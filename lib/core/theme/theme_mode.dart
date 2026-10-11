import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences.dart';

/// Light, dark, or following the phone's setting. Kept on this device only:
/// it is a display preference, not account data, so it does not sync.
class AppThemeMode extends Notifier<ThemeMode> {
  static const _key = 'settings.themeMode';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<AppThemeMode, ThemeMode>(
  AppThemeMode.new,
);
