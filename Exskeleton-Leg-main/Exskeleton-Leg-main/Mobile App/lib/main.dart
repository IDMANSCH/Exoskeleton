import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/bloc_observer.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/app.dart';
import 'package:flutter_starter/presenter/languages/languages.dart';
import 'package:flutter_starter/services/firebase/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Some development devices retain an unrelated EZVIZ isolate/plugin. Do
  // not let its missing optional native channel terminate this app.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is MissingPluginException &&
        stack.toString().contains('ezviz/flutter')) {
      return true;
    }
    return false;
  };

  await EasyLocalization.ensureInitialized();
  await FcmService.initialize();

  await configureDependencies();

  Bloc.observer = AppBlocObserver(provider.get<AuthBloc>());

  runApp(
    const AppLanguages(
      child: GlobalBlocProviders(
        child: App(),
      ),
    ),
  );
}
