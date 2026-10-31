import 'package:flutter/material.dart';

/// Aswaq Altaibat brand palette: white, navy blue, red.
///
/// Was green (#00A859/#008844) in the original MVP spec — rebranded here.
/// Every screen reads these tokens rather than hardcoding colors, so this
/// file is the only place a future palette change needs to happen.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF13294B); // Navy — headers, nav, info text
  static const Color primaryDark = Color(0xFF0A1830); // Deeper navy — gradients, pressed states
  static const Color primaryLight = Color(0xFFE8EAF2); // Pale navy tint — selected chips/badges

  static const Color accent = Color(0xFFD7263D); // Red — buttons, CTAs, discount badges
  static const Color accentDark = Color(0xFFB01E30);
  static const Color discount = accent;

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  /// Soft page background the white cards sit on (quick-commerce look).
  static const Color canvas = Color(0xFFF4F6FB);

  static const Color textPrimary = Color(0xFF14192A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color tile = Color(0xFFF4F6FA); // Soft tile behind category pictures
  static const Color success = Color(0xFF16A34A); // Semantic (free-delivery reached) — not a brand color
  static const Color error = accent;

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
