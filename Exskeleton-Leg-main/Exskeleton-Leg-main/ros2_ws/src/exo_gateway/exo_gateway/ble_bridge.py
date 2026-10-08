"""BLE GATT peripheral that translates a small, versioned protocol into ROS messages.

The bridge does not publish motor commands. SafetyGateway must independently
approve the selected exercise and every subsequent actuator request.
"""

import asyncio
import base64
import json
import threading
import time

import rclpy
from rclpy.executors import MultiThreadedExecutor
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import DeviceState, ExerciseCommand, ExerciseStatus, FallAlert, PrepareExercise
from std_msgs.msg import String

# GATT schema v2. A new UUID namespace forces Android to discard the stale
# cached permissions from the previous bonding experiments.
SERVICE_UUID = '6e400101-b5a3-f393-e0a9-e50e24dcca9e'
CONTROL_UUID = '6e400102-b5a3-f393-e0a9-e50e24dcca9e'
STATUS_UUID = '6e400103-b5a3-f393-e0a9-e50e24dcca9e'
MAX_PAYLOAD_BYTES = 384


class BleBridge(Node):
    def __init__(self, loop):
        super().__init__('ble_bridge')
        self._loop = loop
        self._status_queue = asyncio.Queue(maxsize=16)
        self._latest_fall_alert = None
        self._latest_fall_at = 0.0
        self._last_device_status_at = 0.0
        self._last_device_status_key = None
        self._routine_transfers = {}
        self._prepare_pub = self.create_publisher(PrepareExercise, '/exo/exercise/prepare', 10)
        self._exercise_pub = self.create_publisher(ExerciseCommand, '/exo/exercise/request', 10)
        self._routine_pub = self.create_publisher(String, '/exo/routine/request', 10)
        self._manual_pub = self.create_publisher(String, '/exo/manual/request', 10)
        self.create_subscription(ExerciseStatus, '/exo/exercise/status', self._on_status, 10)
        self.create_subscription(DeviceState, '/exo/state', self._on_device_state, 10)
        self.create_subscription(String, '/exo/button/event', self._on_button_event, 10)
        self.create_subscription(FallAlert, '/exo/fall/alert', self._on_fall_alert, 10)

    def _on_button_event(self, message):
        try:
            payload = json.loads(message.data)
            button = str(payload.get('button', ''))
            action = str(payload.get('action', ''))
            if button not in ('previous', 'next', 'select') or not action:
                return
        except (TypeError, json.JSONDecodeError):
            return
        self._queue_status({
            'v': 1,
            'type': 'button_event',
            'button': button,
            'action': action,
        })

    def _on_fall_alert(self, alert):
        # Safety events are forwarded immediately and are never rate-limited
        # like the ordinary device heartbeat.
        payload = {
            'v': 1,
            'type': 'fall_alert',
            'alert_id': alert.alert_id,
            'device_id': alert.device_id,
            'predicted_class': int(alert.predicted_class),
            'predicted_label': alert.predicted_label,
            'fall_probability': float(alert.fall_probability),
            'consecutive_fall_windows': int(alert.consecutive_fall_windows),
            'confirmed': bool(alert.confirmed),
            'timestamp_ms': int(time.time() * 1000),
        }
        self._latest_fall_alert = payload
        self._latest_fall_at = time.monotonic()
        self.get_logger().warning(
            f'Forwarding fall alert {alert.alert_id} to BLE status; '
            'it will be replayed on the next subscription if needed')
        self._queue_status(payload)

    def replay_recent_fall(self):
        # A fall can occur before the phone connects. Replay the same alert ID
        # on subscription so the server can deduplicate it.
        if self._latest_fall_alert and time.monotonic() - self._latest_fall_at <= 300:
            self.get_logger().warning(
                f'Replaying fall alert {self._latest_fall_alert["alert_id"]} to BLE subscriber')
            self._queue_status(self._latest_fall_alert)

    def _on_status(self, status):
        payload = {
            'v': 1, 'type': 'exercise_status', 'session_id': status.session_id,
            'exercise_code': status.exercise_code,
            'state': status.state, 'reason': status.reason,
            'completed_repetitions': status.completed_repetitions,
            'completed_sets': status.completed_sets,
            'target_sets': status.target_sets,
            'target_repetitions': status.target_repetitions,
            'elapsed_ms': status.elapsed_ms,
            'active_ms': status.active_ms,
            'repetition_duration_ms': status.repetition_duration_ms,
            'total_repetitions': status.total_repetitions,
            'target_total_repetitions': status.target_total_repetitions,
        }
        self._queue_status(payload)

    def _on_device_state(self, state):
        state_name = {
            DeviceState.STATE_DISARMED: 'disarmed',
            DeviceState.STATE_READY: 'ready',
            DeviceState.STATE_ASSISTING: 'assisting',
            DeviceState.STATE_FAULT: 'fault',
        }.get(state.state, 'unknown')
        payload = {
            'v': 1, 'type': 'device_status', 'state': state_name,
            'battery_percent': state.battery_percent,
            'battery_voltage': state.battery_voltage,
            'estop_active': state.estop_active,
            'command_watchdog_ok': state.command_watchdog_ok,
            'fault_reason': state.fault_reason,
        }
        now = time.monotonic()
        key = (
            state_name, state.estop_active, state.command_watchdog_ok,
            round(float(state.battery_percent), 1),
            round(float(state.battery_voltage), 2), state.fault_reason,
        )
        # /exo/state is normally published at 10 Hz. BLE only needs a 1 Hz
        # heartbeat unless the state actually changed.
        if key == self._last_device_status_key and now - self._last_device_status_at < 1.0:
            return
        self._last_device_status_key = key
        self._last_device_status_at = now
        self._queue_status(payload)

    def _queue_status(self, payload):
        def enqueue():
            if self._status_queue.full():
                # A heartbeat must not evict a safety event under BLE backpressure.
                queued = [self._status_queue.get_nowait() for _ in range(self._status_queue.qsize())]
                discard = next((i for i, item in enumerate(queued)
                                if item.get('type') != 'fall_alert'), None)
                if discard is None:
                    if payload.get('type') != 'fall_alert':
                        for item in queued:
                            self._status_queue.put_nowait(item)
                        return
                    discard = 0
                for index, item in enumerate(queued):
                    if index != discard:
                        self._status_queue.put_nowait(item)
            self._status_queue.put_nowait(payload)
        self._loop.call_soon_threadsafe(enqueue)

    def handle_control(self, raw_value):
        payload = {}
        try:
            if len(raw_value) > MAX_PAYLOAD_BYTES:
                raise ValueError('payload too large')
            payload = json.loads(bytes(raw_value).decode('utf-8'))
            if payload.get('v') != 1:
                raise ValueError('unsupported protocol version')
            packet_type = payload.get('type')
            if packet_type == 'prepare_exercise':
                self._handle_prepare(payload)
            elif packet_type == 'exercise_command':
                self._handle_exercise_command(payload)
            elif packet_type == 'manual_command':
                self._handle_manual_command(payload)
            elif packet_type == 'routine_command':
                self._handle_routine_command(payload)
            elif packet_type == 'routine_begin':
                self._handle_routine_begin(payload)
            elif packet_type == 'routine_chunk':
                self._handle_routine_chunk(payload)
            elif packet_type == 'routine_commit':
                self._handle_routine_commit(payload)
            elif packet_type == 'routine_control':
                self._handle_routine_control(payload)
            else:
                raise ValueError('unsupported BLE packet type')
        except (UnicodeDecodeError, ValueError, TypeError, json.JSONDecodeError) as error:
            self.get_logger().warning(f'Rejected BLE control packet: {error}')
            transfer = self._routine_transfers.get(str(payload.get('transfer_id', '')), {})
            session_id = str(payload.get('session_id') or transfer.get('session_id', ''))[:64]
            self._queue_status({
                'v': 1, 'type': 'exercise_status',
                'session_id': session_id,
                'exercise_code': 'custom_routine',
                'state': 'rejected', 'reason': str(error),
                'completed_repetitions': 0, 'completed_sets': 0,
            })

    def _handle_routine_begin(self, payload):
        transfer_id = str(payload.get('transfer_id', ''))
        session_id = str(payload.get('session_id', ''))[:64]
        total_bytes = int(payload.get('total_bytes', 0))
        total_chunks = int(payload.get('total_chunks', 0))
        if not transfer_id or not session_id or not 1 <= total_bytes <= 65536:
            raise ValueError('invalid routine transfer header')
        if not 1 <= total_chunks <= 400:
            raise ValueError('invalid routine chunk count')
        self._routine_transfers.clear()
        self._routine_transfers[transfer_id] = {
            'session_id': session_id, 'total_bytes': total_bytes,
            'total_chunks': total_chunks, 'chunks': [], 'created_at': time.monotonic(),
        }

    def _handle_routine_chunk(self, payload):
        transfer_id = str(payload.get('transfer_id', ''))
        transfer = self._routine_transfers.get(transfer_id)
        if transfer is None or time.monotonic() - transfer['created_at'] > 30.0:
            raise ValueError('routine transfer expired')
        index = int(payload.get('index', -1))
        if index != len(transfer['chunks']):
            raise ValueError('routine chunk is missing or out of order')
        try:
            chunk = base64.b64decode(str(payload.get('data', '')), validate=True)
        except (ValueError, TypeError) as error:
            raise ValueError('invalid routine chunk encoding') from error
        if not chunk or len(chunk) > 180:
            raise ValueError('invalid routine chunk size')
        transfer['chunks'].append(chunk)

    def _handle_routine_commit(self, payload):
        transfer_id = str(payload.get('transfer_id', ''))
        transfer = self._routine_transfers.pop(transfer_id, None)
        if transfer is None:
            raise ValueError('unknown routine transfer')
        if len(transfer['chunks']) != transfer['total_chunks']:
            raise ValueError('incomplete routine transfer')
        raw = b''.join(transfer['chunks'])
        if len(raw) != transfer['total_bytes']:
            raise ValueError('routine transfer length mismatch')
        routine = json.loads(raw.decode('utf-8'))
        if routine.get('v') != 1 or routine.get('session_id') != transfer['session_id']:
            raise ValueError('routine transfer identity mismatch')
        self._handle_routine_command(routine)

    def _handle_routine_control(self, payload):
        if payload.get('action') != 'stop' or not payload.get('session_id'):
            raise ValueError('invalid routine control')
        message = String()
        message.data = json.dumps({
            'v': 1, 'type': 'routine_command', 'action': 'stop',
            'session_id': str(payload['session_id'])[:64],
        }, separators=(',', ':'))
        self._routine_pub.publish(message)

    def _handle_routine_command(self, payload):
        if payload.get('action', 'start') == 'stop':
            return self._handle_routine_control(payload)
        if not payload.get('routine_id') or not isinstance(payload.get('steps'), list):
            raise ValueError('invalid routine_command')
        if not 1 <= int(payload.get('repetitions', 1)) <= 100 or not 1 <= len(payload['steps']) <= 100:
            raise ValueError('routine target is outside configured limits')
        message = String()
        # SafetyGateway performs the authoritative validation before UART TX.
        message.data = json.dumps(payload, separators=(',', ':'))
        self._routine_pub.publish(message)

    def _handle_manual_command(self, payload):
        action = str(payload.get('action', ''))
        if action == 'stop':
            message = String()
            message.data = json.dumps({
                'v': 1, 'type': 'manual_command', 'action': 'stop',
            }, separators=(',', ':'))
            self._manual_pub.publish(message)
            return
        motor = str(payload.get('motor', ''))
        direction = str(payload.get('direction', ''))
        duration = int(payload.get('duration_ms', 0))
        if motor not in ('C1', 'C2', 'C3', 'C4'):
            raise ValueError('unsupported manual motor')
        if direction not in ('OUT', 'IN'):
            raise ValueError('unsupported manual direction')
        if duration not in (5000, 7000):
            raise ValueError('manual duration must be 5000ms or 7000ms')
        message = String()
        message.data = json.dumps({
            'v': 1, 'type': 'manual_command', 'action': 'move',
            'motor': motor, 'direction': direction,
            'duration_ms': duration,
        }, separators=(',', ':'))
        self._manual_pub.publish(message)

    def _handle_prepare(self, payload):
        required = ('session_id', 'plan_item_id', 'exercise_code', 'sets', 'repetitions')
        if any(key not in payload for key in required):
            raise ValueError('missing prepare_exercise field')
        sets = int(payload['sets'])
        repetitions = int(payload['repetitions'])
        if not 1 <= sets <= 20 or not 1 <= repetitions <= 100:
            raise ValueError('exercise target is outside configured BLE limits')
        message = PrepareExercise()
        message.session_id = str(payload['session_id'])[:64]
        message.plan_item_id = str(payload['plan_item_id'])[:64]
        message.exercise_code = str(payload['exercise_code'])[:64]
        message.sets = sets
        message.repetitions = repetitions
        if not message.session_id or not message.exercise_code:
            raise ValueError('invalid exercise target')
        self._prepare_pub.publish(message)

    def _handle_exercise_command(self, payload):
        required = ('session_id', 'exercise_code', 'action')
        if any(key not in payload for key in required):
            raise ValueError('missing exercise_command field')
        actions = {'start': ExerciseCommand.ACTION_START,
                   'pause': ExerciseCommand.ACTION_PAUSE,
                   'stop': ExerciseCommand.ACTION_STOP}
        sides = {'both': ExerciseCommand.SIDE_BOTH,
                 'left': ExerciseCommand.SIDE_LEFT,
                 'right': ExerciseCommand.SIDE_RIGHT}
        action = str(payload['action']).lower()
        side = str(payload.get('side', 'both')).lower()
        if action not in actions or side not in sides:
            raise ValueError('invalid exercise action or side')
        message = ExerciseCommand()
        message.sequence = int(payload.get('sequence', 0))
        message.session_id = str(payload['session_id'])[:64]
        message.plan_item_id = str(payload.get('plan_item_id', ''))[:64]
        message.exercise_code = str(payload['exercise_code'])[:64]
        message.action = actions[action]
        message.side = sides[side]
        message.repetitions = int(payload.get('repetitions', 1))
        message.sets = int(payload.get('sets', 1))
        message.assist_percent = float(payload.get('assist_percent', 0.0))
        if not message.session_id or not message.exercise_code or not 1 <= message.sets <= 20:
            raise ValueError('invalid exercise command')
        self._exercise_pub.publish(message)


