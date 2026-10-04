import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale for the Yumeter design system.
///
/// Plus Jakarta Sans carries headlines, metrics and interactive labels; Inter
/// carries running text and food metadata. The `em` letter-spacing in
/// `DESIGN.md` is converted to logical pixels here (`em * fontSize`), and
/// `lineHeight` to Flutter's `height` multiplier (`lineHeight / fontSize`).
abstract final class AppTypography {
  /// Tabular figures keep animated counters from jittering as digits change.
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.20,
        letterSpacing: -1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.19,
        letterSpacing: -0.64,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.21,
        letterSpacing: -0.56,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.27,
        letterSpacing: -0.22,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.33,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.50,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.33,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.23,
        color: AppColors.textSecondary,
      );

  /// Micro-caps badge text — pair with `TextCapitalization` at the call site.
  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.27,
        letterSpacing: 0.22,
        color: AppColors.textSecondary,
      );

  /// Headline metric — the big calorie counter.
  static TextStyle get metricHeadline => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.13,
        letterSpacing: -0.96,
        fontFeatures: _tabular,
        color: AppColors.textPrimary,
      );

  /// Secondary metric — macro gram counts.
  static TextStyle get metricSub => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.22,
        fontFeatures: _tabular,
        color: AppColors.textPrimary,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
