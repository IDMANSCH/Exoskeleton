import 'package:auto_route/auto_route.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/presenter/pages/home/home.dart';
import 'package:flutter_starter/presenter/pages/login/login.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_placeholders.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_shell.dart';
import 'package:flutter_starter/presenter/pages/caregiver/caregiver_shell.dart';
import 'package:flutter_starter/presenter/pages/register/register.dart';
import 'package:flutter_starter/presenter/pages/splash/splash.dart';
import 'package:injectable/injectable.dart';

part 'navigation.gr.dart';

@singleton
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  final AuthBloc _authBloc;

  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(path: '/', page: SplashRoute.page),
        AutoRoute(path: '/auth/login', page: LoginRoute.page),
        AutoRoute(path: '/auth/register', page: RegisterRoute.page),
        AutoRoute(path: '/caregiver', page: CaregiverShellRoute.page),
        AutoRoute(
          path: '/patient',
          page: PatientShellRoute.page,
          children: [
            AutoRoute(path: 'home', page: HomeRoute.page),
            AutoRoute(path: 'training', page: TrainingRoute.page),
            AutoRoute(path: 'progress', page: ProgressRoute.page),
            AutoRoute(path: 'device', page: DeviceRoute.page),
            AutoRoute(path: 'profile', page: ProfileRoute.page),
            RedirectRoute(path: '', redirectTo: 'home'),
          ],
        ),
      ];

  bool isUnauthorizedRoute(String routeName) =>
      [LoginRoute.name, RegisterRoute.name].contains(routeName);

  bool isAuthorizedRoute(String routeName) => [
        PatientShellRoute.name,
        CaregiverShellRoute.name,
        HomeRoute.name,
        TrainingRoute.name,
        ProgressRoute.name,
        DeviceRoute.name,
        ProfileRoute.name,
      ].contains(routeName);

  @override
  List<AutoRouteGuard> get guards => [
        AutoRouteGuard.simple((resolver, router) {
          final isAuthenticated = _authBloc.state.loggedIn;

          if (isAuthorizedRoute(resolver.routeName) && !isAuthenticated) {
            return resolver.redirect(LoginRoute(), replace: true);
          }

          if (isUnauthorizedRoute(resolver.routeName) && isAuthenticated) {
            final isCaregiver =
                _authBloc.state.account?.roles.contains('caregiver') ?? false;
            return resolver.redirect(
              isCaregiver
                  ? const CaregiverShellRoute()
                  : const PatientShellRoute(),
              replace: true,
            );
          }

          final isPatientRoute = [
            PatientShellRoute.name,
            HomeRoute.name,
            TrainingRoute.name,
            ProgressRoute.name,
            DeviceRoute.name,
            ProfileRoute.name,
          ].contains(resolver.routeName);
          final isCaregiver =
              _authBloc.state.account?.roles.contains('caregiver') ?? false;
          if (isPatientRoute && isCaregiver) {
            return resolver.redirect(const CaregiverShellRoute(),
                replace: true);
          }

          resolver.next(true);
        }),
      ];

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();
}
