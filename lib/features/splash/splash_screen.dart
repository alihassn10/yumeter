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

    // A stored profile means onboarding is already done.
    // TODO(auth): also require a signed-in session once auth exists.
    final returning = ref.read(storedProfileProvider) != null;
    context.go(returning ? AppRoutes.today : AppRoutes.welcome);
  }

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
