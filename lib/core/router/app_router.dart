import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_shell.dart';
import '../../features/home/today_screen.dart';
import '../../features/log/quick_add_screen.dart';
import '../../features/meals/domain/meal_entry.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/plan/creating_plan_screen.dart';
import '../../features/plan/plan_reveal_screen.dart';
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
    GoRoute(
      path: AppRoutes.creatingPlan,
      builder: (_, _) => const CreatingPlanScreen(),
    ),
    GoRoute(
      path: AppRoutes.planReveal,
      builder: (_, _) => const PlanRevealScreen(),
    ),
    GoRoute(
      path: AppRoutes.paywall,
      builder: (_, _) => const PaywallScreen(),
    ),

    // The four tabs, each with its own back stack.
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.today,
              builder: (_, _) => const TodayScreen(),
            ),
          ],
        ),
        for (final (path, title) in const [
          (AppRoutes.analytics, 'Progress'),
          (AppRoutes.meals, 'Meals'),
          (AppRoutes.settings, 'Settings'),
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (_, _) => _Placeholder(title: title),
              ),
            ],
          ),
      ],
    ),

    // Logging flows open full screen, above the tab bar.
    GoRoute(
      path: AppRoutes.quickAdd,
      builder: (_, state) => QuickAddScreen(
        initialType: _mealTypeFrom(state.uri.queryParameters['meal']),
      ),
    ),
    for (final (path, title) in const [
      (AppRoutes.scan, 'Scan'),
      (AppRoutes.mealResult, 'Meal result'),
      (AppRoutes.foodSearch, 'Food search'),
      (AppRoutes.barcodeResult, 'Barcode result'),
      (AppRoutes.deleteAccount, 'Delete account'),
    ])
      GoRoute(path: path, builder: (_, _) => _Placeholder(title: title)),
  ],
);

/// Reads the `?meal=` parameter the log sheet passes along. An unknown value
/// falls back to the screen's own time-of-day guess.
MealType? _mealTypeFrom(String? name) {
  for (final type in MealType.values) {
    if (type.name == name) return type;
  }
  return null;
}

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
