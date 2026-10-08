import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/widgets/exo_kinematic_model.dart';
import 'package:flutter_starter/services/cloudinary/cloudinary_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_starter/services/ble/exo_ble_service.dart';
import 'package:flutter_starter/services/ble/exo_ble_protocol.dart';
import 'package:flutter_starter/presenter/pages/patient/motion_builder.dart';

@RoutePage()
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return _PlanListView(patientId: patientId!);
  }
}

class _PlanListView extends StatefulWidget {
  final String patientId;
  const _PlanListView({required this.patientId});

  @override
  State<_PlanListView> createState() => _PlanListViewState();
}

class _PlanListViewState extends State<_PlanListView> {
  int _selectedIndex = 0;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = provider.get<NetworkDataSource>().getPlanItems(
          widget.patientId,
          scope: _selectedIndex == 0 ? 'today' : 'all',
        );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _PatientTabScaffold(
              title: LocaleKeys.Patient_Tabs_Training.tr(),
              children: [
                if (snapshot.hasError)
                  FilledButton(
                      onPressed: () => setState(_load),
                      child: Text(LocaleKeys.Common_Retry.tr()))
                else
                  const Center(child: CircularProgressIndicator())
              ],
            );
          }
          final items = snapshot.data!;
          return _PatientTabScaffold(
            title: LocaleKeys.Patient_Tabs_Training.tr(),
            children: [
              _TrainingHero(pendingCount: items.length),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MotionRoutineLibraryPage(
                        patientId: widget.patientId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('Bài tập cá nhân'),
                ),
              ),
              const SizedBox(height: 16),
              _SegmentHeader(
                  selectedIndex: _selectedIndex,
                  onChanged: (index) => setState(() {
                        _selectedIndex = index;
                        _load();
                      }),
                  labels: [
                    LocaleKeys.Patient_Training_Today.tr(),
                    LocaleKeys.Patient_Training_All.tr(),
                  ]),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _ExerciseCard(
                  assetPath:
                      '${(item['exercise'] as Map)['image_asset'] ?? ''}',
                  title: _localizedExerciseName(item['exercise'] as Map),
                  subtitle: LocaleKeys.Common_SetsReps.tr(
                    args: [
                      '${(item['target'] as Map)['sets']}',
                      '${(item['target'] as Map)['repetitions_per_set']}',
                    ],
                  ),
                  meta: LocaleKeys.Common_ApproxMinutes.tr(
                    args: [
                      '${((item['estimated_duration_seconds'] as num) / 60).round()}',
                    ],
                  ),
                  chip: _selectedIndex == 0
                      ? LocaleKeys.Patient_Training_Today.tr()
                      : _localizedTrainingStatus('${item['status']}'),
                  icon: Icons.accessibility_new,
                  accent: _AccentTone.primary,
                  progress: 0,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExercisePreparationPage(
                        planItem: item,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
}

String _localizedExerciseName(Map exercise) {
  return _localizedExerciseCopy(exercise, 'name');
}

String _localizedExerciseCopy(Map exercise, String field) {
  final code = exercise['code'];
  final key = switch ('$code:$field') {
    'sit_to_stand:name' => LocaleKeys.Exercises_SitToStand_Name,
    'sit_to_stand:description' => LocaleKeys.Exercises_SitToStand_Description,
    'sit_to_stand:instructions' => LocaleKeys.Exercises_SitToStand_Instructions,
    'sit_to_stand:safety' => LocaleKeys.Exercises_SitToStand_Safety,
    'supported_knee_raise:name' => LocaleKeys.Exercises_SupportedKneeRaise_Name,
    'supported_knee_raise:description' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Description,
    'supported_knee_raise:instructions' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Instructions,
    'supported_knee_raise:safety' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Safety,
    'seated_knee_extension:name' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Name,
    'seated_knee_extension:description' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Description,
    'seated_knee_extension:instructions' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Instructions,
    'seated_knee_extension:safety' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Safety,
    'heel_raises:name' => LocaleKeys.Exercises_HeelRaises_Name,
    'heel_raises:description' => LocaleKeys.Exercises_HeelRaises_Description,
    'heel_raises:instructions' => LocaleKeys.Exercises_HeelRaises_Instructions,
    'heel_raises:safety' => LocaleKeys.Exercises_HeelRaises_Safety,
    'straight_leg_raise:name' => LocaleKeys.Exercises_StraightLegRaise_Name,
    'straight_leg_raise:description' =>
      LocaleKeys.Exercises_StraightLegRaise_Description,
    'straight_leg_raise:instructions' =>
      LocaleKeys.Exercises_StraightLegRaise_Instructions,
    'straight_leg_raise:safety' => LocaleKeys.Exercises_StraightLegRaise_Safety,
    'heel_slides:name' => LocaleKeys.Exercises_HeelSlides_Name,
    'heel_slides:description' => LocaleKeys.Exercises_HeelSlides_Description,
    'heel_slides:instructions' => LocaleKeys.Exercises_HeelSlides_Instructions,
    'heel_slides:safety' => LocaleKeys.Exercises_HeelSlides_Safety,
    'quad_set:name' => LocaleKeys.Exercises_QuadSet_Name,
    'quad_set:description' => LocaleKeys.Exercises_QuadSet_Description,
    'quad_set:instructions' => LocaleKeys.Exercises_QuadSet_Instructions,
    'quad_set:safety' => LocaleKeys.Exercises_QuadSet_Safety,
    'supported_hip_extension:name' =>
      LocaleKeys.Exercises_SupportedHipExtension_Name,
    'supported_hip_extension:description' =>
      LocaleKeys.Exercises_SupportedHipExtension_Description,
    'supported_hip_extension:instructions' =>
      LocaleKeys.Exercises_SupportedHipExtension_Instructions,
    'supported_hip_extension:safety' =>
      LocaleKeys.Exercises_SupportedHipExtension_Safety,
    'walk:name' => LocaleKeys.Exercises_Walk_Name,
    'walk:description' => LocaleKeys.Exercises_Walk_Description,
    'walk:instructions' => LocaleKeys.Exercises_Walk_Instructions,
    'walk:safety' => LocaleKeys.Exercises_Walk_Safety,
    'raise_left_leg:name' => LocaleKeys.Exercises_RaiseLeftLeg_Name,
    'raise_left_leg:description' =>
      LocaleKeys.Exercises_RaiseLeftLeg_Description,
    'raise_left_leg:instructions' =>
      LocaleKeys.Exercises_RaiseLeftLeg_Instructions,
    'raise_left_leg:safety' => LocaleKeys.Exercises_RaiseLeftLeg_Safety,
    'raise_right_leg:name' => LocaleKeys.Exercises_RaiseRightLeg_Name,
    'raise_right_leg:description' =>
      LocaleKeys.Exercises_RaiseRightLeg_Description,
    'raise_right_leg:instructions' =>
      LocaleKeys.Exercises_RaiseRightLeg_Instructions,
    'raise_right_leg:safety' => LocaleKeys.Exercises_RaiseRightLeg_Safety,
    'kick_left_leg:name' => LocaleKeys.Exercises_KickLeftLeg_Name,
    'kick_left_leg:description' => LocaleKeys.Exercises_KickLeftLeg_Description,
    'kick_left_leg:instructions' =>
      LocaleKeys.Exercises_KickLeftLeg_Instructions,
    'kick_left_leg:safety' => LocaleKeys.Exercises_KickLeftLeg_Safety,
    'kick_right_leg:name' => LocaleKeys.Exercises_KickRightLeg_Name,
    'kick_right_leg:description' =>
      LocaleKeys.Exercises_KickRightLeg_Description,
    'kick_right_leg:instructions' =>
      LocaleKeys.Exercises_KickRightLeg_Instructions,
    'kick_right_leg:safety' => LocaleKeys.Exercises_KickRightLeg_Safety,
    'kick_left_knee:name' => LocaleKeys.Exercises_KickLeftKnee_Name,
    'kick_left_knee:description' =>
      LocaleKeys.Exercises_KickLeftKnee_Description,
    'kick_left_knee:instructions' =>
      LocaleKeys.Exercises_KickLeftKnee_Instructions,
    'kick_left_knee:safety' => LocaleKeys.Exercises_KickLeftKnee_Safety,
    'kick_right_knee:name' => LocaleKeys.Exercises_KickRightKnee_Name,
    'kick_right_knee:description' =>
      LocaleKeys.Exercises_KickRightKnee_Description,
    'kick_right_knee:instructions' =>
      LocaleKeys.Exercises_KickRightKnee_Instructions,
    'kick_right_knee:safety' => LocaleKeys.Exercises_KickRightKnee_Safety,
    _ => null,
  };
  final fallbackField = field == 'name' ? 'name' : '${field}_key';
  return key == null ? '${exercise[fallbackField] ?? ''}' : key.tr();
}

String _localizedTrainingStatus(String status) {
  return switch (status) {
    'planned' => LocaleKeys.Patient_Training_Planned.tr(),
    'in_progress' => LocaleKeys.Patient_Training_InProgress.tr(),
    'completed' => LocaleKeys.Patient_Training_Completed.tr(),
    'skipped' => LocaleKeys.Patient_Training_Skipped.tr(),
    _ => status,
  };
}

@RoutePage()
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return _ProgressView(patientId: patientId!);
  }
}

