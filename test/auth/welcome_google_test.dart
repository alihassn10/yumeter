import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/welcome/welcome_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRemote profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRemote();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 4000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: AppRoutes.welcome,
      routes: [
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, _) => const WelcomeScreen(),
        ),
        for (final path in [AppRoutes.today, AppRoutes.onboarding])
          GoRoute(path: path, builder: (_, _) => Text('landed on $path')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          await testPrefs(),
          auth: auth,
          profiles: profiles,
        ),
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapGoogle(WidgetTester tester) async {
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new Google account goes on to onboarding', (tester) async {
    await pump(tester);
    await tapGoogle(tester);
    expect(find.text('landed on ${AppRoutes.onboarding}'), findsOneWidget);
  });

  testWidgets('a returning Google account goes to the dashboard',
      (tester) async {
    profiles.rows[testUser.id] = sampleProfile;
    await pump(tester);
    await tapGoogle(tester);
    expect(find.text('landed on ${AppRoutes.today}'), findsOneWidget);
  });

  testWidgets('closing the Google picker is not treated as an error',
      (tester) async {
    auth.googleError = const AuthCancelled();
    await pump(tester);
    await tapGoogle(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed Google sign-in says so and stays put', (tester) async {
    auth.googleError = const AuthFailure(
      'Google sign-in is not available right now. Use email instead.',
    );
    await pump(tester);
    await tapGoogle(tester);

    expect(
      find.text('Google sign-in is not available right now. Use email instead.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('on iPhone Google sign-in is not offered yet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(tester);
      await tapGoogle(tester);
      expect(find.textContaining('coming soon'), findsOneWidget);
      expect(auth.user, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
