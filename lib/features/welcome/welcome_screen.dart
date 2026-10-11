import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_badge.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/macro_stat.dart';
import '../auth/data/account_sync.dart';
import '../auth/data/auth_repository.dart';

/// First screen a new user sees: the pitch, a sample of what the app produces,
/// and the three sign-in routes.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  /// Google sign-in is wired for Android only so far: iOS needs its own
  /// OAuth client, and Apple requires Sign in with Apple alongside it.
  static bool get googleAvailable =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _googleBusy = false;

  Future<void> _signInWithGoogle() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      final hasProfile = await ref.read(accountSyncProvider).signedIn(user);
      if (!mounted) return;
      context.go(hasProfile ? AppRoutes.today : AppRoutes.onboarding);
    } on AuthCancelled {
      // Closing the picker is a choice, not an error.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

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
                style: context.text.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Snap a photo, get instant macros, and stay on track.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
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
                // The working provider gets the highlight.
                filled: !WelcomeScreen.googleAvailable,
                onPressed: () => _notYetAvailable(context, 'Apple'),
              ),
              const SizedBox(height: AppSpacing.md),
              _SignInButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                filled: WelcomeScreen.googleAvailable,
                busy: _googleBusy,
                onPressed: WelcomeScreen.googleAvailable
                    ? _signInWithGoogle
                    : () => _notYetAvailable(context, 'Google'),
              ),
              const SizedBox(height: AppSpacing.md),
              _SignInButton(
                icon: Icons.mail_outline_rounded,
                label: 'Continue with email',
                onPressed: () => context.push(AppRoutes.signIn),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Agreement(),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }

  // TODO(auth): Sign in with Apple, and Google on iOS. Apple's guideline 4.8
  // requires the Apple option wherever Google sign-in ships on iOS.
  void _notYetAvailable(BuildContext context, String provider) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '$provider sign-in is coming soon. Use email for now.',
            ),
          ),
        );
}

/// A still of the meal breakdown the app produces, shown as proof before
/// anyone signs up.
class _SamplePreview extends StatelessWidget {
  const _SamplePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
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
                  style: context.text.headlineSmall,
                ),
              ),
              Text('540 kcal', style: context.text.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
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
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Shows progress in place of the icon and ignores taps meanwhile.
  final bool busy;

  /// The primary provider gets the light fill; the rest stay neutral.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final leading = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);
    final onTap = busy ? null : onPressed;
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: leading,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.textPrimary,
          foregroundColor: context.colors.canvas,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: leading,
      label: Text(label),
    );
  }
}

/// The agreement line, with both documents one tap away before sign-up.
class _Agreement extends StatelessWidget {
  const _Agreement();

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall.copyWith(color: context.colors.textHint);
    Widget link(String label, String route) => Semantics(
          link: true,
          child: InkWell(
            onTap: () => context.push(route),
            child: Padding(
              // A taller hit area than the text itself.
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                label,
                style: style.copyWith(
                  color: context.colors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: style),
        link('Terms of use', AppRoutes.terms),
        Text(' and ', style: style),
        link('Privacy policy', AppRoutes.privacy),
        Text('.', style: style),
      ],
    );
  }
}