class _ProgressView extends StatefulWidget {
  final String patientId;
  const _ProgressView({required this.patientId});
  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = provider.get<NetworkDataSource>().getProgressOverview(
          widget.patientId,
          period: const ['day', 'week', 'month'][_selectedIndex],
        );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _PatientTabScaffold(
                title: LocaleKeys.Patient_Tabs_Progress.tr(),
                children: [
                  if (snapshot.hasError)
                    _ProgressErrorCard(
                      onRetry: () => setState(_load),
                    )
                  else
                    const Center(child: CircularProgressIndicator())
                ]);
          }
          final data = snapshot.data!;
          final daily = (data['daily'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          final byExercise = (data['by_exercise'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          return _PatientTabScaffold(
              title: LocaleKeys.Patient_Tabs_Progress.tr(),
              children: [
                _ProgressHero(
                  completed: (data['completed_count'] as num?)?.toInt() ?? 0,
                  planned: (data['planned_count'] as num?)?.toInt() ?? 0,
                ),
                const SizedBox(height: 16),
                _SegmentHeader(
                    selectedIndex: _selectedIndex,
                    onChanged: (index) => setState(() {
                          _selectedIndex = index;
                          _load();
                        }),
                    labels: [
                      'Hôm nay',
                      LocaleKeys.Patient_Progress_Week.tr(),
                      LocaleKeys.Patient_Progress_Month.tr(),
                    ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: LocaleKeys.Patient_Progress_Completed.tr(),
                        value:
                            '${data['completed_count']} / ${data['planned_count']}',
                        assetPath:
                            'assets/images/gen_assets/asset_calendar.png',
                        accent: _AccentTone.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: LocaleKeys.Patient_Progress_TrainingTime.tr(),
                        value: LocaleKeys.Common_Minutes.tr(args: [
                          '${((data['active_seconds'] as num) / 60).round()}',
                        ]),
                        assetPath: 'assets/images/gen_assets/asset_clock.png',
                        accent: _AccentTone.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  label: LocaleKeys.Patient_Progress_CorrectMoves.tr(),
                  value:
                      '${((data['correctness_ratio'] as num) * 100).round()}%',
                  assetPath: 'assets/images/gen_assets/asset_progress.png',
                  accent: _AccentTone.neutral,
                ),
                const SizedBox(height: 16),
                _PersonalInsightCard(
                  text: data['insight'] as String? ??
                      'Mỗi phiên tập đều tạo nên tiến bộ của bạn.',
                  streak: (data['streak_days'] as num?)?.toInt() ?? 0,
                ),
                const SizedBox(height: 16),
                _DailyActivityChart(days: daily),
                if (byExercise.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FavoriteExerciseCard(exercises: byExercise),
                ],
                const SizedBox(height: 24),
                Text(
                    LocaleKeys.Patient_Progress_StreakDays.tr(
                      args: ['${data['streak_days']}'],
                    ),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                Text(LocaleKeys.Patient_Progress_RecentHistory.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...((data['recent_sessions'] as List<dynamic>? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .map((session) => _SessionTile(
                          exerciseCode: '${session['exercise_code'] ?? ''}',
                          status: '${session['status'] ?? ''}',
                          startedAt: '${session['started_at'] ?? ''}',
                          repetitions:
                              (session['completed_repetitions'] as num?)
                                      ?.toInt() ??
                                  0,
                          activeSeconds:
                              (session['active_seconds'] as num?)?.toInt() ?? 0,
                        ))),
                if ((data['recent_sessions'] as List<dynamic>? ?? const [])
                    .isEmpty)
                  Text(LocaleKeys.Common_NotEnoughData.tr()),
              ]);
        },
      );
}

class _ProgressErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProgressErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Chưa tải được thống kê',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Dữ liệu luyện tập đang được đồng bộ. Vui lòng thử lại sau một chút.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(LocaleKeys.Common_Retry.tr()),
              ),
            ],
          ),
        ),
      );
}

class _PersonalInsightCard extends StatelessWidget {
  final String text;
  final int streak;

