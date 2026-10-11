import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/storage/profile_store.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/auth/data/account_remote.dart';
import 'package:yumeter/features/auth/data/account_sync.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';
import 'package:yumeter/features/settings/delete_account_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;
  late FakeAccountRemote account;

  Future<void> setUpSignedIn() async {
    account = FakeAccountRemote();
    container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
      account: account,
    );
    addTearDown(container.dispose);

    final log = container.read(mealLogProvider.notifier);
    await log.add(
      type: MealType.lunch,
      name: 'Salmon bowl',
      calories: 515,
      loggedAt: DateTime.now(),
      source: MealSource.photo,
      photoPath: '${testUser.id}/m1.jpg',
    );
    await log.add(
      type: MealType.snack,
      name: 'Apple',
      calories: 95,
      loggedAt: DateTime.now(),
    );
  }

  group('AccountSync.deleteAccount', () {
    test('deletes on the server, then signs out and wipes the phone',
        () async {
      await setUpSignedIn();

      await container.read(accountSyncProvider).deleteAccount();

      expect(account.deletions, 1);
      expect(container.read(currentUserProvider), isNull);
      expect(container.read(mealLogProvider), isEmpty);
      expect(container.read(storedProfileProvider), isNull);
    });

    test('a failed deletion leaves the account and the phone untouched',
        () async {
      await setUpSignedIn();
      account.failure = AccountDeletionFailure.offline;

      await expectLater(
        container.read(accountSyncProvider).deleteAccount(),
        throwsA(isA<AccountDeletionException>()),
      );

      expect(container.read(currentUserProvider), isNotNull);
      expect(container.read(mealLogProvider), hasLength(2));
      expect(container.read(storedProfileProvider), isNotNull);
    });
  });

  group('DeleteAccountScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1170, 6000)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await setUpSignedIn();
      final router = GoRouter(
        initialLocation: AppRoutes.settings,
        routes: [
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const Scaffold(body: Text('settings')),
          ),
          GoRoute(
            path: AppRoutes.deleteAccount,
            builder: (_, _) => const DeleteAccountScreen(),
          ),
          GoRoute(
            path: AppRoutes.welcome,
            builder: (_, _) => const Scaffold(body: Text('welcome')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      router.push(AppRoutes.deleteAccount);
      await tester.pumpAndSettle();
    }

    ElevatedButton deleteButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    testWidgets('lists what will be deleted from the real data',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('2 logged meals'), findsOneWidget);
      expect(find.text('1 meal photo'), findsOneWidget);
      expect(find.text('Your plan and profile'), findsOneWidget);
      expect(find.text('Subscriptions are not cancelled'), findsOneWidget);
    });

    testWidgets('stays locked until DELETE is typed', (tester) async {
      await pumpScreen(tester);
      expect(deleteButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'delet');
      await tester.pump();
      expect(deleteButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      expect(deleteButton(tester).onPressed, isNotNull);
    });

    testWidgets('deleting goes back to the welcome screen', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete my account and data'));
      await tester.pumpAndSettle();

      expect(account.deletions, 1);
      expect(find.text('welcome'), findsOneWidget);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
    });

    testWidgets('offline, it explains and keeps everything', (tester) async {
      await pumpScreen(tester);
      account.failure = AccountDeletionFailure.offline;

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete my account and data'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'You are offline. Connect to the internet to delete your account.',
        ),
        findsOneWidget,
      );
      expect(container.read(mealLogProvider), hasLength(2));
    });
  });
}
