import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which Supabase project the app talks to.
///
/// Defaults point at `yumeter-dev`. A release build passes the production
/// project with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`
/// so testing never touches real users. The publishable key is designed to
/// ship inside the app; row-level security is what protects the data.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qraksxkldrloltzlmhhd.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_m9aS6znLcFfGlUrqZSZoUg_jqlOoqDz',
  );
}

/// Initialised in `main` and overridden there; tests override the
/// repositories built on it instead, so they never reach the network.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => throw StateError(
    'supabaseClientProvider must be overridden in main or in the test',
  ),
);
