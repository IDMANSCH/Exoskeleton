import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exo_ble_protocol.dart';

/// BLE central for a nearby exoskeleton. It never sends motor-level commands.
class ExoBleService {
  static final shared = ExoBleService();

  ExoBleService({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  static const _native = MethodChannel('exo_leg/native_ble');
  static const _nativeStatus = EventChannel('exo_leg/native_ble_status');
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<dynamic>? _statusSubscription;
  Future<void> _writeQueue = Future<void>.value();
  Future<void>? _connecting;
  Timer? _reconnectTimer;
  var _reconnectAttempt = 0;
  bool _disposed = false;
  QualifiedCharacteristic? _control;
  String? _lastDeviceId;
  final _status = StreamController<ExerciseDeviceStatus>.broadcast();
  final _deviceStatus = StreamController<LiveDeviceStatus>.broadcast();
  final _fallAlerts = StreamController<FallAlert>.broadcast();
  final _buttonEvents = StreamController<ExoButtonEvent>.broadcast();

  Stream<ExerciseDeviceStatus> get status => _status.stream;
  Stream<LiveDeviceStatus> get deviceStatus => _deviceStatus.stream;
  Stream<FallAlert> get fallAlerts => _fallAlerts.stream;
  Stream<ExoButtonEvent> get buttonEvents => _buttonEvents.stream;
  bool get isConnected => _control != null;

  Future<List<ExoBleDevice>> discoverExoskeletons() async {
    developer.log('Starting BLE scan for ExoLeg devices', name: 'ExoBle');
    await _ensureReady();
    final devices = <String, ExoBleDevice>{};
    Object? scanError;
    final scan = _ble
        // Filter by the GATT service, not the advertised name. Android can
        // return an empty device.name when the name is carried in scan
        // response data, while the service UUID remains available.
        .scanForDevices(
      withServices: [Uuid.parse(ExoBleProtocol.serviceUuid)],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final name = device.name.isEmpty ? 'ExoLeg-1' : device.name;
      devices[device.id] = ExoBleDevice(
        id: device.id,
        name: name,
        rssi: device.rssi,
      );
      developer.log('Discovered $name (${device.id}), RSSI ${device.rssi}',
          name: 'ExoBle');
    }, onError: (Object error, StackTrace stackTrace) {
      scanError = error;
      developer.log('BLE scan failed: $error',
          name: 'ExoBle', error: error, stackTrace: stackTrace);
    });
    try {
      await Future<void>.delayed(const Duration(seconds: 5));
    } finally {
      await scan.cancel();
    }
    if (scanError != null) throw StateError('BLE scan failed: $scanError');
    return devices.values.toList()
      ..sort((left, right) => right.rssi.compareTo(left.rssi));
  }

  Future<void> connect({String? deviceId}) {
    if (isConnected && (deviceId == null || deviceId == _lastDeviceId)) {
      return Future<void>.value();
    }

    // Device selection and exercise preparation can arrive almost together.
    // FlutterReactiveBle closes the first Android GATT client if a second
    // connectToDevice subscription is created, so all callers must share one
    // in-flight connection attempt.
    final connecting = _connecting;
    if (connecting != null) return connecting;

    late final Future<void> tracked;
    final operation = _connectOnce(deviceId);
    tracked = operation.whenComplete(() {
      if (identical(_connecting, tracked)) _connecting = null;
    });
    _connecting = tracked;
    return tracked;
  }

  Future<void> _connectOnce(String? deviceId) async {
    _reconnectTimer?.cancel();
    await _resetConnection();
    final id = deviceId ?? (await _firstDiscoveredDeviceId());
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _connectToDevice(id);
        return;
      } catch (error) {
        if (attempt == 3 || !_isTransientConnectionError(error)) rethrow;
        developer.log(
            'Transient BLE connect failure; retrying '
            '(attempt ${attempt + 1}/3): $error',
            name: 'ExoBle');
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
    }
  }

