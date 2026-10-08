import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_state.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/data/states/settings/settings_bloc.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/flavors.dart';
import 'package:flutter_starter/presenter/navigation/navigation_logger.dart';
import 'package:flutter_starter/services/firebase/fcm_service.dart';
import 'package:flutter_starter/services/ble/exo_ble_service.dart';
import 'package:flutter_starter/services/ble/exo_ble_protocol.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_placeholders.dart';

class App extends StatefulWidget {
  static final _appRouter = provider.get<AppRouter>();
  static StreamSubscription<String>? _fcmSubscription;

  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _messageSubscription;
  StreamSubscription<FallAlert>? _fallSubscription;
  StreamSubscription<ExerciseDeviceStatus>? _exerciseSubscription;
  final _reportedFallAlerts = <String>{};
  bool _switchingExercise = false;
  String? _lastSelectedCode;
  DateTime? _lastSelectedAt;

  @override
  void initState() {
    super.initState();
    _messageSubscription = FcmService.messageStream.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title']?.toString();
      final body = notification?.body ?? message.data['body']?.toString();
      if (title == null && body == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text([title, body].whereType<String>().join('\n')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
    _fallSubscription = ExoBleService.shared.fallAlerts.listen(_relayFallAlert);
    _exerciseSubscription =
        ExoBleService.shared.status.listen(_handleExerciseStatus);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _fallSubscription?.cancel();
    _exerciseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleExerciseStatus(ExerciseDeviceStatus status) async {
    final code = status.exerciseCode;
    if (!mounted ||
        status.state != 'selected' ||
        code == null ||
        code.isEmpty ||
        _switchingExercise) {
      return;
    }
    final now = DateTime.now();
    if (_lastSelectedCode == code &&
        _lastSelectedAt != null &&
        now.difference(_lastSelectedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSelectedCode = code;
    _lastSelectedAt = now;
    final account = context.read<AuthBloc>().state.account;
    if (account == null || !account.roles.contains('patient')) return;

    _switchingExercise = true;
    try {
      // ESP32 reports the selected code before starting its HOME cycle. Do
      // not navigate until the terminal STOP/HOME acknowledgement arrives.
      await ExoBleService.shared.stopForDeviceSelection(exerciseCode: code);

      final items = await provider.get<NetworkDataSource>().getPlanItems(
            account.id,
            scope: 'today',
          );
      Map<String, dynamic>? item;
      for (final candidate in items) {
        final exercise = candidate['exercise'];
        if (exercise is Map && exercise['code'] == code) {
          item = candidate;
          break;
        }
      }
      item ??= {
        'id': 'device-selection-$code',
        'session_id': 'local-ui',
        'exercise': {'code': code},
        'target': {'sets': 1, 'repetitions_per_set': 1},
      };

      final navigator = App._appRouter.navigatorKey.currentState;
      if (navigator != null && mounted) {
        await navigator.push<void>(MaterialPageRoute<void>(
          builder: (_) => ExercisePreparationPage(planItem: item!),
        ));
      }
    } catch (error, stackTrace) {
      debugPrint('Exercise selection navigation failed: $error\n$stackTrace');
    } finally {
      _switchingExercise = false;
    }
  }

  Future<void> _relayFallAlert(FallAlert alert) async {
    final account = context.read<AuthBloc>().state.account;
    if (account == null || !account.roles.contains('patient')) return;
    final key = alert.alertId.isEmpty
        ? '${alert.deviceId}:${alert.timestampMs}:${alert.fallProbability}'
        : alert.alertId;
    if (!_reportedFallAlerts.add(key)) return;
    if (mounted) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Phát hiện nguy cơ té ngã. Đang gửi cảnh báo đến người giám sát...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    try {
      await provider.get<NetworkDataSource>().reportFall(
            patientId: account.id,
            alertId: alert.alertId,
            deviceId: alert.deviceId,
            probability: alert.fallProbability,
            message:
                'Phát hiện té ngã (độ tin cậy ${(alert.fallProbability * 100).round()}%). Thiết bị: ${alert.deviceId}.',
          );
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Đã lưu cảnh báo ngã và gửi yêu cầu thông báo cho người giám sát.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Fall alert relay failed: $error\n$stackTrace');
      _reportedFallAlerts.remove(key);
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Chưa gửi được cảnh báo ngã. Kiểm tra mạng và kết nối lại thiết bị.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<SettingsBloc>().state.theme;

    return MultiBlocListener(
      listeners: [
        // Automatically navigate back to the login page when the user logged out
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previousState, state) =>
              previousState.loggedIn != state.loggedIn &&
              state.loggedIn == false,
          listener: (context, state) =>
              App._appRouter.replaceAll([const LoginRoute()]),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previousState, state) =>
              previousState.loggedIn != state.loggedIn &&
              state.loggedIn == true,
          listener: (context, state) {
            final token = FcmService.token;
            if (token != null) {
              unawaited(
                provider
                    .get<NetworkDataSource>()
                    .registerFcmToken(token)
                    .catchError((error) {
                  if (kDebugMode) {
                    debugPrint('FCM token registration failed: $error');
                  }
                }),
              );
            }
            App._fcmSubscription?.cancel();
            App._fcmSubscription =
                FcmService.tokenStream.listen((refreshedToken) {
              unawaited(provider
                  .get<NetworkDataSource>()
                  .registerFcmToken(refreshedToken)
                  .catchError((error) {
                if (kDebugMode) {
                  debugPrint('FCM refreshed token registration failed: $error');
                }
              }));
            });
          },
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        title: F.title,
        theme: appTheme.themeData,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: [
          ...context.localizationDelegates,
          // more delegates here
        ],
        routerConfig: App._appRouter.config(
          navigatorObservers: () => [
            if (kDebugMode) NavigationLogger(),
          ],
        ),
      ),
    );
  }
}