  const _PersonalInsightCard({required this.text, required this.streak});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: colors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gợi ý dành riêng cho bạn',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 5),
                Text(text, style: TextStyle(color: colors.onPrimaryContainer)),
                if (streak > 0) ...[
                  const SizedBox(height: 8),
                  Text('🔥 $streak ngày liên tiếp',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _DailyActivityChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = days
        .map((day) => (day['active_seconds'] as num?)?.toDouble() ?? 0)
        .toList();
    final maximum =
        values.fold<double>(0, (max, value) => value > max ? value : max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhịp tập luyện',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 16),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var index = 0; index < days.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 450),
                                  height: maximum == 0
                                      ? 6
                                      : 8 + 72 * values[index] / maximum,
                                  width: 18,
                                  decoration: BoxDecoration(
                                    color: values[index] > 0
                                        ? colors.primary
                                        : colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_shortDate('${days[index]['date']}'),
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(String value) =>
      value.length >= 5 ? value.substring(5) : value;
}

class _FavoriteExerciseCard extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;

  const _FavoriteExerciseCard({required this.exercises});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final favorite = exercises.first;
    final code = '${favorite['exercise_code'] ?? 'Bài tập'}';
    final reps = (favorite['repetitions'] as num?)?.toInt() ?? 0;
    final sessions = (favorite['session_count'] as num?)?.toInt() ?? 0;
    final activeSeconds = (favorite['active_seconds'] as num?)?.toInt() ?? 0;
    final name = _localizedExerciseName({'code': code});
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.secondaryContainer, colors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    Icon(Icons.trending_up_rounded, color: colors.onSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bài tập nổi bật',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            )),
                    const SizedBox(height: 3),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: colors.onSecondaryContainer),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ExerciseStat(label: 'Lần tập', value: '$sessions'),
              _ExerciseStat(label: 'Số lần', value: '$reps'),
              _ExerciseStat(
                  label: 'Thời gian',
                  value: '${(activeSeconds / 60).round()}p'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseStat extends StatelessWidget {
  final String label;
  final String value;

  const _ExerciseStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    )),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}

@RoutePage()
class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) => _PatientTabScaffold(
        title: LocaleKeys.Patient_Tabs_Device.tr(),
        children: [
          const _LiveDeviceStatusCard(),
          const SizedBox(height: 16),
          const _DeviceModelCard(),
          const SizedBox(height: 16),
          _StatusBanner(
            assetPath: 'assets/images/ic_fill_setting.png',
            title: LocaleKeys.Patient_Device_NoDevice.tr(),
            message:
                'Kết nối Pi qua Bluetooth để xem trạng thái thiết bị trực tiếp.',
            tone: _StatusTone.info,
          ),
        ],
      );
}

class _LiveDeviceStatusCard extends StatefulWidget {
  const _LiveDeviceStatusCard();

  @override
  State<_LiveDeviceStatusCard> createState() => _LiveDeviceStatusCardState();
}

class _LiveDeviceStatusCardState extends State<_LiveDeviceStatusCard> {
  final _ble = ExoBleService.shared;
  StreamSubscription<LiveDeviceStatus>? _subscription;
  LiveDeviceStatus? _liveStatus;
  String _connectionText = 'Chưa chọn Pi qua Bluetooth';
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _subscription = _ble.deviceStatus.listen((status) {
      if (mounted) {
        setState(() {
          _liveStatus = status;
          _connectionText = 'Đã kết nối Pi qua Bluetooth';
        });
      }
    }, onError: (Object error) {
      if (mounted) setState(() => _connectionText = 'Lỗi Bluetooth: $error');
    });
  }

  Future<void> _chooseDevice() async {
    setState(() => _scanning = true);
    try {
      final devices = await _ble.discoverExoskeletons();
      if (!mounted) return;
      final selected = await showDialog<ExoBleDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn thiết bị chân'),
          content: devices.isEmpty
              ? const Text('Không tìm thấy ExoLeg đang quảng bá gần đây.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final device in devices)
                        ListTile(
                          leading: Image.asset(
                            'assets/images/gen_assets/asset_bluetooth.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                          title: Text(device.name),
                          subtitle: Text('Tín hiệu ${device.rssi} dBm'),
                          onTap: () => Navigator.of(context).pop(device),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await _ble.connect(deviceId: selected.id);
      if (mounted) {
        setState(() => _connectionText = 'Đã kết nối Pi qua Bluetooth');
      }
    } catch (error) {
      if (mounted) setState(() => _connectionText = 'Chưa kết nối Pi: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _liveStatus;
    final battery = status == null || status.batteryPercent < 0
        ? 'Chưa có dữ liệu BMS'
        : '${status.batteryPercent.round()}%';
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Image.asset(
                'assets/images/gen_assets/asset_bluetooth.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 8),
              Text('Trạng thái Pi trực tiếp',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 10),
            Text(_connectionText),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text('Trạng thái: ${status.state}'),
              Text('Pin BMS: $battery'),
              Text(
                  'E-stop: ${status.estopActive ? 'ĐANG KÍCH HOẠT' : 'không kích hoạt'}'),
              if (status.faultReason?.isNotEmpty == true)
                Text(status.faultReason!,
                    style: TextStyle(color: scheme.error)),
            ],
            if (status == null && !_ble.isConnected) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _scanning ? null : _chooseDevice,
                icon: const Icon(Icons.refresh),
                label:
                    Text(_scanning ? 'Đang quét…' : 'Chọn thiết bị Bluetooth'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatientApiView<T> extends StatefulWidget {
  final String title;
  final Future<T> Function() load;
  final List<Widget> Function(T data) builder;
  const _PatientApiView(
      {required this.title, required this.load, required this.builder});
  @override
  State<_PatientApiView<T>> createState() => _PatientApiViewState<T>();
}

class _PatientApiViewState<T> extends State<_PatientApiView<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _retry() => setState(() => _future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: const Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: Center(
                    child: FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: Text(LocaleKeys.Common_Retry.tr()))));
          }
          return _PatientTabScaffold(
              title: widget.title,
              children: widget.builder(snapshot.data as T));
        },
      );
}

class PatientNotificationsPage extends StatefulWidget {
  const PatientNotificationsPage({super.key});

  @override
  State<PatientNotificationsPage> createState() =>
      _PatientNotificationsPageState();
}

class _PatientNotificationsPageState extends State<PatientNotificationsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = provider.get<NetworkDataSource>().getNotifications();
  }

  Future<void> _relationshipAction(String linkId, String action) async {
    try {
      await provider
          .get<NetworkDataSource>()
          .updateRelationship(linkId, action);
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept'
              ? 'Đã chấp nhận yêu cầu theo dõi.'
              : 'Đã từ chối yêu cầu theo dõi.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật yêu cầu: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _PatientTabScaffold(
            title: LocaleKeys.Common_Notifications.tr(),
            children: [Center(child: CircularProgressIndicator())],
          );
        }
        if (snapshot.hasError) {
          return _PatientTabScaffold(
            title: LocaleKeys.Common_Notifications.tr(),
            children: [
              Center(child: Text(LocaleKeys.Patient_Home_LoadFailedTitle.tr())),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => setState(_load),
                  child: Text(LocaleKeys.Common_Retry.tr())),
            ],
          );
        }
        final items =
            (snapshot.data ?? const <Map<String, dynamic>>[]).map((item) {
          final severity = item['severity'] as String? ?? 'info';
          final type = item['type']?.toString() ?? '';
          return _NotificationItem(
            icon: type == 'relationship_invite'
                ? Icons.person_add_alt_1_rounded
                : severity == 'warning'
                    ? Icons.warning_amber_rounded
                    : Icons.notifications,
            title: item['title'] as String? ?? '',
            body: item['message'] as String? ?? '',
            time: item['occurred_at'] as String? ?? '',
            tone: severity == 'critical'
                ? _AccentTone.tertiary
                : _AccentTone.primary,
            unread: item['source'] == 'inbox'
                ? item['read_at'] == null
                : item['resolved_at'] == null,
            relationshipInvite: type == 'relationship_invite',
            linkId: item['link_id']?.toString(),
            onRelationshipAction: _relationshipAction,
          );
        }).toList();
        return _PatientTabScaffold(
          title: LocaleKeys.Common_Notifications.tr(),
          children: [
            _NotificationSummary(
                unreadCount: items.where((e) => e.unread).length),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(child: Text(LocaleKeys.Patient_Device_NoDevice.tr()))
            else ...[
              _SegmentHeader(labels: [
                LocaleKeys.Patient_Notifications_All.tr(),
                LocaleKeys.Patient_Notifications_Unread.tr()
              ]),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _NotificationBlock(item: item),
                const SizedBox(height: 12)
              ],
            ],
          ],
        );
      },
    );
  }
}

