import 'package:flutter/material.dart';

/// Aswaq Altaibat brand palette.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF00A859);
  static const Color primaryDark = Color(0xFF008844);
  static const Color primaryLight = Color(0xFFE6F7EE);

  static const Color accent = Color(0xFFFFA000);
  static const Color discount = Color(0xFFE53935);

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1B1F23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
