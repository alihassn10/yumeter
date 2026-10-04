import 'package:flutter/material.dart';

/// Colour tokens for the Yumeter design system.
///
/// Values come from `design/.../kinetic_glow_nutrition/DESIGN.md`. The app ships
/// dark-first, matching the Stitch screens; the `light*` variants are the
/// documented counterparts, kept here so a light theme can be added later
/// without re-deriving the palette.
abstract final class AppColors {
  // Canvas and surfaces.
  static const canvas = Color(0xFF0A0A0B);
  static const surface = Color(0xFF18181B);
  static const surfaceNested = Color(0xFF1E1E22);
  static const track = Color(0xFF27272A);
  static const outline = Color(0xFF3F3F46);

  // Text and iconography.
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textHint = Color(0xFF71717A);

  // Nutrient accents.
  static const calories = Color(0xFFFF8A3D);
  static const protein = Color(0xFFFF6B70);
  static const carbs = Color(0xFFFFB84D);
  static const fat = Color(0xFF6BA3FF);

  // System feedback.
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFF87171);

  // Light-mode counterparts, unused until a light theme exists.
  static const lightCanvas = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF4F4F5);
  static const lightTrack = Color(0xFFE4E4E7);
  static const lightTextPrimary = Color(0xFF0A0A0B);
  static const lightTextSecondary = Color(0xFF6B6B73);
  static const lightTextHint = Color(0xFFA1A1AA);
  static const lightCalories = Color(0xFFFF7A1A);
  static const lightProtein = Color(0xFFF2555A);
  static const lightCarbs = Color(0xFFF5A623);
  static const lightFat = Color(0xFF4A8DF8);
  static const lightSuccess = Color(0xFF22C55E);
  static const lightError = Color(0xFFEF4444);

  /// Tinted pill fill for a macro badge — the accent at 12% over the canvas.
  static Color tint(Color accent) => accent.withValues(alpha: 0.12);

  /// Ambient glow cast by primary CTAs and streak badges.
  static List<BoxShadow> glow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}
