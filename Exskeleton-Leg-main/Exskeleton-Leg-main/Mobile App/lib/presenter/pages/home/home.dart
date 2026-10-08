import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/repositories/home_repository/home_repository.default.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/pages/home/home_cubit.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_placeholders.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';

@RoutePage()
class HomePage extends StatelessWidget implements AutoRouteWrapper {
  const HomePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LogoutCubit(provider.get<AuthRepository>()),
        ),
        BlocProvider(
          create: (_) => HomeCubit(
            repository: DefaultHomeRepository(
              networkDataSource: provider.get<NetworkDataSource>(),
            ),
          )..load(patientId),
        ),
      ],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(LocaleKeys.Patient_Tabs_Today.tr()),
        ),
        actions: [
          IconButton(
            tooltip: LocaleKeys.Common_Notifications.tr(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PatientNotificationsPage(),
              ),
            ),
            icon: Image.asset(
              'assets/images/gen_assets/asset_notifications.png',
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          ),
          BlocConsumer<LogoutCubit, LogoutStatus>(
            listener: (context, status) {
              if (status == LogoutStatus.success) {
                context.read<AuthBloc>().add(const AuthLoggedOut());
              }
            },
            builder: (context, status) => IconButton(
              tooltip: LocaleKeys.Common_Logout.tr(),
              onPressed: status == LogoutStatus.submitting
                  ? null
                  : () => context.read<LogoutCubit>().logout(),
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return switch (state.status) {
              HomeStatus.initial || HomeStatus.loading => const _HomeLoading(),
              HomeStatus.failure => _HomeError(
                  onRetry: () => context.read<HomeCubit>().load(
                        context.read<AuthBloc>().state.account?.id,
                      ),
                ),
              HomeStatus.content => _HomeContent(home: state.home),
            };
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final PatientHome? home;

  const _HomeContent({required this.home});

  @override
  Widget build(BuildContext context) {
    final data = home;
    if (data == null) {
      return _HomeError(onRetry: () {});
    }

    final nextPlanItem = data.nextPlanItem;
    final metrics = data.todayMetrics;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HomeHero(displayName: data.patient.displayName),
        const SizedBox(height: 20),
        const _HomeStatusBanner(),
        const SizedBox(height: 20),
        if (nextPlanItem == null)
          const _EmptyPlanCard()
        else
          _NextExerciseCard(planItem: nextPlanItem),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                assetPath: 'assets/images/gen_assets/asset_exercises.png',
                icon: Icons.task_alt,
                value: '${metrics.completedCount} / ${metrics.plannedCount}',
                label: LocaleKeys.Patient_Home_CompletedExercises.tr(),
                background: colorScheme.primaryContainer,
                foreground: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TodayMetric(
                assetPath: 'assets/images/gen_assets/asset_clock.png',
                icon: Icons.timer_outlined,
                value: _minutesLabel(metrics.activeSeconds),
                label: LocaleKeys.Patient_Home_TrainingTime.tr(),
                background: colorScheme.secondaryContainer,
                foreground: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TodayMetric(
          assetPath: 'assets/images/gen_assets/asset_progress.png',
          icon: Icons.check_circle_outline,
          value: _ratioLabel(metrics.correctnessRatio),
          label: LocaleKeys.Patient_Home_CorrectMoves.tr(),
          background: colorScheme.tertiaryContainer,
          foreground: colorScheme.onTertiaryContainer,
        ),
        const SizedBox(height: 24),
        Text(LocaleKeys.Patient_Home_NeedsAttention.tr(),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (data.openAlerts.isEmpty)
          const _NoAlertPreview()
        else
          _AlertPreview(alert: data.openAlerts.first),
      ],
    );
  }

  String _minutesLabel(int activeSeconds) {
    final minutes = (activeSeconds / 60).round();
    return LocaleKeys.Common_Minutes.tr(args: ['$minutes']);
  }

  String _ratioLabel(double? ratio) {
    if (ratio == null) return LocaleKeys.Common_NotEnoughData.tr();
    return '${(ratio * 100).round()}%';
  }
}

class _HomeHero extends StatelessWidget {
  final String displayName;

  const _HomeHero({required this.displayName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/gen_assets/asset_profile.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.Patient_Home_Greeting.tr(args: [displayName]),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  LocaleKeys.Patient_Home_HeroSubtitle.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(width: 180, height: 28, color: colorScheme.surfaceContainer),
        const SizedBox(height: 12),
        Container(width: 260, height: 20, color: colorScheme.surfaceContainer),
        const SizedBox(height: 20),
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: i == 1 ? 160 : 88,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HomeError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.Patient_Home_LoadFailedTitle.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.Patient_Home_LoadFailedSubtitle.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(LocaleKeys.Common_Retry.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStatusBanner extends StatelessWidget {
  const _HomeStatusBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatusContainer(
      icon: Icons.bluetooth_searching,
      assetPath: 'assets/images/gen_assets/asset_bluetooth.png',
      foreground: colorScheme.primary,
      background: colorScheme.primaryContainer,
      title: 'Trạng thái thiết bị chưa được kết nối',
      message:
          'Mở tab Thiết bị và kết nối Pi qua Bluetooth để xem dữ liệu trực tiếp.',
    );
  }
}

class _StatusContainer extends StatelessWidget {
  final IconData icon;
  final String? assetPath;
  final Color foreground;
  final Color background;
  final String title;
  final String message;

  const _StatusContainer({
    required this.icon,
    this.assetPath,
    required this.foreground,
    required this.background,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: assetPath == null
                ? Icon(icon, color: foreground, size: 30)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(assetPath!,
                        width: 48, height: 48, fit: BoxFit.cover),
                  ),
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
          IconButton(
            tooltip: LocaleKeys.Patient_Device_ViewDeviceTooltip.tr(),
            onPressed: () => context.router.push(const DeviceRoute()),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _NextExerciseCard extends StatelessWidget {
  final NextPlanItem planItem;

  const _NextExerciseCard({required this.planItem});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _HomeAsset(
                    assetPath: planItem.imageAsset.isNotEmpty
                        ? planItem.imageAsset
                        : 'assets/images/gen_assets/asset_exercises.png',
                    size: 52,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    planItem.exerciseName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip(
                  icon: Icons.repeat,
                  label: LocaleKeys.Common_SetsReps.tr(
                    args: [
                      '${planItem.target.sets}',
                      '${planItem.target.repetitionsPerSet}',
                    ],
                  ),
                ),
                _PlanChip(
                  icon: Icons.schedule,
                  label: _minutesLabel(planItem.estimatedDurationSeconds),
                ),
                _PlanChip(
                  icon: Icons.tune,
                  label: LocaleKeys.Patient_Home_Assistance.tr(
                    args: [_assistanceLabel(planItem.assistanceLevel)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.router.push(const TrainingRoute()),
                icon: const Icon(Icons.play_arrow),
                label: Text(LocaleKeys.Patient_Home_StartExercise.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _minutesLabel(int seconds) => LocaleKeys.Common_ApproxMinutes.tr(
        args: ['${(seconds / 60).round()}'],
      );

  String _assistanceLabel(String value) {
    return switch (value) {
      'low' => LocaleKeys.Patient_Home_AssistanceLow.tr(),
      'medium' => LocaleKeys.Patient_Home_AssistanceMedium.tr(),
      'high' => LocaleKeys.Patient_Home_AssistanceHigh.tr(),
      _ => value,
    };
  }
}

class _HomeAsset extends StatelessWidget {
  final String assetPath;
  final double size;

  const _HomeAsset({required this.assetPath, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child:
          Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.Patient_Home_NoExerciseTitle.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(LocaleKeys.Patient_Home_NoExerciseSubtitle.tr()),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.router.push(const TrainingRoute()),
              icon: Image.asset(
                'assets/images/gen_assets/asset_exercises.png',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
              label: Text(LocaleKeys.Common_ViewExercises.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final String? assetPath;
  final IconData icon;
  final String value;
  final String label;
  final Color background;
  final Color foreground;

  const _TodayMetric({
    this.assetPath,
    required this.icon,
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          assetPath == null
              ? Icon(icon, color: foreground)
              : Image.asset(assetPath!,
                  width: 30, height: 30, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: foreground)),
        ],
      ),
    );
  }
}

class _AlertPreview extends StatelessWidget {
  final HomeAlert alert;

  const _AlertPreview({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE08A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/gen_assets/asset_notifications.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(alert.title)),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PatientNotificationsPage(),
              ),
            ),
            child: Text(LocaleKeys.Common_View.tr()),
          ),
        ],
      ),
    );
  }
}

class _NoAlertPreview extends StatelessWidget {
  const _NoAlertPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/gen_assets/asset_progress.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(LocaleKeys.Patient_Home_NoAlerts.tr())),
        ],
      ),
    );
  }
}

enum LogoutStatus { initial, submitting, success }

class LogoutCubit extends Cubit<LogoutStatus> {
  final AuthRepository _authRepository;

  LogoutCubit(this._authRepository) : super(LogoutStatus.initial);

  Future<void> logout() async {
    if (state == LogoutStatus.submitting) return;
    emit(LogoutStatus.submitting);
    try {
      await _authRepository.logout();
    } finally {
      emit(LogoutStatus.success);
    }
  }
}
