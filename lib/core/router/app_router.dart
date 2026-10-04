import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';
import 'app_routes.dart';

/// The app's route table. Screens are added here as each one is built; the
/// remaining paths resolve to [_Placeholder] so navigation can be wired and
/// walked end to end before every screen exists.
final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, _) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (_, _) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    for (final (path, title) in const [
      (AppRoutes.creatingPlan, 'Creating your plan'),
      (AppRoutes.planReveal, 'Your plan'),
      (AppRoutes.paywall, 'Paywall'),
      (AppRoutes.today, 'Today'),
      (AppRoutes.analytics, 'Analytics'),
      (AppRoutes.meals, 'Meals'),
      (AppRoutes.settings, 'Settings'),
      (AppRoutes.scan, 'Scan'),
      (AppRoutes.mealResult, 'Meal result'),
      (AppRoutes.foodSearch, 'Food search'),
      (AppRoutes.barcodeResult, 'Barcode result'),
      (AppRoutes.quickAdd, 'Quick add'),
      (AppRoutes.deleteAccount, 'Delete account'),
    ])
      GoRoute(path: path, builder: (_, _) => _Placeholder(title: title)),
  ],
);

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Text(
            '$title is not built yet.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
        ),
      ),
    );
  }
}
