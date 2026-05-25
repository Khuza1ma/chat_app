import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF377DFE);
  static const Color primaryVariant = Color(0xFF3700B3);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFB00020);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onBackground = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyMedium = Color(0xFFE0E0E0);
  static const Color greyDark = Color(0xFF757575);

  static Color getColorFromString(String str) {
    final colors = [
      const Color(0xFF377DFE),
      const Color(0xFF03DAC6),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA500),
      const Color(0xFF9C27B0),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
    ];
    return colors[str.hashCode.abs() % colors.length];
  }
}