async def run():
    try:
        from bless import BlessServer, GATTAttributePermissions, GATTCharacteristicProperties
        from bless.backends.bluezdbus.dbus.advertisement import BlueZLEAdvertisement
    except ImportError as error:
        raise RuntimeError('Install BLE dependencies: pip install -r requirements-ble.txt') from error

    # bless 0.3.0 exposes optional TxPower/interval properties by default.
    # BlueZ on Raspberry Pi rejects those properties with Invalid Parameters
    # when registering the advertisement. Keep the portable core fields only.
    for property_name in (
            'TxPower', 'MinInterval', 'MaxInterval',
            'ManufacturerData', 'ServiceData'):
        if hasattr(BlueZLEAdvertisement, property_name):
            delattr(BlueZLEAdvertisement, property_name)

    loop = asyncio.get_running_loop()
    rclpy.init()
    node = BleBridge(loop)
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    executor_thread = threading.Thread(target=executor.spin, daemon=True)
    executor_thread.start()

    # Keep the advertised name short: the 128-bit service UUID plus a long
    # local name can exceed the BLE legacy advertisement limit (31 bytes).
    server = BlessServer(name='ExoLeg-1', loop=loop)
    await server.add_new_service(SERVICE_UUID)
    # Nordic UART clients normally send command frames without waiting for an
    # ATT response.  Expose both write modes: older clients can still use a
    # response while Android can use the low-latency no-response path.
    writable = (
        GATTCharacteristicProperties.write
        | GATTCharacteristicProperties.write_without_response
    )
    await server.add_new_characteristic(
        SERVICE_UUID, CONTROL_UUID, writable, None, GATTAttributePermissions.writeable)
    readable_notifiable = GATTCharacteristicProperties.read | GATTCharacteristicProperties.notify
    await server.add_new_characteristic(
        SERVICE_UUID, STATUS_UUID, readable_notifiable, bytearray(b'{}'),
        GATTAttributePermissions.readable)

    def on_write(characteristic, value, **_kwargs):
        if characteristic.uuid.lower() == CONTROL_UUID:
            node.get_logger().info(f'Received BLE control write ({len(value)} bytes)')
            node.handle_control(value)
        characteristic.value = value

    def on_read(characteristic, **_kwargs):
        value = characteristic.value or bytearray()
        node.get_logger().info(
            f'Read BLE characteristic {characteristic.uuid} ({len(value)} bytes)')
        return bytearray(value)

    server.write_request_func = on_write
    server.read_request_func = on_read
    def on_start_notify(characteristic):
        node.get_logger().info('BLE central subscribed to status notifications')
        node.replay_recent_fall()

    server.app.StartNotify = on_start_notify
    server.app.StopNotify = lambda characteristic: node.get_logger().info(
        'BLE central unsubscribed from status notifications')
    await server.start()
    node.get_logger().info('Advertising ExoLeg-1 BLE GATT service')
    try:
        while rclpy.ok():
            status = await node._status_queue.get()
            characteristic = server.get_characteristic(STATUS_UUID)
            characteristic.value = bytearray(json.dumps(status, separators=(',', ':')).encode())
            try:
                server.update_value(SERVICE_UUID, STATUS_UUID)
                if status.get('type') == 'fall_alert':
                    node.get_logger().info(f'BLE fall alert update sent: {status.get("alert_id")}')
            except Exception as error:
                node.get_logger().warning(f'BLE notification update failed: {error}')
    finally:
        await server.stop()
        executor.shutdown()
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


def main():
    try:
        asyncio.run(run())
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
