import 'package:go_router/go_router.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/food/barcode_scan_screen.dart';
import '../../features/food/food_product_screen.dart';
import '../../features/food/food_search_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/today_screen.dart';
import '../../features/log/quick_add_screen.dart';
import '../../features/meals/domain/meal_entry.dart';
import '../../features/meals/meal_detail_screen.dart';
import '../../features/meals/meals_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/plan/creating_plan_screen.dart';
import '../../features/plan/plan_reveal_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/scan/domain/picked_photo.dart';
import '../../features/scan/meal_result_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/settings/delete_account_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import 'app_routes.dart';

/// The app's route table.
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
      path: AppRoutes.signIn,
      builder: (_, _) => const SignInScreen(),
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.analytics,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.meals,
              builder: (_, _) => const MealsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, _) => const SettingsScreen(),
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
    GoRoute(
      path: AppRoutes.scan,
      builder: (_, _) => const ScanScreen(),
    ),
    GoRoute(
      path: AppRoutes.mealResult,
      // The photo travels as `extra`; without one (a restored or typed URL)
      // there is nothing to review, so start from the camera.
      redirect: (_, state) =>
          state.extra is PickedPhoto ? null : AppRoutes.scan,
      builder: (_, state) =>
          MealResultScreen(photo: state.extra! as PickedPhoto),
    ),
    GoRoute(
      path: AppRoutes.mealDetailPattern,
      builder: (_, state) =>
          MealDetailScreen(mealId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.deleteAccount,
      builder: (_, _) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: AppRoutes.foodSearch,
      builder: (_, state) => FoodSearchScreen(
        mealType: _mealTypeFrom(state.uri.queryParameters['meal']),
      ),
    ),
    GoRoute(
      path: AppRoutes.barcodeScan,
      builder: (_, state) => BarcodeScanScreen(
        mealType: _mealTypeFrom(state.uri.queryParameters['meal']),
      ),
    ),
    GoRoute(
      path: AppRoutes.foodProduct,
      // Without a product (a restored or typed URL) there is nothing to show.
      redirect: (_, state) =>
          state.extra is FoodProductArgs ? null : AppRoutes.foodSearch,
      builder: (_, state) =>
          FoodProductScreen(args: state.extra! as FoodProductArgs),
    ),
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

