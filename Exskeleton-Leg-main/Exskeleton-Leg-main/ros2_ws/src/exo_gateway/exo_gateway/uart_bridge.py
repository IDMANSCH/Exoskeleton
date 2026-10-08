"""Pi USB serial (CP210x) <-> ESP32 USB Type-C bridge.

The wire format is deliberately inspectable while the hardware protocol is
being commissioned:

    EXO1|{"type":"exercise_command",...}|AB12\n
AB12 is CRC-16/CCITT over the JSON bytes. Only messages already accepted by
SafetyGateway are sent to the MCU. The MCU must still enforce its own limits
and watchdog.
"""

import json
import threading
import time

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import DeviceCommand, DeviceState, ExerciseCommand, ExerciseStatus, ImuSample
from std_msgs.msg import String


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def encode_frame(payload):
    raw = json.dumps(payload, separators=(',', ':'), ensure_ascii=True).encode('utf-8')
    return b'EXO1|' + raw + b'|' + f'{crc16(raw):04X}'.encode('ascii') + b'\n'


def decode_frame(line):
    parts = line.strip().split(b'|')
    if len(parts) != 3 or parts[0] != b'EXO1':
        raise ValueError('invalid UART frame prefix')
    raw, received = parts[1], parts[2]
    if len(raw) > 768 or received.upper() != f'{crc16(raw):04X}'.encode('ascii'):
        raise ValueError('UART CRC or payload length check failed')
    return json.loads(raw.decode('utf-8'))


