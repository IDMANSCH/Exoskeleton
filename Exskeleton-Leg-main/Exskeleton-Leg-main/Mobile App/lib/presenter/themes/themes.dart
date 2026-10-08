import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/themes/colors.dart';
import 'package:flutter_starter/presenter/themes/styles.dart';
import 'package:flutter_starter/presenter/themes/typography.dart';

class AppTheme extends ThemeExtension<AppTheme> {
  final String name;
  final String fontFamily;
  final Brightness brightness;
  final AppThemeColors colors;
  final AppThemeTypography typographies;
  final AppThemeStyles styles;

  const AppTheme({
    required this.name,
    required this.brightness,
    required this.colors,
    this.styles = const AppThemeStyles(),
    this.typographies = const AppThemeTypography(),
    this.fontFamily = 'Roboto',
  });

  ColorScheme get baseColorScheme => brightness == Brightness.light //
      ? const ColorScheme.light()
      : const ColorScheme.dark();

  ThemeData get themeData => ThemeData(
        useMaterial3: true,
        extensions: [this],
        brightness: brightness,
        primaryColor: colors.primary,
        unselectedWidgetColor: colors.hint,
        disabledColor: colors.disabled,
        scaffoldBackgroundColor: colors.background,
        hintColor: colors.hint,
        dividerColor: colors.border,
        fontFamily: fontFamily,
        colorScheme: baseColorScheme.copyWith(
          primary: colors.primary,
          onPrimary: colors.textOnPrimary,
          primaryContainer: const Color(0xFFE1E4FF),
          onPrimaryContainer: const Color(0xFF111A64),
          secondary: colors.secondary,
          onSecondary: colors.textOnPrimary,
          secondaryContainer: const Color(0xFFC7F0FF),
          onSecondaryContainer: const Color(0xFF003543),
          tertiary: const Color(0xFFFF7A1A),
          onTertiary: const Color(0xFFFFFFFF),
          tertiaryContainer: const Color(0xFFFFDEC8),
          onTertiaryContainer: const Color(0xFF4D2300),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1B1B23),
          surfaceContainerLowest: const Color(0xFFFFFFFF),
          surfaceContainerLow: const Color(0xFFF6F7FB),
          surfaceContainer: const Color(0xFFEFF1F7),
          surfaceContainerHigh: const Color(0xFFE8EBF3),
          surfaceContainerHighest: const Color(0xFFE1E5EF),
          onSurfaceVariant: const Color(0xFF474752),
          outline: const Color(0xFF747481),
          outlineVariant: const Color(0xFFC7C5D0),
          error: colors.error,
          shadow: colors.border,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontSize: 18, height: 28 / 18),
          bodyMedium: TextStyle(fontSize: 16, height: 1.5),
          labelLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          titleTextStyle: typographies.body,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: colors.text,
          surfaceTintColor: Colors.transparent,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: colors.text,
          unselectedLabelColor: colors.text.withValues(alpha: 0.4),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: styles.buttonLarge.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: styles.buttonLarge.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: styles.buttonLarge.copyWith(
            side: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? BorderSide(color: colors.disabled)
                  : null;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: styles.buttonLarge.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.disabled
                  : null; // Defer to the widget's default.
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: true,
          fillColor: colors.backgroundDark,
          hintStyle: typographies.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.text.withValues(alpha: 0.4),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          // prefixIconColor: colors.text,
          // suffixIconColor: colors.text,
        ),
        checkboxTheme: CheckboxThemeData(
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: BorderSide(color: colors.border),
        ),
        radioTheme: const RadioThemeData(
          visualDensity: VisualDensity(horizontal: -4, vertical: -4),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.secondary,
          foregroundColor: colors.textOnPrimary,
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: colors.border,
          thickness: 1,
          space: 1,
        ),
      );

  @override
  AppTheme copyWith({
    String? name,
    Brightness? brightness,
    AppThemeColors? colors,
    AppThemeTypography? typographies,
    AppThemeStyles? styles,
  }) {
    return AppTheme(
      brightness: brightness ?? this.brightness,
      name: name ?? this.name,
      colors: colors ?? this.colors,
      typographies: typographies ?? this.typographies,
      styles: styles ?? this.styles,
    );
  }

  @override
  AppTheme lerp(covariant ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) {
      return this;
    }
    return AppTheme(
      name: name,
      brightness: brightness,
      colors: colors.lerp(other.colors, t),
      typographies: typographies.lerp(other.typographies, t),
      styles: styles,
    );
  }
}
