import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';

class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? assetPath;

  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: assetPath == null
                ? Icon(icon,
                    size: 34,
                    color: colorScheme.onPrimaryContainer,
                    semanticLabel: title)
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(assetPath!, fit: BoxFit.contain),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class AuthTextFormField extends StatelessWidget {
  final String label;
  final String? hintText;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? helperText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthTextFormField({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.helperText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fieldFill = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.035),
      colorScheme.surface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            focusedBorder: _border(colorScheme.primary.withValues(alpha: 0.18)),
            errorBorder: _border(colorScheme.error.withValues(alpha: 0.26)),
            focusedErrorBorder:
                _border(colorScheme.error.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide:
          BorderSide(color: color, width: color == Colors.transparent ? 0 : 1),
    );
  }
}

class SocialAuthButtons extends StatelessWidget {
  final VoidCallback onGooglePressed;
  final VoidCallback onFacebookPressed;

  const SocialAuthButtons({
    super.key,
    required this.onGooglePressed,
    required this.onFacebookPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                LocaleKeys.Auth_SocialDivider.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SocialAuthButton(
                label: 'Google',
                mark: 'G',
                markColor: const Color(0xFF4285F4),
                onPressed: onGooglePressed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SocialAuthButton(
                label: 'Facebook',
                mark: 'f',
                markColor: const Color(0xFF1877F2),
                onPressed: onFacebookPressed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final String label;
  final String mark;
  final Color markColor;
  final VoidCallback onPressed;

  const SocialAuthButton({
    super.key,
    required this.label,
    required this.mark,
    required this.markColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: colorScheme.surface,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: markColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              mark,
              style: TextStyle(
                color: markColor,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
