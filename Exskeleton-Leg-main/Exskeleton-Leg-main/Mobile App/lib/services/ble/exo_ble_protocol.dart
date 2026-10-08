import 'dart:convert';

/// Stable GATT UUIDs. Change only with an explicit protocol-version migration.
abstract final class ExoBleProtocol {
  // GATT schema v2. The UUID namespace changed to invalidate Android's stale
  // service cache from the earlier encrypted/bonding experiments.
  static const serviceUuid = '6e400101-b5a3-f393-e0a9-e50e24dcca9e';
  static const controlUuid = '6e400102-b5a3-f393-e0a9-e50e24dcca9e';
  static const statusUuid = '6e400103-b5a3-f393-e0a9-e50e24dcca9e';
  static const protocolVersion = 1;

  static List<int> encode(Map<String, Object?> value) =>
      utf8.encode(jsonEncode({'v': protocolVersion, ...value}));
}

class ExerciseDeviceStatus {
  final String state;
  final String? exerciseCode;
  final String? sessionId;
  final String? reason;
  final int? completedRepetitions;
  final int completedSets;
  final int targetSets;
  final int targetRepetitions;
  final int elapsedMs;
  final int activeMs;
  final int repetitionDurationMs;
  final int totalRepetitions;
  final int targetTotalRepetitions;

  const ExerciseDeviceStatus({
    required this.state,
    this.exerciseCode,
    this.sessionId,
    this.reason,
    this.completedRepetitions,
    this.completedSets = 0,
    this.targetSets = 0,
    this.targetRepetitions = 0,
    this.elapsedMs = 0,
    this.activeMs = 0,
    this.repetitionDurationMs = 0,
    this.totalRepetitions = 0,
    this.targetTotalRepetitions = 0,
  });

  factory ExerciseDeviceStatus.fromJson(Map<String, dynamic> json) =>
      ExerciseDeviceStatus(
        state: json['state'] as String,
        exerciseCode: json['exercise_code'] as String?,
        sessionId: json['session_id'] as String?,
        reason: json['reason'] as String?,
        completedRepetitions: (json['completed_repetitions'] as num?)?.toInt(),
        completedSets: (json['completed_sets'] as num?)?.toInt() ?? 0,
        targetSets: (json['target_sets'] as num?)?.toInt() ?? 0,
        targetRepetitions: (json['target_repetitions'] as num?)?.toInt() ?? 0,
        elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
        activeMs: (json['active_ms'] as num?)?.toInt() ?? 0,
        repetitionDurationMs:
            (json['repetition_duration_ms'] as num?)?.toInt() ?? 0,
        totalRepetitions: (json['total_repetitions'] as num?)?.toInt() ?? 0,
        targetTotalRepetitions:
            (json['target_total_repetitions'] as num?)?.toInt() ?? 0,
      );
}

class ExoButtonEvent {
  final String button;
  final String action;

  const ExoButtonEvent({required this.button, required this.action});

  factory ExoButtonEvent.fromJson(Map<String, dynamic> json) => ExoButtonEvent(
        button: json['button']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
      );
}

class LiveDeviceStatus {
  final String state;
  final double batteryPercent;
  final double batteryVoltage;
  final bool estopActive;
  final bool commandWatchdogOk;
  final String? faultReason;

  const LiveDeviceStatus({
    required this.state,
    required this.batteryPercent,
    required this.batteryVoltage,
    required this.estopActive,
    required this.commandWatchdogOk,
    this.faultReason,
  });

  factory LiveDeviceStatus.fromJson(Map<String, dynamic> json) =>
      LiveDeviceStatus(
        state: json['state'] as String,
        batteryPercent: (json['battery_percent'] as num).toDouble(),
        batteryVoltage: (json['battery_voltage'] as num?)?.toDouble() ?? -1.0,
        estopActive: json['estop_active'] as bool,
        commandWatchdogOk: json['command_watchdog_ok'] as bool,
        faultReason: json['fault_reason'] as String?,
      );
}

class FallAlert {
  final String alertId;
  final String deviceId;
  final int predictedClass;
  final String predictedLabel;
  final double fallProbability;
  final int consecutiveFallWindows;
  final bool confirmed;
  final int? timestampMs;

  const FallAlert({
    required this.alertId,
    required this.deviceId,
    required this.predictedClass,
    required this.predictedLabel,
    required this.fallProbability,
    required this.consecutiveFallWindows,
    required this.confirmed,
    this.timestampMs,
  });

  factory FallAlert.fromJson(Map<String, dynamic> json) => FallAlert(
        alertId: json['alert_id']?.toString() ?? '',
        deviceId: json['device_id']?.toString() ?? '',
        predictedClass: (json['predicted_class'] as num?)?.toInt() ?? 3,
        predictedLabel: json['predicted_label']?.toString() ?? 'Fall',
        fallProbability: (json['fall_probability'] as num?)?.toDouble() ?? 0,
        consecutiveFallWindows:
            (json['consecutive_fall_windows'] as num?)?.toInt() ?? 0,
        confirmed: json['confirmed'] == true,
        timestampMs: (json['timestamp_ms'] as num?)?.toInt(),
      );
}

Map<String, dynamic> decodeBleStatus(List<int> bytes) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (json['v'] != ExoBleProtocol.protocolVersion) {
    throw const FormatException('Unsupported exoskeleton BLE protocol');
  }
  return json;
}
