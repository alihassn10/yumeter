import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/auth/sign_in_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRemote profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRemote();
  });

  Future<void> pumpSignIn(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.signIn,
      routes: [
        GoRoute(
          path: AppRoutes.signIn,
          builder: (_, _) => const SignInScreen(),
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

  Future<void> requestCode(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'a@example.test');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
  }

  /// Disposes the screen so its resend countdown does not outlive the test.
  Future<void> tearDownScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('send code stays disabled until the email looks real',
      (tester) async {
    await pumpSignIn(tester);
    ElevatedButton button() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a@example.test');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('sending a code moves to the code step with a cooldown',
      (tester) async {
    await pumpSignIn(tester);
    await requestCode(tester);

    expect(auth.sentCodesTo, ['a@example.test']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('Resend code in 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Resend code'), findsOneWidget);
    await tearDownScreen(tester);
  });

  testWidgets('a wrong code shows an error and stays put', (tester) async {
    await pumpSignIn(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('That code did not work.'), findsOneWidget);
    expect(find.text('Check your email'), findsOneWidget);
    await tearDownScreen(tester);
  });

  testWidgets('a new account goes on to onboarding', (tester) async {
    await pumpSignIn(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('landed on ${AppRoutes.onboarding}'), findsOneWidget);
  });

  testWidgets('a returning account goes straight to the dashboard',
      (tester) async {
    profiles.rows[testUser.id] = sampleProfile;
    await pumpSignIn(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('landed on ${AppRoutes.today}'), findsOneWidget);
  });
}