@RoutePage()
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

void _openProfileInfo(
  BuildContext context,
  String title,
  String subtitle,
  String assetPath,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ProfileInfoPage(
        title: title,
        subtitle: subtitle,
        assetPath: assetPath,
      ),
    ),
  );
}

class _ProfileInfoPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;

  const _ProfileInfoPage({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    assetPath,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    assetPath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(title),
                subtitle: Text(subtitle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openAccountDetails(BuildContext context, Account? account) {
  if (account == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => _AccountDetailsPage(account: account),
  ));
}

class _AccountDetailsPage extends StatelessWidget {
  final Account account;
  const _AccountDetailsPage({required this.account});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar:
          AppBar(title: Text(LocaleKeys.Patient_Profile_PersonalProfile.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/gen_assets/asset_profile.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  )),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(account.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(account.email ?? '—', overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          ),
          const SizedBox(height: 16),
          _AccountField(
              icon: Icons.badge_outlined,
              assetPath: 'assets/images/gen_assets/asset_profile.png',
              label: LocaleKeys.Patient_Profile_Role.tr(),
              value: account.roles.join(', '),
              accent: _AccentTone.primary),
          _AccountField(
              icon: Icons.email_outlined,
              assetPath: 'assets/images/gen_assets/asset_phone.png',
              label: LocaleKeys.Common_Email.tr(),
              value: account.email ?? '—',
              accent: _AccentTone.secondary),
          _AccountField(
              icon: Icons.language_outlined,
              assetPath: 'assets/images/gen_assets/asset_language.png',
              label: LocaleKeys.Common_Locale.tr(),
              value: account.locale ?? '—',
              accent: _AccentTone.tertiary),
          _AccountField(
              icon: Icons.schedule_outlined,
              assetPath: 'assets/images/gen_assets/asset_clock.png',
              label: LocaleKeys.Common_Timezone.tr(),
              value: account.timezone ?? '—',
              accent: _AccentTone.neutral),
          _AccountField(
              icon: Icons.verified_user_outlined,
              assetPath: 'assets/images/gen_assets/asset_privacy.png',
              label: LocaleKeys.Patient_Profile_Status.tr(),
              value: LocaleKeys.Patient_Profile_Active.tr(),
              accent: _AccentTone.secondary),
        ],
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  final IconData icon;
  final String? assetPath;
  final String label;
  final String value;
  final _AccentTone accent;
  const _AccountField(
      {required this.icon,
      this.assetPath,
      required this.label,
      required this.value,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    final colors = _accentColors(Theme.of(context).colorScheme, accent);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: assetPath == null
              ? _TintIcon(
                  icon: icon,
                  background: colors.background,
                  foreground: colors.foreground,
                  size: 48)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    assetPath!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
          title: Text(label),
          subtitle: Text(value),
        ),
      ),
    );
  }
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryUploadService();
  String? _avatarUrl;
  bool _uploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 86,
    );
    if (image == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await _cloudinary.uploadAvatar(image);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.Patient_Profile_UploadSuccess.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.Patient_Profile_UploadFailed.tr()),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;
    final displayName =
        account?.displayName ?? LocaleKeys.Patient_Profile_FallbackName.tr();

    return _PatientTabScaffold(
      title: LocaleKeys.Patient_Tabs_Profile.tr(),
      children: [
        _ProfileHeader(
          displayName: displayName,
          email: account?.email ?? LocaleKeys.Patient_Profile_NoEmail.tr(),
          avatarUrl: _avatarUrl,
          uploading: _uploading,
          onUpload: _pickAndUploadAvatar,
        ),
        const SizedBox(height: 16),
        _ProfileInfoGrid(
          items: [
            _ProfileInfoItem(
              label: LocaleKeys.Patient_Profile_Role.tr(),
              value: account?.roles.join(', ') ??
                  LocaleKeys.Patient_Profile_PatientAccount.tr(),
              icon: Icons.badge_outlined,
              assetPath: 'assets/images/gen_assets/asset_calendar.png',
              accent: _AccentTone.primary,
            ),
            _ProfileInfoItem(
              label: LocaleKeys.Patient_Profile_Status.tr(),
              value: LocaleKeys.Patient_Profile_Active.tr(),
              icon: Icons.verified_user_outlined,
              assetPath: 'assets/images/gen_assets/asset_clock.png',
              accent: _AccentTone.secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: LocaleKeys.Patient_Profile_AccountSection.tr(),
          children: [
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_profile.png',
              label: LocaleKeys.Patient_Profile_PersonalProfile.tr(),
              subtitle: LocaleKeys.Patient_Profile_PersonalProfileSubtitle.tr(),
              onTap: () => _openAccountDetails(context, account),
            ),
            const SizedBox(height: 10),
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_phone.png',
              label: LocaleKeys.Patient_Profile_CareNetwork.tr(),
              subtitle: LocaleKeys.Patient_Profile_CareNetworkSubtitle.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const CareNetworkPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: LocaleKeys.Patient_Profile_SettingsSection.tr(),
          children: [
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_notifications.png',
              label: LocaleKeys.Patient_Profile_Notifications.tr(),
              subtitle: LocaleKeys.Patient_Profile_NotificationsSubtitle.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PatientNotificationsPage(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _LanguageTile(),
            const SizedBox(height: 10),
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_exercise_rehab.png',
              label: LocaleKeys.Patient_Profile_Accessibility.tr(),
              subtitle: LocaleKeys.Patient_Profile_AccessibilitySubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Accessibility.tr(),
                  LocaleKeys.Patient_Profile_AccessibilitySubtitle.tr(),
                  'assets/images/gen_assets/asset_exercise_rehab.png'),
            ),
            const SizedBox(height: 10),
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_privacy.png',
              label: LocaleKeys.Patient_Profile_Privacy.tr(),
              subtitle: LocaleKeys.Patient_Profile_PrivacySubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Privacy.tr(),
                  LocaleKeys.Patient_Profile_PrivacySubtitle.tr(),
                  'assets/images/gen_assets/asset_privacy.png'),
            ),
            const SizedBox(height: 10),
            _MenuTile(
              assetPath: 'assets/images/gen_assets/asset_help.png',
              label: LocaleKeys.Patient_Profile_Help.tr(),
              subtitle: LocaleKeys.Patient_Profile_HelpSubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Help.tr(),
                  LocaleKeys.Patient_Profile_HelpSubtitle.tr(),
                  'assets/images/gen_assets/asset_help.png'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _LogoutButton(),
      ],
    );
  }
}

