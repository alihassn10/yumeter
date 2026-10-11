import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Assembles the design tokens into the `ThemeData` the app runs on, once for
/// each mode. The palette rides along as a theme extension, which is where
/// `context.colors` and `context.text` read from.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette c, Brightness brightness) {
    final t = AppTypography(c);
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      surface: c.canvas,
      onSurface: c.textPrimary,
      surfaceContainer: c.surface,
      surfaceContainerHighest: c.track,
      primary: c.calories,
      onPrimary: c.onAccent,
      // Material components fall back to `secondary` for tonal buttons and
      // selections. It was the protein pink, which leaked into unrelated
      // controls; the brand orange keeps them on palette.
      secondary: c.calories,
      onSecondary: c.onAccent,
      // The orange at 15% over the card surface, made opaque so it reads the
      // same on any background.
      secondaryContainer:
          isDark ? const Color(0xFF3B2920) : const Color(0xFFFFEBDD),
      onSecondaryContainer: isDark ? c.calories : const Color(0xFF8A3A00),
      error: c.error,
      onError: c.onAccent,
      outline: c.outline,
      outlineVariant: c.track,
    );

    // Status bar icons contrast with the canvas behind them.
    final overlay =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      textTheme: t.textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],

      // Every route animates the platform's way: Material 3's fade-forward
      // on Android, the native slide (with swipe-back) on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: t.headlineSmall,
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle: overlay,
      ),

      // Primary CTA: full-width stadium pill with an ambient accent glow that
      // the caller adds via AppColors.glow() when it should light up.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.calories,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.track,
          disabledForegroundColor: c.textHint,
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillShape),
          textStyle: t.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.track,
          foregroundColor: c.textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          side: BorderSide(color: c.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillShape),
          textStyle: t.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textSecondary,
          textStyle: t.labelMedium,
        ),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardShape),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: t.bodyMedium.copyWith(color: c.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.md,
        ),
        prefixIconColor: c.textSecondary,
        border: _inputBorder(c.track),
        enabledBorder: _inputBorder(c.track),
        focusedBorder: _inputBorder(c.calories),
        errorBorder: _inputBorder(c.error),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetShape),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),

      // Floats above the tab bar in the palette; the default is a slab that
      // glares against the canvas.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.track : c.textPrimary,
        contentTextStyle:
            t.bodyMedium.copyWith(color: isDark ? c.textPrimary : c.canvas),
        actionTextColor: c.calories,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),

      dividerTheme: DividerThemeData(color: c.track, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.calories,
        linearTrackColor: c.track,
        circularTrackColor: c.track,
        strokeCap: StrokeCap.round,
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.calories : c.track,
        ),
        thumbColor: WidgetStatePropertyAll(isDark ? c.textPrimary : c.canvas),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.canvas,
        selectedItemColor: c.calories,
        unselectedItemColor: c.textHint,
        selectedLabelStyle: t.labelSmall,
        unselectedLabelStyle: t.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
        borderSide: BorderSide(color: color),
      );
}
