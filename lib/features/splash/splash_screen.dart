import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/brand_mark.dart';
import '../auth/data/account_sync.dart';
import '../auth/data/auth_repository.dart';

/// Brand moment while the app boots. It holds for a beat so the mark can
/// animate in, then hands off to the first real screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    // The widget can be disposed if the user backgrounds the app mid-animation.
    if (!mounted) return;

    // Supabase restored any saved session before the first frame.
    if (ref.read(currentUserProvider) == null) {
      context.go(AppRoutes.welcome);
      return;
    }

    final sync = ref.read(accountSyncProvider);
    if (ref.read(storedProfileProvider) != null) {
      // Signed in with a profile on the phone: go straight in and refresh it
      // from the account in the background.
      unawaited(sync.restoreProfile());
      context.go(AppRoutes.today);
      return;
    }

    // Signed in but nothing on the phone, e.g. after a reinstall. Look on the
    // account before sending a returning user through onboarding again.
    final hasProfile = await sync
        .restoreProfile()
        .timeout(_restoreTimeout, onTimeout: () => false);
    if (!mounted) return;
    context.go(hasProfile ? AppRoutes.today : AppRoutes.onboarding);
  }

  static const _restoreTimeout = Duration(seconds: 8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 96)
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
            const SizedBox(height: AppSpacing.lg),
            Text.rich(
              TextSpan(
                text: 'Yumeter',
                style: AppTypography.displaySmall,
                children: [
                  TextSpan(
                    text: '.',
                    style: AppTypography.displaySmall
                        .copyWith(color: AppColors.calories),
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Snap a meal, know the calories',
              style: AppTypography.bodyMedium,
            ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