class CareNetworkPage extends StatefulWidget {
  const CareNetworkPage({super.key});

  @override
  State<CareNetworkPage> createState() => _CareNetworkPageState();
}

class _CareNetworkPageState extends State<CareNetworkPage> {
  final _emailController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _relationships;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _reload() {
    _relationships = provider.get<NetworkDataSource>().getRelationships();
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    try {
      await provider.get<NetworkDataSource>().inviteRelationship(email);
      _emailController.clear();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lời mời liên kết.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi lời mời: $error')),
      );
    }
  }

  Future<void> _change(String id, String action) async {
    try {
      await provider.get<NetworkDataSource>().updateRelationship(id, action);
      if (mounted) setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật liên kết: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.read<AuthBloc>().state.account;
    final isCaregiver = account?.roles.contains('caregiver') ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Mạng lưới chăm sóc')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isCaregiver
                ? 'Thêm người tập để theo dõi an toàn và tiến độ.'
                : 'Thêm người giám sát để họ nhận được cảnh báo an toàn.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText:
                    isCaregiver ? 'Email người tập' : 'Email người giám sát',
                hintText: 'name@example.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: IconButton(
                  onPressed: _invite,
                  tooltip: 'Gửi lời mời',
                  icon: const Icon(Icons.person_add_alt_1),
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
              ),
              onSubmitted: (_) => _invite(),
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _relationships,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final links = snapshot.data ?? const <Map<String, dynamic>>[];
              if (links.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('Chưa có liên kết nào.')),
                );
              }
              return Column(
                children: links.map((link) {
                  final status = link['status']?.toString() ?? '';
                  final otherName = isCaregiver
                      ? link['patient_name']?.toString()
                      : link['caregiver_name']?.toString();
                  final otherEmail = isCaregiver
                      ? link['patient_email']?.toString()
                      : link['caregiver_email']?.toString();
                  final id = link['id']?.toString();
                  final requestedBy = link['requested_by']?.toString();
                  final isIncoming =
                      requestedBy != null && requestedBy != account?.id;
                  final statusLabel = switch (status) {
                    'pending' => isIncoming
                        ? 'Đang chờ bạn xác nhận'
                        : 'Đã gửi — chờ xác nhận',
                    'active' => 'Đang hoạt động',
                    'rejected' => 'Đã từ chối',
                    'revoked' => 'Đã hủy liên kết',
                    _ => status,
                  };
                  return Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(otherName ?? 'Tài khoản liên kết'),
                      subtitle: Text('$otherEmail\n$statusLabel'),
                      isThreeLine: true,
                      trailing: id == null
                          ? null
                          : status == 'pending' && isIncoming
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Từ chối',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => _change(id, 'reject'),
                                    ),
                                    IconButton(
                                      tooltip: 'Chấp nhận',
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      onPressed: () => _change(id, 'accept'),
                                    ),
                                  ],
                                )
                              : status == 'pending'
                                  ? IconButton(
                                      tooltip: 'Hủy lời mời',
                                      icon: const Icon(Icons.cancel_outlined),
                                      onPressed: () => _change(id, 'revoke'),
                                    )
                                  : status == 'active'
                                      ? IconButton(
                                          tooltip: 'Hủy liên kết',
                                          icon: const Icon(Icons.link_off),
                                          onPressed: () =>
                                              _change(id, 'revoke'),
                                        )
                                      : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PatientTabScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PatientTabScaffold({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

class _TrainingHero extends StatelessWidget {
  final int pendingCount;

  const _TrainingHero({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/gen_assets/asset_training_plan.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.Patient_Training_PendingTitle.tr(
                    args: ['$pendingCount'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Training_PendingSubtitle.tr(),
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHero extends StatelessWidget {
  final int completed;
  final int planned;

  const _ProgressHero({required this.completed, required this.planned});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/gen_assets/asset_progress.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.Patient_Progress_HeroTitle.tr(
                    args: ['$completed', '$planned'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Progress_HeroSubtitle.tr(),
                  style: TextStyle(color: colorScheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Retained for the future server-profile view; live BLE data is shown instead.
// ignore: unused_element
class _DeviceHero extends StatelessWidget {
  final String model;
  final int battery;
  final bool ready;

  const _DeviceHero({
    required this.model,
    required this.battery,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _AssetTintIcon(
            assetPath: 'assets/images/ic_fill_setting.png',
            background: colorScheme.primary,
            foreground: colorScheme.onPrimary,
            size: 64,
            iconSize: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  LocaleKeys.Patient_Device_HeroSubtitle.tr(
                    args: [
                      '$battery',
                      ready
                          ? LocaleKeys.Patient_Device_Ready.tr()
                          : LocaleKeys.Patient_Device_NeedsCheck.tr(),
                    ],
                  ),
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceModelCard extends StatelessWidget {
  const _DeviceModelCard();

  bool get _supports3dView =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerLowest,
            colorScheme.secondaryContainer.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                _TintIcon(
                  icon: Icons.view_in_ar_outlined,
                  background: colorScheme.primary,
                  foreground: colorScheme.onPrimary,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleKeys.Patient_Device_ModelTitle.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Icon(Icons.touch_app_outlined,
                    color: colorScheme.primary.withValues(alpha: 0.8)),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            width: double.infinity,
            child: _supports3dView
                ? Semantics(
                    label: LocaleKeys.Patient_Device_PairedModel.tr(),
                    child: const ExoKinematicModel(),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        LocaleKeys.Patient_Device_ModelUnavailable.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Text(
              LocaleKeys.Patient_Device_ModelSubtitle.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ManualControlPage(),
                ),
              ),
              icon: const Icon(Icons.touch_app_rounded),
              label: const Text('Bật điều khiển Manual'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualControlPage extends StatefulWidget {
  const _ManualControlPage();

  @override
  State<_ManualControlPage> createState() => _ManualControlPageState();
}

class _ManualControlPageState extends State<_ManualControlPage> {
  final _ble = ExoBleService.shared;
  String _selectedJoint = 'right_hip';
  String _direction = 'OUT';
  bool _sending = false;
  bool _closing = false;
  String _message = 'Chạm vào một khớp trên mô hình để chọn.';

  static const _jointLabels = {
    'right_hip': 'Hông phải',
    'right_knee': 'Gối phải',
    'left_hip': 'Hông trái',
    'left_knee': 'Gối trái',
  };

  static const _jointMotors = {
    'right_hip': 'C2',
    'right_knee': 'C1',
    'left_hip': 'C4',
    'left_knee': 'C3',
  };

  void _selectJoint(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final key = '${data['side']}_${data['joint']}';
      if (_jointLabels.containsKey(key) && mounted) {
        setState(() {
          _selectedJoint = key;
          _message = '${_jointLabels[key]} đã được chọn.';
        });
      }
    } catch (_) {
      // A malformed hotspot event must never affect motor control.
    }
  }

  Future<void> _move(int durationMs) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _message = 'Đang gửi lệnh tới ${_jointLabels[_selectedJoint]}…';
    });
    try {
      await _ble.sendManualMotor(
        motor: _jointMotors[_selectedJoint]!,
        direction: _direction,
        durationMs: durationMs,
      );
      if (mounted) {
        setState(() {
          _message =
              '${_jointLabels[_selectedJoint]}: ${_direction == 'OUT' ? 'co / nâng' : 'duỗi / hạ'} mức ${durationMs == 7000 ? 'cao' : 'thấp'}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Không gửi được lệnh: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _stopAndClose() async {
    if (_closing) return;
    _closing = true;
    try {
      await _ble.stopManualMotors();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (!_closing) unawaited(_ble.stopManualMotors());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _jointLabels[_selectedJoint]!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Điều khiển Manual'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _stopAndClose,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Thoát Manual',
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: () => _ble.stopManualMotors(),
            icon: const Icon(Icons.stop_rounded),
            tooltip: 'Dừng tất cả',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Manual chỉ dùng khi người tập đã ngồi/đứng an toàn. Mỗi lệnh sẽ tự dừng theo mức đã chọn.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: ExoKinematicModel(onJointSelected: _selectJoint),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(_message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Text('Khớp đang điều khiển: $selected',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _jointLabels.entries
                  .map((entry) => SizedBox(
                        width: width,
                        child: _ManualOptionTile(
                          label: entry.value,
                          icon: entry.key.endsWith('hip')
                              ? Icons.accessibility_new_rounded
                              : Icons.directions_walk_rounded,
                          selected: entry.key == _selectedJoint,
                          onTap: _sending
                              ? null
                              : () =>
                                  setState(() => _selectedJoint = entry.key),
                        ),
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 16),
          Text('Hướng chuyển động',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ManualOptionTile(
                label: 'Co / nâng',
                icon: Icons.arrow_upward_rounded,
                selected: _direction == 'OUT',
                onTap:
                    _sending ? null : () => setState(() => _direction = 'OUT'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ManualOptionTile(
                label: 'Duỗi / hạ',
                icon: Icons.arrow_downward_rounded,
                selected: _direction == 'IN',
                onTap:
                    _sending ? null : () => setState(() => _direction = 'IN'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text('Mức chuyển động',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ManualOptionTile(
                label: 'Thấp',
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: _sending ? null : () => _move(5000),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ManualOptionTile(
                label: 'Cao',
                icon: Icons.keyboard_double_arrow_up_rounded,
                onTap: _sending ? null : () => _move(7000),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _ManualOptionTile(
            label: 'Dừng tất cả xy lanh',
            icon: Icons.stop_circle_outlined,
            danger: true,
            onTap: () => _ble.stopManualMotors(),
          ),
        ],
      ),
    );
  }
}

class _ManualOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool danger;
  final VoidCallback? onTap;

  const _ManualOptionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = danger
        ? scheme.error
        : selected
            ? scheme.primary
            : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: danger
                ? scheme.errorContainer.withValues(alpha: 0.45)
                : selected
                    ? scheme.primaryContainer
                    : scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: danger
                  ? scheme.error.withValues(alpha: 0.55)
                  : selected
                      ? scheme.primary
                      : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(children: [
                Icon(icon, color: foreground, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: foreground, fontWeight: FontWeight.w800)),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded,
                      color: scheme.primary, size: 18),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentHeader extends StatefulWidget {
  final List<String> labels;
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;

  const _SegmentHeader(
      {required this.labels, this.selectedIndex, this.onChanged});

  @override
  State<_SegmentHeader> createState() => _SegmentHeaderState();
}

class _SegmentHeaderState extends State<_SegmentHeader> {
  int _selectedIndex = 0;

  int get selectedIndex => widget.selectedIndex ?? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / widget.labels.length;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * itemWidth + 4,
                top: 5,
                bottom: 5,
                width: itemWidth - 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final entry in widget.labels.indexed)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          widget.onChanged?.call(entry.$1);
                          if (widget.onChanged == null) {
                            setState(() => _selectedIndex = entry.$1);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: selectedIndex == entry.$1
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ) ??
                                TextStyle(
                                  color: selectedIndex == entry.$1
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                            child: Text(entry.$2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String assetPath;
  final String title;
  final String subtitle;
  final String meta;
  final String chip;
  final IconData icon;
  final _AccentTone accent;
  final double progress;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.chip,
    required this.icon,
    required this.accent,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, accent);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  assetPath.isEmpty
                      ? _TintIcon(
                          icon: icon,
                          background: colors.background,
                          foreground: colors.foreground,
                          size: 54,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(assetPath,
                              width: 54, height: 54, fit: BoxFit.cover),
                        ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.foreground),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  color: colors.foreground,
                  backgroundColor: colors.background,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.schedule,
                    label: meta,
                    background: colorScheme.surfaceContainerLow,
                    foreground: colorScheme.onSurfaceVariant,
                  ),
                  _MetaPill(
                    icon: Icons.flag_outlined,
                    label: chip,
                    background: colors.background,
                    foreground: colors.foreground,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExercisePreparationPage extends StatefulWidget {
  final Map planItem;

  const ExercisePreparationPage({required this.planItem});

  @override
  State<ExercisePreparationPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExercisePreparationPage> {
  final _ble = ExoBleService.shared;
  String _deviceStatus = 'Chưa kết nối thiết bị';
  ExerciseDeviceStatus? _liveExercise;
  bool _preparing = false;
  bool _starting = false;
  bool _stopping = false;
  bool _completionSent = false;
  StreamSubscription<ExerciseDeviceStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    if (_ble.isConnected) {
      _deviceStatus = 'Đã kết nối Pi qua Bluetooth';
    }
    _statusSubscription = _ble.status.listen((status) {
      if (mounted) {
        setState(() {
          _liveExercise = status;
          _deviceStatus = status.reason?.isNotEmpty == true
              ? '${status.state}: ${status.reason}'
              : _friendlyExerciseState(status.state);
        });
        if (status.state == 'completed' && !_completionSent) {
          _completionSent = true;
          _recordCompletion(status);
        }
      }
    });
  }

  Future<void> _recordCompletion(ExerciseDeviceStatus status) async {
    final patientId = context.read<AuthBloc>().state.account?.id;
    final exercise = widget.planItem['exercise'] as Map;
    if (patientId == null) return;
    try {
      await provider.get<NetworkDataSource>().completeTrainingSession(
            patientId: patientId,
            sessionId:
                '${widget.planItem['session_id'] ?? widget.planItem['id']}',
            planItemId: '${widget.planItem['id']}',
            exerciseCode: '${exercise['code']}',
            completedRepetitions: status.totalRepetitions,
            activeSeconds: status.activeMs ~/ 1000,
          );
      if (mounted) {
        setState(() => _deviceStatus = 'Đã hoàn thành và đồng bộ tiến độ');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _deviceStatus = 'Đã hoàn thành trên thiết bị, chưa đồng bộ server');
      }
    }
  }

  String _friendlyExerciseState(String state) => switch (state) {
        'running' => LocaleKeys.Patient_Training_RunningExercise.tr(),
        'stopping' => LocaleKeys.Patient_Training_StoppingExercise.tr(),
        'flexing' => LocaleKeys.Patient_Training_FlexingExercise.tr(),
        'extending' => LocaleKeys.Patient_Training_ExtendingExercise.tr(),
        'paused' => LocaleKeys.Patient_Training_PausedExercise.tr(),
        'completed' => LocaleKeys.Patient_Training_CompletedExercise.tr(),
        'stopped' => LocaleKeys.Patient_Training_StoppedExercise.tr(),
        'prepared' => LocaleKeys.Patient_Training_PreparedExercise.tr(),
        'not_ready' => LocaleKeys.Patient_Training_NotReadyExercise.tr(),
        'selected' => LocaleKeys.Patient_Training_SelectedExercise.tr(),
        _ => state,
      };

  Future<void> _start() async {
    final exercise = widget.planItem['exercise'] as Map;
    final target = widget.planItem['target'] as Map? ?? const {};
    setState(() => _starting = true);
    try {
      // Starting is an atomic user flow: always prepare this exact session
      // first, wait for the Pi acknowledgement, then issue START.
      await _ble.prepareExercise(
        sessionId: '${widget.planItem['session_id'] ?? widget.planItem['id']}',
        planItemId: '${widget.planItem['id']}',
        exerciseCode: '${exercise['code']}',
        sets: (target['sets'] as num?)?.toInt() ?? 1,
        repetitions: (target['repetitions_per_set'] as num?)?.toInt() ?? 1,
      );
      await _ble.startExercise(
        sessionId: '${widget.planItem['session_id'] ?? widget.planItem['id']}',
        planItemId: '${widget.planItem['id']}',
        exerciseCode: '${exercise['code']}',
        sets: (target['sets'] as num?)?.toInt() ?? 1,
        repetitions: (target['repetitions_per_set'] as num?)?.toInt() ?? 1,
      );
      if (mounted) {
        setState(() => _deviceStatus = 'Đã bắt đầu bài tập');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _deviceStatus = 'Không bắt đầu được: $error');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _prepare() async {
    final target = widget.planItem['target'] as Map? ?? const {};
    final exercise = widget.planItem['exercise'] as Map;
    setState(() => _preparing = true);
    try {
      await _ble.prepareExercise(
        sessionId: '${widget.planItem['session_id'] ?? widget.planItem['id']}',
        planItemId: '${widget.planItem['id']}',
        exerciseCode: '${exercise['code']}',
        sets: (target['sets'] as num?)?.toInt() ?? 0,
        repetitions: (target['repetitions_per_set'] as num?)?.toInt() ?? 0,
      );
      if (mounted) {
        setState(() => _deviceStatus = 'Đã gửi yêu cầu chuẩn bị bài tập');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _deviceStatus =
            'Chưa gửi được lệnh. Hãy giữ kết nối Bluetooth và thử lại.');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _stop() async {
    final exercise = widget.planItem['exercise'] as Map;
    setState(() => _stopping = true);
    try {
      await _ble.stopExercise(
        sessionId: '${widget.planItem['session_id'] ?? widget.planItem['id']}',
        exerciseCode: '${exercise['code']}',
      );
      if (mounted) {
        setState(() => _deviceStatus = 'Đã đưa chân về vị trí ban đầu');
      }
    } catch (error) {
      if (mounted) setState(() => _deviceStatus = 'Không dừng được: $error');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final exercise = widget.planItem['exercise'] as Map;
    final title = _localizedExerciseName(exercise);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                _ExerciseAsset(
                  assetPath: '${exercise['image_asset'] ?? ''}',
                  fallback: Icons.accessibility_new,
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ExerciseDetailSection(
            icon: Icons.info_outline,
            title: LocaleKeys.Common_Description.tr(),
            content: _localizedExerciseCopy(exercise, 'description'),
            color: colorScheme.primary,
          ),
          _ExerciseDetailSection(
            icon: Icons.format_list_numbered,
            title: LocaleKeys.Common_Instructions.tr(),
            content: _localizedExerciseCopy(exercise, 'instructions'),
            color: colorScheme.tertiary,
          ),
          _ExerciseDetailSection(
            icon: Icons.health_and_safety_outlined,
            title: LocaleKeys.Common_Safety.tr(),
            content: _localizedExerciseCopy(exercise, 'safety'),
            color: colorScheme.error,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _preparing || !_ble.isConnected ? null : _prepare,
            icon: _preparing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_connected),
            label: const Text('Chuẩn bị bài tập trên thiết bị'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _starting || !_ble.isConnected ? null : _start,
            icon: _starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('Bắt đầu bài tập'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _stopping || !_ble.isConnected ? null : _stop,
            icon: _stopping
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.stop_circle_outlined),
            label: const Text('Dừng và đưa chân về ban đầu'),
          ),
          const SizedBox(height: 8),
          Text('Trạng thái thiết bị: $_deviceStatus',
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
          if (_liveExercise != null) ...[
            const SizedBox(height: 14),
            _ExerciseTelemetryCard(status: _liveExercise!),
          ],
          if (!_ble.isConnected) ...[
            const SizedBox(height: 8),
            Text(
                'Hãy kết nối ExoLeg-1 trong tab Thiết bị trước khi chuẩn bị bài tập.',
                style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Text(LocaleKeys.Exercises_Disclaimer.tr(),
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ExerciseTelemetryCard extends StatelessWidget {
  final ExerciseDeviceStatus status;

  const _ExerciseTelemetryCard({required this.status});

  String _duration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final target = status.targetTotalRepetitions;
    final progress =
        target == 0 ? 0.0 : (status.totalRepetitions / target).clamp(0.0, 1.0);
    final averageSeconds = status.totalRepetitions == 0
        ? 0.0
        : status.activeMs / 1000 / status.totalRepetitions;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.insights, color: colors.onSecondaryContainer),
              const SizedBox(width: 8),
              Text('Tiến độ trực tiếp',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TelemetryChip(
                  icon: Icons.repeat,
                  label: '${status.totalRepetitions}/$target lần',
                ),
                _TelemetryChip(
                  icon: Icons.layers_outlined,
                  label: '${status.completedSets}/${status.targetSets} set',
                ),
                _TelemetryChip(
                  icon: Icons.timer_outlined,
                  label: _duration(status.activeMs),
                ),
                _TelemetryChip(
                  icon: Icons.speed,
                  label: '${averageSeconds.toStringAsFixed(1)}s/lần',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TelemetryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: colors.onSecondaryContainer)),
        ],
      ),
    );
  }
}

class _ExerciseDetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _ExerciseDetailSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium)
          ]),
          const SizedBox(height: 10),
          Text(content),
        ],
      ),
    );
  }
}

class _TintIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  const _TintIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: foreground, size: size * 0.54),
    );
  }
}

class _ExerciseAsset extends StatelessWidget {
  final String assetPath;
  final IconData fallback;
  final double size;

  const _ExerciseAsset({
    required this.assetPath,
    required this.fallback,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (assetPath.isEmpty) {
      return _TintIcon(
        icon: fallback,
        background: scheme.primary,
        foreground: scheme.onPrimary,
        size: size,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child:
          Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class _AssetTintIcon extends StatelessWidget {
  final String assetPath;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  const _AssetTintIcon({
    required this.assetPath,
    required this.background,
    required this.foreground,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Center(
        child: ImageIcon(
          AssetImage(assetPath),
          color: foreground,
          size: iconSize,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

enum _AccentTone { primary, secondary, tertiary, neutral }

({Color background, Color foreground}) _accentColors(
  ColorScheme colorScheme,
  _AccentTone tone,
) {
  return switch (tone) {
    _AccentTone.primary => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.primary,
      ),
    _AccentTone.secondary => (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.secondary,
      ),
    _AccentTone.tertiary => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.tertiary,
      ),
    _AccentTone.neutral => (
        background: Colors.white,
        foreground: colorScheme.primary,
      ),
  };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String assetPath;
  final _AccentTone accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.assetPath,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, accent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
        border: accent == _AccentTone.neutral
            ? Border.all(color: colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              assetPath,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String assetPath;
  final String title;
  final String message;
  final _StatusTone tone;

  const _StatusBanner({
    required this.assetPath,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _StatusTone.ready => (
          foreground: Theme.of(context).colorScheme.secondary,
          background: Theme.of(context).colorScheme.secondaryContainer,
        ),
      _StatusTone.info => (
          foreground: Theme.of(context).colorScheme.primary,
          background: Theme.of(context).colorScheme.primaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _AssetTintIcon(
            assetPath: assetPath,
            background: colors.foreground.withValues(alpha: 0.14),
            foreground: colors.foreground,
            size: 56,
            iconSize: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusTone { ready, info }

// ignore: unused_element
class _InfoTile extends StatelessWidget {
  final String assetPath;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: _AssetTintIcon(
          assetPath: assetPath,
          background: colorScheme.primaryContainer,
          foreground: colorScheme.primary,
          size: 56,
          iconSize: 31,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onUpload;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: colorScheme.primary,
                foregroundImage:
                    avatarUrl == null ? null : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          'assets/images/gen_assets/asset_profile.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Tooltip(
                  message: LocaleKeys.Patient_Profile_UploadPhoto.tr(),
                  child: IconButton.filled(
                    onPressed: uploading ? null : onUpload,
                    icon: uploading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: uploading ? null : onUpload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(LocaleKeys.Patient_Profile_UploadPhoto.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoGrid extends StatelessWidget {
  final List<_ProfileInfoItem> items;

  const _ProfileInfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in items.indexed) ...[
          if (entry.$1 > 0) const SizedBox(width: 12),
          Expanded(child: _ProfileInfoCard(item: entry.$2)),
        ],
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final _ProfileInfoItem item;

  const _ProfileInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, item.accent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item.assetPath == null
              ? Icon(item.icon, color: colors.foreground)
              : Image.asset(
                  item.assetPath!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoItem {
  final String label;
  final String value;
  final IconData icon;
  final String? assetPath;
  final _AccentTone accent;

  const _ProfileInfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.assetPath,
    required this.accent,
  });
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String assetPath;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.assetPath,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            assetPath,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  final int unreadCount;

  const _NotificationSummary({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Image.asset(
              'assets/images/gen_assets/asset_notifications.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.Patient_Notifications_SummaryTitle.tr(
                    args: ['$unreadCount'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Notifications_SummaryBody.tr(),
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBlock extends StatelessWidget {
  final _NotificationItem item;

  const _NotificationBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, item.tone);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.unread
              ? colors.foreground.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TintIcon(
              icon: item.icon,
              background: colors.background,
              foreground: colors.foreground,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (item.unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (item.relationshipInvite && item.linkId != null) ...[
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => item.onRelationshipAction
                              ?.call(item.linkId!, 'reject'),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => item.onRelationshipAction
                              ?.call(item.linkId!, 'accept'),
                          child: const Text('Chấp nhận'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      _MetaPill(
                        icon: Icons.schedule,
                        label: item.time,
                        background: colorScheme.surfaceContainerLow,
                        foreground: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final _AccentTone tone;
  final bool unread;
  final bool relationshipInvite;
  final String? linkId;
  final Future<void> Function(String linkId, String action)?
      onRelationshipAction;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.tone,
    required this.unread,
    this.relationshipInvite = false,
    this.linkId,
    this.onRelationshipAction,
  });
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLanguage = context.locale.languageCode == 'vi'
        ? LocaleKeys.Common_Vietnamese.tr()
        : LocaleKeys.Common_English.tr();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLanguagePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/gen_assets/asset_language.png',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.Common_Language.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentLanguage,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  LocaleKeys.Patient_Profile_ChooseLanguage.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                title: LocaleKeys.Common_English.tr(),
                subtitle: LocaleKeys.Patient_Profile_EnglishSubtitle.tr(),
                selected: context.locale.languageCode == 'en',
                color: colorScheme.primary,
                onTap: () async => _setLocale(sheetContext, const Locale('en')),
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                title: LocaleKeys.Common_Vietnamese.tr(),
                subtitle: LocaleKeys.Patient_Profile_VietnameseSubtitle.tr(),
                selected: context.locale.languageCode == 'vi',
                color: colorScheme.tertiary,
                onTap: () async => _setLocale(sheetContext, const Locale('vi')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(Icons.language, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? color : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ActionRow extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final IconData primaryIcon;
  final IconData secondaryIcon;

  const _ActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryIcon,
    required this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showActionDialog(context, primaryLabel),
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _showActionDialog(context, secondaryLabel),
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          ),
        ),
      ],
    );
  }

  void _showActionDialog(BuildContext context, String action) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Text(LocaleKeys.Patient_Device_HeroSubtitle.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.Common_Ok.tr())),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String exerciseCode;
  final String status;
  final String startedAt;
  final int repetitions;
  final int activeSeconds;

  const _SessionTile({
    required this.exerciseCode,
    required this.status,
    required this.startedAt,
    required this.repetitions,
    required this.activeSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final completed = status == 'completed';
    final name = _localizedExerciseName({'code': exerciseCode});
    final date = DateTime.tryParse(startedAt);
    final dateLabel = date == null
        ? 'Vừa cập nhật'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: completed
                  ? colorScheme.primaryContainer
                  : colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              completed ? Icons.check_rounded : Icons.schedule_rounded,
              color: completed
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? exerciseCode : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 5),
                Text(
                    '$dateLabel · $repetitions lần · ${(activeSeconds / 60).round()} phút',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: completed
                  ? colorScheme.primaryContainer
                  : colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              completed ? 'Đã xong' : _localizedTrainingStatus(status),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: completed
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton();

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _submitting = false;

  Future<void> _logout() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
    });

    try {
      await provider.get<AuthRepository>().logout();
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthLoggedOut());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _logout,
        icon: const Icon(Icons.logout),
        label: Text(
          _submitting
              ? LocaleKeys.Common_LoggingOut.tr()
              : LocaleKeys.Common_Logout.tr(),
        ),
      ),
    );
  }
}
