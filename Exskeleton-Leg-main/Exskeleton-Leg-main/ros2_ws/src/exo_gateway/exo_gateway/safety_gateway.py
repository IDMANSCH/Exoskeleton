"""ROS safety boundary. Hardware drivers must remain downstream of this node."""

import rclpy
import json
import time
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import (
    DeviceCommand,
    DeviceState,
    ExerciseCommand,
    ExerciseStatus,
    PrepareExercise,
)
from std_msgs.msg import String


class SafetyGateway(Node):
    def __init__(self):
        super().__init__('safety_gateway')
        self.declare_parameter('max_assist_percent', 40.0)
        self.declare_parameter('command_timeout_sec', 0.5)
        # False until a real, independently fail-safe E-stop input is wired in.
        self.declare_parameter('estop_active', True)
        self.declare_parameter('exercise_commissioning_mode', False)
        self._last_command_time = None
        self._fault_reason = 'E-stop hardware adapter not configured'
        self._prepared_session_id = None
        self._device_telemetry = None
        self._device_telemetry_received_at = 0.0
        self._state_pub = self.create_publisher(DeviceState, '/exo/state', 10)
        self.create_subscription(DeviceState, '/exo/state/raw', self._on_device_telemetry, 10)
        self._accepted_pub = self.create_publisher(DeviceCommand, '/exo/command/accepted', 10)
        self.create_subscription(DeviceCommand, '/exo/command/request', self._on_request, 10)
        self.create_subscription(PrepareExercise, '/exo/exercise/prepare', self._on_prepare_exercise, 10)
        self._exercise_accepted_pub = self.create_publisher(
            ExerciseCommand, '/exo/exercise/accepted', 10)
        self.create_subscription(ExerciseCommand, '/exo/exercise/request', self._on_exercise_request, 10)
        self._routine_accepted_pub = self.create_publisher(String, '/exo/routine/accepted', 10)
        self.create_subscription(String, '/exo/routine/request', self._on_routine_request, 10)
        self._manual_accepted_pub = self.create_publisher(String, '/exo/manual/accepted', 10)
        self.create_subscription(String, '/exo/manual/request', self._on_manual_request, 10)
        self._exercise_status_pub = self.create_publisher(ExerciseStatus, '/exo/exercise/status', 10)
        self.create_timer(0.1, self._publish_state)

        # Single source of truth for the commissioning dataset. The actuator
        # adapter will later use the same code to select its motion profile.
        self._exercise_catalog = {
            'walk': {'side': ExerciseCommand.SIDE_BOTH, 'profile': 'gait'},
            'raise_left_leg': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'leg_raise'},
            'raise_right_leg': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'leg_raise'},
            'sit_to_stand': {'side': ExerciseCommand.SIDE_BOTH, 'profile': 'sit_stand'},
            'kick_left_leg': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'leg_kick'},
            'kick_right_leg': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'leg_kick'},
            'kick_left_knee': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'knee_kick'},
            'kick_right_knee': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'knee_kick'},
        }

    def _on_prepare_exercise(self, exercise):
        status = ExerciseStatus()
        status.session_id = exercise.session_id
        status.exercise_code = exercise.exercise_code
        if self._estop_active() and not self._commissioning_mode():
            status.state = 'not_ready'
            status.reason = 'E-stop active or hardware adapter not configured'
        elif exercise.exercise_code not in self._exercise_catalog:
            status.state = 'rejected'
            status.reason = 'unsupported exercise code'
        elif not exercise.exercise_code or not exercise.sets or not exercise.repetitions:
            status.state = 'rejected'
            status.reason = 'exercise code, sets, and repetitions are required'
        else:
            self._prepared_session_id = exercise.session_id
            status.state = 'prepared'
            status.reason = ''
        self._exercise_status_pub.publish(status)

    def _on_exercise_request(self, command):
        status = ExerciseStatus()
        status.session_id = command.session_id
        status.exercise_code = command.exercise_code
        status.completed_repetitions = 0

        if command.action == ExerciseCommand.ACTION_STOP:
            self._exercise_accepted_pub.publish(command)
            status.state = 'stopping'
            status.reason = 'Returning all cylinders to HOME'
            self._exercise_status_pub.publish(status)
            return
        if self._estop_active() and not self._commissioning_mode():
            status.state = 'not_ready'
            status.reason = 'E-stop active or hardware adapter not configured'
        elif command.exercise_code not in self._exercise_catalog:
            status.state = 'rejected'
            status.reason = 'unsupported exercise code'
        elif (self._exercise_catalog[command.exercise_code]['side'] != ExerciseCommand.SIDE_BOTH
              and command.side != self._exercise_catalog[command.exercise_code]['side']):
            status.state = 'rejected'
            status.reason = 'exercise side does not match the selected profile'
        elif not self._prepared_session_id or command.session_id != self._prepared_session_id:
            status.state = 'rejected'
            status.reason = 'exercise session was not prepared'
        elif command.action not in (
                ExerciseCommand.ACTION_START, ExerciseCommand.ACTION_PAUSE):
            status.state = 'rejected'
            status.reason = 'unsupported exercise action'
        elif not 1 <= command.repetitions <= 100:
            status.state = 'rejected'
            status.reason = 'repetitions must be between 1 and 100'
        elif not 0.0 <= command.assist_percent <= self.get_parameter('max_assist_percent').value:
            status.state = 'rejected'
            status.reason = 'assist_percent is outside the configured limit'
        else:
            self._exercise_accepted_pub.publish(command)
            # Acceptance by the Pi is not proof that the actuator started.
            # Mobile waits for running/flexing emitted by the ESP32 over UART.
            status.state = 'accepted' if command.action == ExerciseCommand.ACTION_START else 'paused'
            status.reason = ''
            self._last_command_time = self.get_clock().now()

        self._exercise_status_pub.publish(status)

    def _on_routine_request(self, message):
        session_id = ''
        try:
            payload = json.loads(message.data)
            session_id = str(payload.get('session_id', ''))[:64]
            if payload.get('action', 'start') == 'stop':
                if not session_id:
                    raise ValueError('routine stop requires session_id')
                accepted = String()
                accepted.data = json.dumps(payload, separators=(',', ':'))
                self._routine_accepted_pub.publish(accepted)
                self._publish_routine_status(session_id, 'stopping', 'Returning all cylinders to HOME')
                return
            if not session_id:
                raise ValueError('routine requires session_id')
            if self._estop_active() and not self._commissioning_mode():
                raise ValueError('E-stop active or hardware adapter not configured')
            steps = payload.get('steps', [])
            mode = str(payload.get('execution_mode', 'ONE_LEG')).upper()
            starting_side = str(payload.get('starting_side', 'RIGHT')).upper()
            if mode not in ('ONE_LEG', 'TWO_LEG_ALTERNATING') or starting_side not in ('LEFT', 'RIGHT'):
                raise ValueError('invalid routine leg mode')
            if not payload.get('routine_id') or not 1 <= int(payload.get('repetitions', 1)) <= 100:
                raise ValueError('invalid routine target')
            if not 1 <= len(steps) <= 100:
                raise ValueError('routine has too many or too few steps')
            joint_state = {motor: 'IN' for motor in ('C1', 'C2', 'C3', 'C4')}
            last_motion = {}
            used_motors = set()
            active_side = starting_side
            switched_side = False
            for step in steps:
                motor = step.get('motor')
                direction = step.get('direction')
                duration = int(step.get('duration_ms', 0))
                rest = int(step.get('rest_after_ms', 0))
                repeat = int(step.get('repeat_count', 1))
                if motor not in ('C1', 'C2', 'C3', 'C4') or direction not in ('OUT', 'IN', 'STOP'):
                    raise ValueError('unsupported motor action')
                if not 0 <= duration <= 30000 or not 0 <= rest <= 10000 or not 1 <= repeat <= 100:
                    raise ValueError('routine timing outside limits')
                if direction != 'STOP' and repeat != 1:
                    raise ValueError('motor motion steps cannot repeat without a reverse motion')
                used_motors.add(motor)
                step_side = 'RIGHT' if motor in ('C1', 'C2') else 'LEFT'
                if mode == 'ONE_LEG' and step_side != starting_side:
                    raise ValueError('one-leg routine contains the opposite leg')
                if mode == 'TWO_LEG_ALTERNATING' and not last_motion and step_side != starting_side:
                    raise ValueError('routine does not start on the selected leg')
                if mode == 'TWO_LEG_ALTERNATING' and step_side != active_side:
                    if switched_side:
                        raise ValueError('two-leg routine switches side more than once')
                    active_motors = ('C1', 'C2') if active_side == 'RIGHT' else ('C3', 'C4')
                    if any(joint_state[motor] != 'IN' for motor in active_motors):
                        raise ValueError('first leg must return HOME before switching side')
                    active_side = step_side
                    switched_side = True
                if direction != 'STOP' and joint_state[motor] == direction:
                    raise ValueError(f'{motor} cannot run {direction} twice without reversing')
                if direction != 'STOP' and motor in last_motion and last_motion[motor][0] != direction and last_motion[motor][1] < 700:
                    raise ValueError('direction change requires 700ms stop rest')
                if direction != 'STOP':
                    joint_state[motor] = direction
                    last_motion[motor] = (direction, rest)
            if any(joint_state[motor] != 'IN' for motor in used_motors):
                raise ValueError('routine must finish with every used joint at home')
            if mode == 'TWO_LEG_ALTERNATING' and not switched_side:
                raise ValueError('two-leg routine is missing the mirrored leg')
            accepted = String()
            accepted.data = json.dumps(payload, separators=(',', ':'))
            self._routine_accepted_pub.publish(accepted)
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.get_logger().warning(f'Rejected routine: {error}')
            self._publish_routine_status(session_id, 'rejected', str(error))

    def _on_manual_request(self, message):
        try:
            payload = json.loads(message.data)
            action = str(payload.get('action', ''))
            if action == 'stop':
                accepted = String()
                accepted.data = json.dumps(
                    {'v': 1, 'type': 'manual_command', 'action': 'stop'},
                    separators=(',', ':'))
                self._manual_accepted_pub.publish(accepted)
                return
            motor = str(payload.get('motor', ''))
            direction = str(payload.get('direction', ''))
            duration = int(payload.get('duration_ms', 0))
            if self._estop_active() and not self._commissioning_mode():
                raise ValueError('E-stop active or hardware adapter not configured')
            if motor not in ('C1', 'C2', 'C3', 'C4'):
                raise ValueError('unsupported manual motor')
            if direction not in ('OUT', 'IN'):
                raise ValueError('unsupported manual direction')
            if duration not in (5000, 7000):
                raise ValueError('manual duration must be 5000ms or 7000ms')
            accepted = String()
            accepted.data = json.dumps({
                'v': 1, 'type': 'manual_command', 'action': 'move',
                'motor': motor, 'direction': direction,
                'duration_ms': duration,
            }, separators=(',', ':'))
            self._manual_accepted_pub.publish(accepted)
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.get_logger().warning(f'Rejected manual command: {error}')

    def _publish_routine_status(self, session_id, state, reason=''):
        status = ExerciseStatus()
        status.session_id = session_id
        status.exercise_code = 'custom_routine'
        status.state = state
        status.reason = reason
        self._exercise_status_pub.publish(status)

    def _estop_active(self):
        return self.get_parameter('estop_active').value

    def _on_device_telemetry(self, telemetry):
        self._device_telemetry = telemetry
        self._device_telemetry_received_at = time.monotonic()

    def _commissioning_mode(self):
        return self.get_parameter('exercise_commissioning_mode').value

    def _on_request(self, command):
        if command.mode == DeviceCommand.MODE_STOP or not command.enable:
            self._accepted_pub.publish(command)
            self._fault_reason = ''
            return
        if self._estop_active():
            self._fault_reason = 'E-stop active or hardware adapter not configured'
            self.get_logger().warning(f'Rejected enable request: {self._fault_reason}')
            return
        maximum = self.get_parameter('max_assist_percent').value
        if not 0.0 <= command.assist_percent <= maximum:
            self._fault_reason = f'assist_percent must be in [0, {maximum}]'
            self.get_logger().warning(
                f'Rejected command {command.sequence}: {self._fault_reason}')
            return
        self._last_command_time = self.get_clock().now()
        self._fault_reason = ''
        self._accepted_pub.publish(command)

    def _publish_state(self):
        state = DeviceState()
        state.header.stamp = self.get_clock().now().to_msg()
        telemetry = self._device_telemetry
        telemetry_fresh = (
            telemetry is not None
            and time.monotonic() - self._device_telemetry_received_at <= 3.0
        )
        state.estop_active = self._estop_active() or not telemetry_fresh
        timeout = self.get_parameter('command_timeout_sec').value
        safety_watchdog_ok = (
            self._last_command_time is not None
            and (self.get_clock().now() - self._last_command_time).nanoseconds / 1e9 <= timeout
        )
        state.command_watchdog_ok = bool(
            telemetry.command_watchdog_ok if telemetry_fresh else False
        ) and safety_watchdog_ok
        state.state = (
            DeviceState.STATE_FAULT
            if state.estop_active
            else (telemetry.state if telemetry_fresh else DeviceState.STATE_FAULT)
        )
        state.battery_percent = telemetry.battery_percent if telemetry_fresh else -1.0
        state.battery_voltage = telemetry.battery_voltage if telemetry_fresh else -1.0
        if self._estop_active():
            state.fault_reason = self._fault_reason
        elif not telemetry_fresh:
            state.fault_reason = 'ESP32 telemetry timeout'
        else:
            state.fault_reason = telemetry.fault_reason
        self._state_pub.publish(state)


def main():
    rclpy.init()
    node = SafetyGateway()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
