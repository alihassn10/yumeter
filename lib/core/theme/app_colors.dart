import 'package:flutter/material.dart';

/// Colour tokens for the Yumeter design system.
///
/// Values come from `design/.../kinetic_glow_nutrition/DESIGN.md`. Screens read
/// colours through `context.colors`, which resolves to the dark or light
/// [AppPalette] the app is currently showing. The constants on [AppColors] are
/// the dark values: the brand mark keeps them in both modes, since it always
/// sits on its own dark tile.
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

/// One full set of colour tokens, attached to the theme so every widget
/// reads the colours of the mode the app is in.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceNested,
    required this.track,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.success,
    required this.error,
    required this.onAccent,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceNested;
  final Color track;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color calories;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color success;
  final Color error;

  /// Text and icons on an accent fill, such as the orange primary button.
  /// Near-black in both modes: white on the orange is too faint to read.
  final Color onAccent;

  static const dark = AppPalette(
    canvas: AppColors.canvas,
    surface: AppColors.surface,
    surfaceNested: AppColors.surfaceNested,
    track: AppColors.track,
    outline: AppColors.outline,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
    calories: AppColors.calories,
    protein: AppColors.protein,
    carbs: AppColors.carbs,
    fat: AppColors.fat,
    success: AppColors.success,
    error: AppColors.error,
    onAccent: AppColors.canvas,
  );

  /// The documented light counterparts: white canvas, light grey cards, and
  /// accents a step deeper so they hold up against white.
  static const light = AppPalette(
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F5),
    surfaceNested: Color(0xFFEBEBED),
    track: Color(0xFFE4E4E7),
    outline: Color(0xFFD4D4D8),
    textPrimary: Color(0xFF0A0A0B),
    textSecondary: Color(0xFF6B6B73),
    // A touch darker than the documented #A1A1AA, which is too faint to read
    // as hint text on white.
    textHint: Color(0xFF8A8A93),
    calories: Color(0xFFFF7A1A),
    protein: Color(0xFFF2555A),
    carbs: Color(0xFFF5A623),
    fat: Color(0xFF4A8DF8),
    success: Color(0xFF22C55E),
    error: Color(0xFFEF4444),
    onAccent: Color(0xFF0A0A0B),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceNested: mix(surfaceNested, other.surfaceNested),
      track: mix(track, other.track),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textHint: mix(textHint, other.textHint),
      calories: mix(calories, other.calories),
      protein: mix(protein, other.protein),
      carbs: mix(carbs, other.carbs),
      fat: mix(fat, other.fat),
      success: mix(success, other.success),
      error: mix(error, other.error),
      onAccent: mix(onAccent, other.onAccent),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The colours of the mode the app is showing. Reading them here also makes
  /// the widget rebuild when the mode changes.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
