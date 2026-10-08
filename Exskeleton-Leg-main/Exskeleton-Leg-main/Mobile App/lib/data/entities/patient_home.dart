class PatientHome {
  final HomePatient patient;
  final HomeDevice? device;
  final NextPlanItem? nextPlanItem;
  final TodayMetrics todayMetrics;
  final List<HomeAlert> openAlerts;

  const PatientHome({
    required this.patient,
    required this.device,
    required this.nextPlanItem,
    required this.todayMetrics,
    required this.openAlerts,
  });

  factory PatientHome.fromJson(Map<String, dynamic> json) => PatientHome(
        patient: HomePatient.fromJson(json['patient'] as Map<String, dynamic>),
        device: json['device'] is Map<String, dynamic>
            ? HomeDevice.fromJson(json['device'] as Map<String, dynamic>)
            : null,
        nextPlanItem: json['next_plan_item'] is Map<String, dynamic>
            ? NextPlanItem.fromJson(
                json['next_plan_item'] as Map<String, dynamic>,
              )
            : null,
        todayMetrics: TodayMetrics.fromJson(
          json['today_metrics'] as Map<String, dynamic>,
        ),
        openAlerts: (json['open_alerts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HomeAlert.fromJson)
            .toList(growable: false),
      );
}

class HomePatient {
  final String id;
  final String displayName;
  final String timezone;

  const HomePatient({
    required this.id,
    required this.displayName,
    required this.timezone,
  });

  factory HomePatient.fromJson(Map<String, dynamic> json) => HomePatient(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        timezone: json['timezone'] as String,
      );
}

class HomeDevice {
  final String id;
  final String serialNumber;
  final bool online;
  final int batteryPercent;
  final String? lastSeenAt;
  final Readiness readiness;

  const HomeDevice({
    required this.id,
    required this.serialNumber,
    required this.online,
    required this.batteryPercent,
    required this.lastSeenAt,
    required this.readiness,
  });

  factory HomeDevice.fromJson(Map<String, dynamic> json) => HomeDevice(
        id: json['id'] as String,
        serialNumber: json['serial_number'] as String,
        online: json['online'] as bool? ?? false,
        batteryPercent: json['battery_percent'] as int? ?? 0,
        lastSeenAt: json['last_seen_at'] as String?,
        readiness: Readiness.fromJson(
          json['readiness'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

class Readiness {
  final String state;
  final List<String> blockingReasons;

  const Readiness({
    required this.state,
    required this.blockingReasons,
  });

  factory Readiness.fromJson(Map<String, dynamic> json) => Readiness(
        state: json['state'] as String? ?? 'unknown',
        blockingReasons:
            (json['blocking_reasons'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(growable: false),
      );
}

class NextPlanItem {
  final String id;
  final String exerciseId;
  final String exerciseCode;
  final String exerciseName;
  final String imageAsset;
  final ExerciseTarget target;
  final String assistanceLevel;
  final int estimatedDurationSeconds;

  const NextPlanItem({
    required this.id,
    required this.exerciseId,
    required this.exerciseCode,
    required this.exerciseName,
    required this.imageAsset,
    required this.target,
    required this.assistanceLevel,
    required this.estimatedDurationSeconds,
  });

  factory NextPlanItem.fromJson(Map<String, dynamic> json) => NextPlanItem(
        id: json['id'] as String,
        exerciseId: json['exercise_id'] as String,
        exerciseCode: json['exercise_code'] as String? ?? '',
        exerciseName: json['exercise_name'] as String,
        imageAsset: json['image_asset'] as String? ?? '',
        target: ExerciseTarget.fromJson(
          json['target'] as Map<String, dynamic>,
        ),
        assistanceLevel: json['assistance_level'] as String,
        estimatedDurationSeconds:
            json['estimated_duration_seconds'] as int? ?? 0,
      );
}

class ExerciseTarget {
  final String kind;
  final int sets;
  final int repetitionsPerSet;

  const ExerciseTarget({
    required this.kind,
    required this.sets,
    required this.repetitionsPerSet,
  });

  factory ExerciseTarget.fromJson(Map<String, dynamic> json) => ExerciseTarget(
        kind: json['kind'] as String? ?? 'unknown',
        sets: json['sets'] as int? ?? 0,
        repetitionsPerSet: json['repetitions_per_set'] as int? ?? 0,
      );
}

class TodayMetrics {
  final int plannedCount;
  final int completedCount;
  final int activeSeconds;
  final double? correctnessRatio;

  const TodayMetrics({
    required this.plannedCount,
    required this.completedCount,
    required this.activeSeconds,
    required this.correctnessRatio,
  });

  factory TodayMetrics.fromJson(Map<String, dynamic> json) => TodayMetrics(
        plannedCount: json['planned_count'] as int? ?? 0,
        completedCount: json['completed_count'] as int? ?? 0,
        activeSeconds: json['active_seconds'] as int? ?? 0,
        correctnessRatio: (json['correctness_ratio'] as num?)?.toDouble(),
      );
}

class HomeAlert {
  final String id;
  final String severity;
  final String title;
  final String occurredAt;

  const HomeAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.occurredAt,
  });

  factory HomeAlert.fromJson(Map<String, dynamic> json) => HomeAlert(
        id: json['id'] as String,
        severity: json['severity'] as String? ?? 'info',
        title: json['title'] as String,
        occurredAt: json['occurred_at'] as String,
      );
}