class UartBridge(Node):
    def __init__(self):
        super().__init__('uart_bridge')
        self.declare_parameter('device', '/dev/ttyUSB0')
        self.declare_parameter('baudrate', 921600)
        self.declare_parameter('reconnect_sec', 2.0)
        self._serial = None
        self._serial_lock = threading.Lock()
        self._stop = threading.Event()
        self._last_valid_rx = 0.0
        self._invalid_rx_since = 0.0
        # UART is only a telemetry source.  SafetyGateway is the single
        # authoritative publisher of /exo/state; publishing there directly
        # would make consumers receive alternating Pi/ESP32 snapshots.
        self._state_pub = self.create_publisher(DeviceState, '/exo/state/raw', 10)
        self._exercise_status_pub = self.create_publisher(ExerciseStatus, '/exo/exercise/status', 10)
        self._imu_pub = self.create_publisher(ImuSample, '/exo/imu', 100)
        # Local ESP32 controls are useful to the app/logger as well as to the
        # operator. Keep the raw JSON so future consumers do not need a new
        # interface message for every button action.
        self._button_event_pub = self.create_publisher(String, '/exo/button/event', 10)
        self.create_subscription(DeviceCommand, '/exo/command/accepted', self._on_device_command, 10)
        self.create_subscription(ExerciseCommand, '/exo/exercise/accepted', self._on_exercise_command, 10)
        self.create_subscription(String, '/exo/routine/accepted', self._on_routine_command, 10)
        self.create_subscription(String, '/exo/manual/accepted', self._on_manual_command, 10)
        self._routine_stop = threading.Event()
        self._routine_io_lock = threading.Lock()
        self._status_condition = threading.Condition()
        self._last_exercise_status = {}
        self._routine_thread = None
        self._active_routine_session = None
        self._reader = threading.Thread(target=self._read_loop, name='exo-uart-reader', daemon=True)
        self._reader.start()

    def _connect(self):
        try:
            import serial
            device = str(self.get_parameter('device').value)
            baudrate = int(self.get_parameter('baudrate').value)
            # Opening a CP210x can toggle DTR/RTS and accidentally hold an
            # ESP32 in reset/bootloader. Force both lines inactive, then give
            # the board time to finish booting before using the stream.
            port = serial.Serial(
                device, baudrate=baudrate, timeout=0.5, write_timeout=0.5,
                rtscts=False, dsrdtr=False, exclusive=True,
            )
            port.rts = False
            port.dtr = False
            time.sleep(1.5)
            port.reset_input_buffer()
            self._serial = port
            self._last_valid_rx = time.monotonic()
            self._invalid_rx_since = 0.0
            self.get_logger().info(f'Connected ESP32 USB serial at {device} ({baudrate} baud)')
            # A harmless handshake confirms that the ESP32 is alive. It also
            # makes startup deterministic when the Pi came up before USB.
            self._send({'type': 'ping'})
        except Exception as error:  # pyserial reports several OS-specific errors
            try:
                if self._serial is not None:
                    self._serial.close()
            except Exception:
                pass
            self._serial = None
            self.get_logger().warning(f'ESP32 UART unavailable: {error}')

    def _disconnect(self, reason):
        with self._serial_lock:
            serial_port = self._serial
            self._serial = None
        if serial_port is not None:
            try:
                serial_port.close()
            except Exception:
                pass
        self.get_logger().warning(f'ESP32 UART reconnect scheduled: {reason}')

    def _send(self, payload):
        with self._serial_lock:
            if self._serial is None:
                return
            try:
                self._serial.write(encode_frame(payload))
                self._serial.flush()
                self.get_logger().info(f"UART TX {payload.get('type', 'unknown')}")
            except Exception as error:
                self.get_logger().error(f'UART write failed: {error}')
                try:
                    self._serial.close()
                finally:
                    self._serial = None

    def _on_device_command(self, command):
        self._send({
            'type': 'device_command', 'sequence': int(command.sequence),
            'mode': int(command.mode), 'enable': bool(command.enable),
            'assist_percent': float(command.assist_percent),
        })

    def _on_exercise_command(self, command):
        actions = {ExerciseCommand.ACTION_START: 'start',
                   ExerciseCommand.ACTION_PAUSE: 'pause',
                   ExerciseCommand.ACTION_STOP: 'stop'}
        sides = {ExerciseCommand.SIDE_BOTH: 'both', ExerciseCommand.SIDE_LEFT: 'left',
                 ExerciseCommand.SIDE_RIGHT: 'right'}
        if command.action == ExerciseCommand.ACTION_STOP:
            self._routine_stop.set()
        self._send({
            'type': 'exercise_command', 'sequence': int(command.sequence),
            'session_id': command.session_id, 'plan_item_id': command.plan_item_id,
            'exercise_code': command.exercise_code, 'action': actions.get(command.action, 'stop'),
            'side': sides.get(command.side, 'both'), 'repetitions': int(command.repetitions),
            'sets': int(command.sets),
            'assist_percent': float(command.assist_percent),
        })

    def _on_routine_command(self, message):
        try:
            payload = json.loads(message.data)
        except (TypeError, json.JSONDecodeError):
            return
        if payload.get('action', 'start') == 'stop':
            self._routine_stop.set()
            session_id = str(payload.get('session_id', ''))[:64]
            with self._routine_io_lock:
                self._send({'type': 'home_command', 'action': 'stop',
                            'session_id': session_id})
            return
        if self._routine_thread is not None and self._routine_thread.is_alive():
            self._publish_routine_status(
                str(payload.get('session_id', ''))[:64], 'rejected',
                'another routine is still active')
            return
        self._routine_stop = threading.Event()
        self._active_routine_session = str(payload.get('session_id', ''))[:64]
        self._routine_thread = threading.Thread(
            target=self._run_routine, args=(payload, self._routine_stop),
            name='exo-routine-runner', daemon=True)
        self._routine_thread.start()

    def _on_manual_command(self, message):
        try:
            payload = json.loads(message.data)
        except (TypeError, json.JSONDecodeError):
            self.get_logger().warning('Invalid manual command JSON')
            return
        if payload.get('action') == 'stop':
            with self._routine_io_lock:
                for motor in ('C1', 'C2', 'C3', 'C4'):
                    self._send({'type': 'motor_command', 'session_id': 'manual',
                                'motor': motor, 'direction': 'STOP', 'duration_ms': 0})
            self.get_logger().info('Manual mode stopped all motors')
            return
        with self._routine_io_lock:
            self._send({
                'type': 'motor_command', 'session_id': 'manual',
                'motor': payload.get('motor'),
                'direction': payload.get('direction'),
                'duration_ms': int(payload.get('duration_ms', 0)),
            })
        self.get_logger().info(
            f"Manual motor {payload.get('motor')} {payload.get('direction')} "
            f"for {payload.get('duration_ms')}ms")

    def _run_routine(self, payload, stop_event):
        session_id = str(payload.get('session_id', ''))[:64]
        self._publish_routine_status(session_id, 'preparing', 'Returning all cylinders to HOME')
        if not self._routine_send(stop_event, {
                'type': 'home_command', 'action': 'prepare',
                'session_id': session_id}):
            return
        if not self._wait_for_status(session_id, {'home_ready'}, 10.0, stop_event):
            if not stop_event.is_set():
                self._publish_routine_status(session_id, 'rejected', 'ESP32 HOME acknowledgement timeout')
            return
        self._publish_routine_status(session_id, 'running')
        repetitions = int(payload.get('repetitions', 1))
        completed = 0
        for _ in range(repetitions):
            for step in payload.get('steps', []):
                for _ in range(int(step.get('repeat_count', 1))):
                    if stop_event.is_set():
                        return
                    if not self._routine_send(stop_event, {
                            'type': 'motor_command', 'session_id': session_id,
                            'motor': step['motor'], 'direction': step['direction'],
                            'duration_ms': int(step['duration_ms'])}):
                        return
                    self._publish_routine_status(
                        session_id,
                        'flexing' if step['direction'] == 'OUT' else 'extending')
                    if stop_event.wait(int(step.get('duration_ms', 0)) / 1000.0):
                        return
                    if not self._routine_send(stop_event, {
                            'type': 'motor_command', 'session_id': session_id,
                            'motor': step['motor'], 'direction': 'STOP',
                            'duration_ms': 0}):
                        return
                    if stop_event.wait(int(step.get('rest_after_ms', 0)) / 1000.0):
                        return
            completed += 1
            self._publish_routine_status(
                session_id, 'running', completed_repetitions=completed,
                target_repetitions=repetitions)
        if not self._routine_send(stop_event, {
                'type': 'home_command', 'action': 'complete',
                'session_id': session_id}):
            return
        if not self._wait_for_status(session_id, {'completed'}, 10.0, stop_event):
            if not stop_event.is_set():
                self._publish_routine_status(session_id, 'rejected', 'ESP32 final HOME acknowledgement timeout')

    def _routine_send(self, stop_event, payload):
        with self._routine_io_lock:
            if stop_event.is_set():
                return False
            self._send(payload)
            return True

    def _wait_for_status(self, session_id, states, timeout, stop_event):
        deadline = time.monotonic() + timeout
        with self._status_condition:
            while not stop_event.is_set():
                state = self._last_exercise_status.get(session_id)
                if state in states:
                    return True
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return False
                self._status_condition.wait(min(remaining, 0.2))
        return False

    def _publish_routine_status(self, session_id, state, reason='',
                                completed_repetitions=0, target_repetitions=0):
        status = ExerciseStatus()
        status.session_id = session_id
        status.exercise_code = 'custom_routine'
        status.state = state
        status.reason = reason
        status.completed_repetitions = completed_repetitions
        status.target_repetitions = target_repetitions
        status.target_sets = 1
        self._exercise_status_pub.publish(status)

    def _handle_rx(self, payload):
        kind = payload.get('type')
        if kind == 'imu_sample':
            sample = ImuSample()
            sample.header.stamp = self.get_clock().now().to_msg()
            sample.sequence = int(payload.get('seq', 0))
            sample.sensor_time_ms = int(payload.get('t_ms', 0))
            sample.channel = int(payload.get('channel', 4))
            sample.ax = float(payload.get('ax', 0.0))
            sample.ay = float(payload.get('ay', 0.0))
            sample.az = float(payload.get('az', 0.0))
            sample.gx = float(payload.get('gx', 0.0))
            sample.gy = float(payload.get('gy', 0.0))
            sample.gz = float(payload.get('gz', 0.0))
            self._imu_pub.publish(sample)
        elif kind == 'device_status':
            state = DeviceState()
            state.state = {
                'disarmed': DeviceState.STATE_DISARMED,
                'ready': DeviceState.STATE_READY,
                'assisting': DeviceState.STATE_ASSISTING,
                'fault': DeviceState.STATE_FAULT,
            }.get(payload.get('state'), DeviceState.STATE_FAULT)
            state.estop_active = bool(payload.get('estop_active', True))
            state.command_watchdog_ok = bool(payload.get('command_watchdog_ok', False))
            state.battery_percent = float(payload.get('battery_percent', -1.0))
            state.battery_voltage = float(payload.get('battery_voltage', -1.0))
            state.fault_reason = str(payload.get('fault_reason', ''))[:256]
            state.header.stamp = self.get_clock().now().to_msg()
            self._state_pub.publish(state)
        elif kind == 'exercise_status':
            status = ExerciseStatus()
            status.session_id = str(payload.get('session_id', ''))[:64]
            status.exercise_code = str(payload.get('exercise_code', ''))[:64]
            status.state = str(payload.get('state', 'rejected'))[:32]
            status.reason = str(payload.get('reason', ''))[:256]
            status.completed_repetitions = int(payload.get('completed_repetitions', 0))
            status.completed_sets = int(payload.get('completed_sets', 0))
            status.target_sets = int(payload.get('target_sets', 0))
            status.target_repetitions = int(payload.get('target_repetitions', 0))
            status.elapsed_ms = int(payload.get('elapsed_ms', 0))
            status.active_ms = int(payload.get('active_ms', 0))
            status.repetition_duration_ms = int(payload.get('repetition_duration_ms', 0))
            status.total_repetitions = int(payload.get('total_repetitions', 0))
            status.target_total_repetitions = int(payload.get('target_total_repetitions', 0))
            with self._status_condition:
                self._last_exercise_status[status.session_id] = status.state
                self._status_condition.notify_all()
            self._exercise_status_pub.publish(status)
            if (status.session_id == self._active_routine_session):
                if status.state == 'stopping':
                    # A physical long-press on ESP32 must stop the Pi runner
                    # before it can transmit another timed motor step.
                    self._routine_stop.set()
                elif status.state in ('rejected', 'not_ready'):
                    self._routine_stop.set()
                    with self._routine_io_lock:
                        self._send({'type': 'home_command', 'action': 'stop',
                                    'session_id': status.session_id})
                elif status.state == 'stopped':
                    self._routine_stop.set()
                    self._active_routine_session = None
                elif status.state == 'completed':
                    self._active_routine_session = None
        elif kind == 'exercise_selected':
            exercise_code = str(payload.get('exercise_code', ''))[:64]
            self.get_logger().info(f'ESP32 selected exercise {exercise_code}')
            status = ExerciseStatus()
            status.session_id = 'local-ui'
            status.exercise_code = exercise_code
            status.state = 'selected'
            status.reason = ''
            status.completed_repetitions = 0
            status.completed_sets = 0
            status.target_sets = 0
            status.target_repetitions = 0
            status.elapsed_ms = 0
            status.active_ms = 0
            status.repetition_duration_ms = 0
            status.total_repetitions = 0
            status.target_total_repetitions = 0
            self._exercise_status_pub.publish(status)
        elif kind == 'button_event':
            button = str(payload.get('button', ''))[:32]
            action = str(payload.get('action', ''))[:32]
            if button not in ('previous', 'next', 'select'):
                self.get_logger().warning(f'Ignoring invalid ESP32 button event: {payload}')
                return
            event = String()
            event.data = json.dumps({
                'v': 1,
                'type': 'button_event',
                'button': button,
                'action': action,
            }, separators=(',', ':'))
            self._button_event_pub.publish(event)
            self.get_logger().info(f'ESP32 button {button}: {action}')
        else:
            self.get_logger().warning(f'Ignoring unknown ESP32 UART message: {kind}')

    def _read_loop(self):
        while not self._stop.is_set() and rclpy.ok():
            if self._serial is None:
                self._connect()
                if self._serial is None:
                    self._stop.wait(float(self.get_parameter('reconnect_sec').value))
                    continue
            try:
                line = self._serial.readline()
                if not line:
                    if time.monotonic() - self._last_valid_rx >= 5.0:
                        self._disconnect('no valid EXO1 frame for 5 seconds')
                    continue
            except Exception as error:
                self.get_logger().warning(f'UART read failed: {error}')
                self._disconnect(str(error))
                continue
            try:
                payload = decode_frame(line)
            except Exception as error:
                # USB-UART ESP32 boot messages and monitor text are not
                # protocol frames. Ignore them without resetting the port.
                self.get_logger().debug(f'Ignoring non-protocol USB input: {error}')
                now = time.monotonic()
                if self._invalid_rx_since == 0.0:
                    self._invalid_rx_since = now
                # Continuous garbage normally means that the ESP32 and Pi
                # are not synchronized (boot timing, stale USB state, or
                # wrong firmware/baud). Reopen the port automatically; this
                # is the same recovery a physical unplug/replug provides.
                if now - self._invalid_rx_since >= 3.0:
                    self._disconnect('no valid EXO1 frame for 3 seconds')
                continue
            try:
                self._last_valid_rx = time.monotonic()
                self._invalid_rx_since = 0.0
                # IMU arrives at 100 Hz. Logging every sample floods journald
                # and can starve the BLE event loop on a Raspberry Pi.
                if payload.get('type') != 'imu_sample':
                    self.get_logger().info(f"UART RX {payload.get('type', 'unknown')}")
                self._handle_rx(payload)
            except Exception as error:
                self.get_logger().warning(f'UART frame handling failed: {error}')
                try:
                    self._serial.close()
                finally:
                    self._serial = None

    def destroy_node(self):
        self._stop.set()
        with self._serial_lock:
            if self._serial is not None:
                self._serial.close()
                self._serial = None
        self._reader.join(timeout=1.0)
        return super().destroy_node()


def main():
    rclpy.init()
    node = UartBridge()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
