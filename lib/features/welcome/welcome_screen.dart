import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_badge.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/macro_stat.dart';

/// First screen a new user sees: the pitch, a sample of what the app produces,
/// and the three sign-in routes.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BrandMark(size: 64)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Reach your goals with\neffortless AI tracking',
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Snap a photo, get instant macros, and stay on track.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AccentBadge(
                    label: 'Photo logging',
                    icon: Icons.photo_camera_rounded,
                  ),
                  AccentBadge(label: 'Macro breakdown', icon: Icons.pie_chart_rounded),
                  AccentBadge(label: 'Personalized plan', icon: Icons.flag_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SamplePreview(),
              const SizedBox(height: AppSpacing.xl),
              _SignInButton(
                icon: Icons.apple,
                label: 'Continue with Apple',
                filled: true,
                onPressed: () => _startOnboarding(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _SignInButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: () => _startOnboarding(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _SignInButton(
                icon: Icons.mail_outline_rounded,
                label: 'Continue with email',
                onPressed: () => _startOnboarding(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'By continuing you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textHint),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }

  // TODO(auth): run the real provider sign-in before entering onboarding.
  void _startOnboarding(BuildContext context) =>
      context.go(AppRoutes.onboarding);
}

/// A still of the meal breakdown the app produces, shown as proof before
/// anyone signs up.
class _SamplePreview extends StatelessWidget {
  const _SamplePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Grilled salmon bowl',
                  style: AppTypography.headlineSmall,
                ),
              ),
              Text('540 kcal', style: AppTypography.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(child: MacroStat.protein(grams: 46, goalGrams: 60)),
              Expanded(child: MacroStat.carbs(grams: 38, goalGrams: 60)),
              Expanded(child: MacroStat.fat(grams: 22, goalGrams: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// The primary provider gets the light fill; the rest stay neutral.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.canvas,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
