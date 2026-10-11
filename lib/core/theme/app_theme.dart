import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Assembles the design tokens into the `ThemeData` the app runs on.
abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      surface: AppColors.canvas,
      onSurface: AppColors.textPrimary,
      surfaceContainer: AppColors.surface,
      surfaceContainerHighest: AppColors.track,
      primary: AppColors.calories,
      onPrimary: AppColors.canvas,
      // Material components fall back to `secondary` for tonal buttons and
      // selections. It was the protein pink, which leaked into unrelated
      // controls; the brand orange keeps them on palette.
      secondary: AppColors.calories,
      onSecondary: AppColors.canvas,
      // The orange at 15% over the card surface, made opaque so it reads the
      // same on any background.
      secondaryContainer: Color(0xFF3B2920),
      onSecondaryContainer: AppColors.calories,
      error: AppColors.error,
      onError: AppColors.canvas,
      outline: AppColors.outline,
      outlineVariant: AppColors.track,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: AppTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,

      // Every route animates the platform's way: Material 3's fade-forward
      // on Android, the native slide (with swipe-back) on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headlineSmall,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Primary CTA: full-width stadium pill with an ambient accent glow that
      // the caller adds via AppColors.glow() when it should light up.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.calories,
          foregroundColor: AppColors.canvas,
          disabledBackgroundColor: AppColors.track,
          disabledForegroundColor: AppColors.textHint,
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillShape),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.track,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          side: const BorderSide(color: AppColors.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillShape),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: AppTypography.labelMedium,
        ),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardShape),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.md,
        ),
        prefixIconColor: AppColors.textSecondary,
        border: _inputBorder(AppColors.track),
        enabledBorder: _inputBorder(AppColors.track),
        focusedBorder: _inputBorder(AppColors.calories),
        errorBorder: _inputBorder(AppColors.error),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.outline,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetShape),
      ),

      // Floats above the tab bar in the dark palette; the default is a light
      // slab that glares against the canvas.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.track,
        contentTextStyle:
            AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        actionTextColor: AppColors.calories,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.track,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.calories,
        linearTrackColor: AppColors.track,
        circularTrackColor: AppColors.track,
        strokeCap: StrokeCap.round,
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.calories
              : AppColors.track,
        ),
        thumbColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        selectedItemColor: AppColors.calories,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
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
