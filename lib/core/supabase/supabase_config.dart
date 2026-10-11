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

  /// The Google OAuth *web* client, which Google signs ID tokens for and
  /// Supabase checks them against. Client IDs are public by design; the
  /// client secret lives only in the Supabase dashboard.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '609463770262-9ofu996r2jvkbr471lupj9h166cug6m4.apps.googleusercontent.com',
  );
}

/// Initialised in `main` and overridden there; tests override the
/// repositories built on it instead, so they never reach the network.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => throw StateError(
    'supabaseClientProvider must be overridden in main or in the test',
  ),
);
