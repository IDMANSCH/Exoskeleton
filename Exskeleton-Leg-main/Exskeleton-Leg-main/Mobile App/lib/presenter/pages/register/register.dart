import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/presenter/pages/auth_widgets.dart';
import 'package:flutter_starter/presenter/pages/register/register_cubit.dart';

@RoutePage()
class RegisterPage extends StatefulWidget implements AutoRouteWrapper {
  const RegisterPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider(
        create: (_) => RegisterCubit(provider.get<AuthRepository>()),
        child: this,
      );

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  String _role = 'patient';

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.Auth_Register_TermsRequired.tr()),
        ),
      );
      return;
    }
    context.read<RegisterCubit>().register(
          displayName: _displayNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          acceptedTerms: _acceptedTerms,
          role: _role,
        );
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterCubit, RegisterState>(
      listener: (context, state) async {
        if (state.status == RegisterStatus.success && state.account != null) {
          final authBloc = context.read<AuthBloc>();
          final authenticated = authBloc.stream.firstWhere(
            (authState) => authState.loggedIn,
          );
          authBloc.add(AuthLoggedIn(state.account!));
          await authenticated;
          if (!context.mounted) return;
          final caregiver = state.account!.roles.contains('caregiver');
          context.router.replaceAll([
            caregiver ? const CaregiverShellRoute() : const PatientShellRoute()
          ]);
        } else if (state.status == RegisterStatus.failure) {
          final message = state.error?.message;
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr(message))));
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: Text(LocaleKeys.Auth_Register_AppBarTitle.tr())),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthHeader(
                            icon: Icons.health_and_safety_outlined,
                            assetPath:
                                'assets/images/gen_assets/asset_training_plan.png',
                            title: LocaleKeys.Auth_Register_Title.tr(),
                            subtitle: LocaleKeys.Auth_Register_Subtitle.tr(),
                          ),
                          const SizedBox(height: 30),
                          AuthTextFormField(
                            label: LocaleKeys.Auth_Register_FullName.tr(),
                            hintText:
                                LocaleKeys.Auth_Register_FullNameHint.tr(),
                            prefixIcon: Icons.person_outline,
                            controller: _displayNameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) => (value?.trim().length ?? 0) <
                                    2
                                ? LocaleKeys.Auth_Register_FullNameRequired.tr()
                                : null,
                          ),
                          const SizedBox(height: 18),
                          _RoleChoiceCard(
                            role: _role,
                            onChanged: (value) => setState(() => _role = value),
                          ),
                          const SizedBox(height: 18),
                          AuthTextFormField(
                            label: LocaleKeys.Common_Email.tr(),
                            hintText: 'user@example.com',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return email.contains('@') &&
                                      email.split('@').last.contains('.')
                                  ? null
                                  : LocaleKeys.Auth_Login_InvalidEmail.tr();
                            },
                          ),
                          const SizedBox(height: 18),
                          AuthTextFormField(
                            label: LocaleKeys.Common_Password.tr(),
                            hintText:
                                LocaleKeys.Auth_Register_PasswordHint.tr(),
                            prefixIcon: Icons.lock_outline,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            helperText:
                                LocaleKeys.Auth_Register_PasswordHelper.tr(),
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
                            validator: (value) {
                              final length = value?.characters.length ?? 0;
                              return length < 8 || length > 128
                                  ? LocaleKeys.Auth_Register_PasswordLength.tr()
                                  : null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _acceptedTerms,
                              onChanged: (value) => setState(() {
                                _acceptedTerms = value ?? false;
                              }),
                              title: Text(LocaleKeys.Auth_Register_Terms.tr()),
                            ),
                          ),
                          const SizedBox(height: 16),
                          BlocBuilder<RegisterCubit, RegisterState>(
                            builder: (context, state) {
                              final submitting =
                                  state.status == RegisterStatus.submitting;
                              return FilledButton(
                                onPressed: submitting ? null : _submit,
                                child: submitting
                                    ? const SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        LocaleKeys.Auth_Register_Submit.tr()),
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
                            onPressed: () => context.router.maybePop(),
                            child:
                                Text(LocaleKeys.Auth_Register_LoginLink.tr()),
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
    );
  }
}

class _RoleChoiceCard extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;

  const _RoleChoiceCard({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bạn sử dụng Exoskeleton Leg với vai trò',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _RoleOption(
              selected: role == 'patient',
              icon: Icons.directions_walk_rounded,
              title: 'Người tập',
              subtitle: 'Tập và theo dõi cơ thể',
              onTap: () => onChanged('patient'),
              scheme: scheme,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _RoleOption(
              selected: role == 'caregiver',
              icon: Icons.shield_outlined,
              title: 'Giám sát',
              subtitle: 'Theo dõi người tập',
              onTap: () => onChanged('caregiver'),
              scheme: scheme,
            )),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 142,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
