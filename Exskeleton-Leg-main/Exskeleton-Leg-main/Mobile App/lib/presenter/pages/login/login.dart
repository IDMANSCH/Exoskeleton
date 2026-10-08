import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/presenter/pages/auth_widgets.dart';
import 'package:flutter_starter/presenter/pages/login/login_bloc.dart';
import 'package:flutter_starter/presenter/pages/login/login_event.dart';
import 'package:flutter_starter/presenter/pages/login/login_selector.dart';
import 'package:flutter_starter/presenter/pages/login/login_state.dart';
import 'package:flutter_starter/presenter/widgets/loading_indicator.dart';

@RoutePage()
class LoginPage extends StatefulWidget implements AutoRouteWrapper {
  const LoginPage();

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (ctx) => provider.get<LoginBloc>(),
      child: this,
    );
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  LoginBloc get _bloc => context.read<LoginBloc>();

  void _onUsernameChanged(String username) {
    _bloc.add(LoginUsernameChanged(username));
  }

  void _onPasswordChanged(String password) {
    _bloc.add(LoginPasswordChanged(password));
  }

  void _onLoginPressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _bloc.add(const LoginStarted());
  }

  void _onSocialPressed(String providerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocaleKeys.Common_ProviderComingSoon.tr(args: [providerName]),
        ),
      ),
    );
  }

  void _onSuccess(BuildContext context, LoginState state) {
    final caregiver = state.account?.roles.contains('caregiver') ?? false;
    context.router.replaceAll(
        [caregiver ? const CaregiverShellRoute() : const PatientShellRoute()]);
  }

  void _onError(BuildContext context, LoginState state) {
    final errorMessage = state.error?.message;

    if (errorMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(errorMessage)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        LoginSuccessListener(listener: _onSuccess),
        LoginFailureListener(listener: _onError),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/exoskeleton_leg_logo.png',
                                height: 132,
                                fit: BoxFit.contain,
                                semanticLabel: 'Exoskeleton Leg',
                              ),
                            ),
                            const SizedBox(height: 16),
                            AuthHeader(
                              icon: Icons.accessibility_new_rounded,
                              assetPath:
                                  'assets/images/gen_assets/asset_patient_profile_card.png',
                              title: LocaleKeys.Auth_Login_Title.tr(),
                              subtitle: LocaleKeys.Auth_Login_Subtitle.tr(),
                            ),
                            const SizedBox(height: 30),
                            AuthTextFormField(
                              label: LocaleKeys.Common_Email.tr(),
                              hintText: 'user@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              onChanged: _onUsernameChanged,
                            ),
                            const SizedBox(height: 18),
                            AuthTextFormField(
                              label: LocaleKeys.Common_Password.tr(),
                              hintText: LocaleKeys.Auth_Login_PasswordHint.tr(),
                              prefixIcon: Icons.lock_outline,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? LocaleKeys.Auth_Login_ShowPassword.tr()
                                    : LocaleKeys.Auth_Login_HidePassword.tr(),
                                onPressed: () => setState(() {
                                  _obscurePassword = !_obscurePassword;
                                }),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) => (value?.isEmpty ?? true)
                                  ? LocaleKeys.Auth_Login_PasswordRequired.tr()
                                  : null,
                              onFieldSubmitted: (_) => _onLoginPressed(),
                              onChanged: _onPasswordChanged,
                            ),
                            const SizedBox(height: 26),
                            LoginStatusSelector(
                              builder: (status) {
                                final submitting =
                                    status == LoginStatus.submitting;
                                return FilledButton(
                                  onPressed:
                                      submitting ? null : _onLoginPressed,
                                  child: submitting
                                      ? const AppFilledButtonLoadingIndicator()
                                      : Text(tr(LocaleKeys.Login)),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            SocialAuthButtons(
                              onGooglePressed: () => _onSocialPressed('Google'),
                              onFacebookPressed: () =>
                                  _onSocialPressed('Facebook'),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () =>
                                  context.router.pushNamed('/auth/register'),
                              child: Text(
                                LocaleKeys.Auth_Login_CreateAccountLink.tr(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty ||
        !email.contains('@') ||
        !email.split('@').last.contains('.')) {
      return LocaleKeys.Auth_Login_InvalidEmail.tr();
    }
    return null;
  }
}
