import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_colors.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/core/theme/theme_mode.dart';
import 'package:yumeter/features/settings/settings_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  test('follows the phone by default and remembers a choice', () async {
    final prefs = await testPrefs();
    final first = testContainer(prefs);
    addTearDown(first.dispose);
    expect(first.read(themeModeProvider), ThemeMode.system);

    await first.read(themeModeProvider.notifier).set(ThemeMode.light);

    // A fresh start reads the saved choice back.
    final second = testContainer(prefs);
    addTearDown(second.dispose);
    expect(second.read(themeModeProvider), ThemeMode.light);
  });

  test('each theme carries its own palette', () {
    expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
    expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.light.brightness, Brightness.light);
    // Dark text on the orange button in both modes; white on it is too faint.
    expect(AppTheme.light.colorScheme.onPrimary, AppPalette.light.onAccent);
    expect(AppPalette.light.onAccent, const Color(0xFF0A0A0B));
  });

  testWidgets('picking Light in Settings repaints the app in light colours',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1170, 7000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ref.watch(themeModeProvider),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color canvas() => tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(canvas(), AppPalette.dark.canvas);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(canvas(), AppPalette.light.canvas);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
