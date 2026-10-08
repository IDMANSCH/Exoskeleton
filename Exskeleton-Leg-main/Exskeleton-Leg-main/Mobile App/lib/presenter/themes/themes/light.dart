import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/themes/colors.dart';
import 'package:flutter_starter/presenter/themes/themes.dart';

class LightAppTheme extends AppTheme {
  const LightAppTheme()
      : super(
          name: 'light',
          brightness: Brightness.light,
          colors: const AppThemeColors(
            primarySwatch: Colors.indigo,
            primary: Color(0xFF4557D6),
            secondary: Color(0xFF0087A7),
            accent: Color(0xFFFF8A3D),
            background: Color(0xFFFFFFFF),
            backgroundDark: Color(0xFFF5F6FA),
            disabled: Color(0x64303943),
            information: Color(0xFF4557D6),
            success: Color(0xFF0087A7),
            alert: Color(0xFF8A5200),
            warning: Color(0xFF8A5200),
            error: Color(0xFFBA1A1A),
            text: Color(0xFF1B1B23),
            textOnPrimary: Color(0xFFFFFFFF),
            border: Color(0xFF747481),
            hint: Color(0xFF474752),
          ),
        );
}