  bool _isTransientConnectionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('status=257') ||
        message.contains('status=22') ||
        message.contains('status=133') ||
        message.contains('not_connected') ||
        message.contains('cancelled') ||
        message.contains('notify') ||
        message.contains('disconnected') ||
        message.contains('gatt');
  }

  Future<void> _resetConnection() async {
    await _connection?.cancel();
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    _connection = null;
    _control = null;
    await _native.invokeMethod<void>('disconnect');
    // Android needs a short gap after close() before a new GATT client is
    // allocated for the same peripheral.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _ensureReady() async {
    final permissions =
        await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    if (permissions.values.any((value) => !value.isGranted)) {
      throw StateError('Bluetooth permission was not granted');
    }
    final adapterStatus = await _ble.statusStream
        .firstWhere((status) => status != BleStatus.unknown)
        .timeout(const Duration(seconds: 5));
    if (adapterStatus != BleStatus.ready) {
      throw StateError('Bluetooth adapter is not ready: $adapterStatus');
    }
  }

  Future<String> _firstDiscoveredDeviceId() async {
    final devices = await discoverExoskeletons();
    if (devices.isEmpty) throw StateError('No nearby ExoLeg device was found');
    return devices.first.id;
  }

  Future<void> _connectToDevice(String deviceId) async {
    developer.log('Connecting GATT to $deviceId', name: 'ExoBle');
    final serviceId = Uuid.parse(ExoBleProtocol.serviceUuid);
    try {
      await _native.invokeMethod<void>('connect', {'deviceId': deviceId});
      developer.log('Native GATT connected and services discovered',
          name: 'ExoBle');
    } catch (error) {
      await _resetConnection();
      developer.log('Native GATT connection failed: $error', name: 'ExoBle');
      rethrow;
    }

    final control = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(ExoBleProtocol.controlUuid),
      deviceId: deviceId,
    );
    try {
      await _startStatusSubscription(deviceId);
    } catch (_) {
      await _resetConnection();
      rethrow;
    }
    _control = control;
    _lastDeviceId = deviceId;
    _reconnectAttempt = 0;
    developer.log('GATT transport connected; awaiting user command',
        name: 'ExoBle');
  }

  Future<void> _startStatusSubscription(String deviceId) async {
    await _statusSubscription?.cancel();
    Object? lastError;
    _statusSubscription = _nativeStatus.receiveBroadcastStream().listen(
      (event) {
        try {
          final bytes = List<int>.from(event as List<dynamic>);
          final payload = decodeBleStatus(bytes);
          final type = payload['type'];
          if (type == 'exercise_status') {
            _status.add(ExerciseDeviceStatus.fromJson(payload));
          } else if (type == 'button_event') {
            _buttonEvents.add(ExoButtonEvent.fromJson(payload));
          } else if (type == 'device_status') {
            _deviceStatus.add(LiveDeviceStatus.fromJson(payload));
          } else if (type == 'fall_alert') {
            _fallAlerts.add(FallAlert.fromJson(payload));
          } else if (type == 'transport_status' &&
              payload['state'] == 'disconnected') {
            _control = null;
            developer.log(
              'Native GATT disconnected: ${payload['reason']}',
              name: 'ExoBle',
            );
            _scheduleReconnect();
          }
        } catch (error, stackTrace) {
          developer.log('BLE status decode failed: $error',
              name: 'ExoBle', error: error, stackTrace: stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _control = null;
        developer.log('BLE status channel closed: $error',
            name: 'ExoBle', error: error, stackTrace: stackTrace);
      },
    );
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _native.invokeMethod<void>('subscribe');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return;
      } catch (error, stackTrace) {
        lastError = error;
        developer.log('BLE status subscription retry $attempt failed: $error',
            name: 'ExoBle', error: error, stackTrace: stackTrace);
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    throw StateError('Không đăng ký được trạng thái BLE: $lastError');
  }

  void _scheduleReconnect() {
    if (_disposed ||
        _lastDeviceId == null ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    final delaySeconds = 1 << _reconnectAttempt.clamp(0, 3);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_disposed || isConnected) return;
      try {
        await connect(deviceId: _lastDeviceId);
        developer.log('BLE automatically reconnected', name: 'ExoBle');
      } catch (error) {
        developer.log('BLE automatic reconnect failed: $error', name: 'ExoBle');
        _scheduleReconnect();
      }
    });
  }

  Future<ExerciseDeviceStatus> _waitForExerciseStatus({
    required String sessionId,
    required Set<String> terminalStates,
    Duration timeout = const Duration(seconds: 8),
  }) =>
      status
          .firstWhere((event) =>
              event.sessionId == sessionId &&
              terminalStates.contains(event.state))
          .timeout(timeout);

  Future<void> prepareExercise({
    required String sessionId,
    required String planItemId,
    required String exerciseCode,
    required int sets,
    required int repetitions,
  }) async {
    await connect();
    final acknowledgement = _waitForExerciseStatus(
      sessionId: sessionId,
      terminalStates: const {'prepared', 'not_ready', 'rejected'},
    );
    await _write({
      'type': 'prepare_exercise',
      'session_id': sessionId,
      'plan_item_id': planItemId,
      'exercise_code': exerciseCode,
      'sets': sets,
      'repetitions': repetitions,
    });
    final response = await acknowledgement;
    if (response.state != 'prepared') {
      throw StateError(response.reason ?? 'Thiết bị chưa sẵn sàng');
    }
  }

  Future<void> startExercise({
    required String sessionId,
    required String exerciseCode,
    String planItemId = '',
    String side = 'both',
    int sets = 1,
    int repetitions = 1,
    double assistPercent = 0,
  }) async {
    final resolvedSide = side != 'both'
        ? side
        : (exerciseCode.contains('left')
            ? 'left'
            : (exerciseCode.contains('right') ? 'right' : 'both'));
    final acknowledgement = _waitForExerciseStatus(
      sessionId: sessionId,
      terminalStates: const {'running', 'flexing', 'not_ready', 'rejected'},
    );
    await _sendExerciseCommand(
      sessionId: sessionId,
      exerciseCode: exerciseCode,
      planItemId: planItemId,
      action: 'start',
      side: resolvedSide,
      sets: sets,
      repetitions: repetitions,
      assistPercent: assistPercent,
    );
    final response = await acknowledgement;
    if (response.state == 'not_ready' || response.state == 'rejected') {
      throw StateError(response.reason ?? 'Thiết bị từ chối bắt đầu bài tập');
    }
  }

  Future<void> pauseExercise({
    required String sessionId,
    String exerciseCode = 'walk',
    int sets = 1,
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        action: 'pause',
        sets: sets,
      );

  Future<void> stopExercise({
    required String sessionId,
    String exerciseCode = 'walk',
    int sets = 1,
  }) async {
    final acknowledgement = _waitForExerciseStatus(
      sessionId: sessionId,
      terminalStates: const {'stopped'},
      timeout: const Duration(seconds: 15),
    );
    await _sendExerciseCommand(
      sessionId: sessionId,
      exerciseCode: exerciseCode,
      action: 'stop',
      sets: sets,
    );
    await acknowledgement;
  }

  /// Stops the routine selected from the ESP32 local menu. The local menu
  /// uses `local-ui`, while an active mobile session may have another ID, so
  /// this acknowledgement intentionally matches the physical terminal state
  /// instead of assuming one session identity.
  Future<void> stopForDeviceSelection({required String exerciseCode}) async {
    final acknowledgement = status
        .firstWhere((event) => event.state == 'stopped')
        .timeout(const Duration(seconds: 15));
    await _sendExerciseCommand(
      sessionId: 'local-ui',
      exerciseCode: exerciseCode,
      action: 'stop',
    );
    await acknowledgement;
  }

  /// Sends a server-compiled routine in acknowledged chunks. A normal routine
  /// is larger than one BLE ATT write, even with a negotiated 512-byte MTU.
  Future<void> sendRoutine(
    Map<String, Object?> routine, {
    required String sessionId,
  }) async {
    await connect();
    final payload = <String, Object?>{
      ...routine,
      'v': ExoBleProtocol.protocolVersion,
      'type': 'routine_command',
      'action': 'start',
      'session_id': sessionId,
    };
    final raw = utf8.encode(jsonEncode(payload));
    const rawChunkSize = 180;
    final chunkCount = (raw.length / rawChunkSize).ceil();
    final transferId = '${DateTime.now().microsecondsSinceEpoch}';
    final acknowledgement = _waitForExerciseStatus(
      sessionId: sessionId,
      terminalStates: const {'running', 'not_ready', 'rejected'},
      timeout: const Duration(seconds: 20),
    );
    await _write({
      'type': 'routine_begin',
      'transfer_id': transferId,
      'session_id': sessionId,
      'total_bytes': raw.length,
      'total_chunks': chunkCount,
    });
    for (var index = 0; index < chunkCount; index++) {
      final start = index * rawChunkSize;
      final candidateEnd = start + rawChunkSize;
      final end = candidateEnd < raw.length ? candidateEnd : raw.length;
      await _write({
        'type': 'routine_chunk',
        'transfer_id': transferId,
        'index': index,
        'data': base64Encode(raw.sublist(start, end)),
      });
    }
    await _write({
      'type': 'routine_commit',
      'transfer_id': transferId,
    });
    final response = await acknowledgement;
    if (response.state != 'running') {
      throw StateError(response.reason ?? 'Pi từ chối quy trình');
    }
  }

  Future<void> stopRoutine({required String sessionId}) async {
    final acknowledgement = _waitForExerciseStatus(
      sessionId: sessionId,
      terminalStates: const {'stopped'},
      timeout: const Duration(seconds: 15),
    );
    await _write({
      'type': 'routine_control',
      'action': 'stop',
      'session_id': sessionId,
    });
    await acknowledgement;
  }

  Future<void> sendManualMotor({
    required String motor,
    required String direction,
    required int durationMs,
  }) async {
    if (durationMs != 5000 && durationMs != 7000) {
      throw ArgumentError('Manual duration must be 5000ms or 7000ms');
    }
    if (!const {'C1', 'C2', 'C3', 'C4'}.contains(motor)) {
      throw ArgumentError('Unsupported motor');
    }
    if (!const {'OUT', 'IN'}.contains(direction)) {
      throw ArgumentError('Unsupported direction');
    }
    await connect();
    await _write({
      'type': 'manual_command',
      'action': 'move',
      'motor': motor,
      'direction': direction,
      'duration_ms': durationMs,
    });
  }

  Future<void> stopManualMotors() async {
    if (!isConnected) return;
    await _write({'type': 'manual_command', 'action': 'stop'});
  }

  Future<void> _sendExerciseCommand({
    required String sessionId,
    required String exerciseCode,
    required String action,
    String planItemId = '',
    String side = 'both',
    int sets = 1,
    int repetitions = 1,
    double assistPercent = 0,
  }) async {
    await connect();
    await _write({
      'type': 'exercise_command',
      'session_id': sessionId,
      'plan_item_id': planItemId,
      'exercise_code': exerciseCode,
      'action': action,
      'side': side,
      'sets': sets,
      'repetitions': repetitions,
      'assist_percent': assistPercent,
    });
  }

  Future<void> _write(Map<String, Object?> payload) async {
    final next = _writeQueue.then((_) => _writeUnlocked(payload));
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeUnlocked(Map<String, Object?> payload) async {
    final bytes = ExoBleProtocol.encode(payload);
    if (bytes.length > 384) {
      throw StateError('Lệnh Bluetooth vượt quá giới hạn 384 byte.');
    }
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        if (_control == null) {
          await connect(deviceId: _lastDeviceId);
        }
        // The protocol defines the control point as write-with-response. This
        // also gives Android a definitive ATT completion before a subsequent
        // command or status subscription starts.
        await _native.invokeMethod<void>('write', {
          'value': Uint8List.fromList(bytes),
        });
        developer.log('BLE control write succeeded (attempt $attempt)',
            name: 'ExoBle');
        return;
      } catch (error) {
        lastError = error;
        final transient = _isTransientConnectionError(error);
        if (!transient || attempt == 3) break;
        developer.log(
            'BLE control write waiting for Android GATT (attempt $attempt): $error',
            name: 'ExoBle',
            error: error);
        _control = null;
        await _resetConnection();
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw StateError('Bluetooth chưa sẵn sàng để gửi lệnh: $lastError');
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _statusSubscription?.cancel();
    await _connection?.cancel();
    await _status.close();
    await _deviceStatus.close();
    await _fallAlerts.close();
    await _buttonEvents.close();
  }
}

class ExoBleDevice {
  final String id;
  final String name;
  final int rssi;

  const ExoBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}
