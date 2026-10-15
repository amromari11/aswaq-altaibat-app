import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Arabic-first typography. Cairo is the primary face; swap the
/// `GoogleFonts.cairo` calls below for `GoogleFonts.tajawal` app-wide if the
/// brand prefers Tajawal's geometric look instead.
class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get h1 => GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h2 => GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h3 => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get price => GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDark,
      );

  static TextStyle get priceStrikethrough => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        decoration: TextDecoration.lineThrough,
      );

  static TextStyle get button => GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );
}
