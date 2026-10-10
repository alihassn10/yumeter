import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/supabase/supabase_config.dart';

/// The signed-in account, reduced to what the app uses.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// A sign-in step that failed in a way the user can act on.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Passwordless email sign-in: the user asks for a code, then types it in.
///
/// A code rather than a magic link keeps sign-in inside the app, with no deep
/// links to configure per platform.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits whenever the user signs in or out, including a session expiring.
  Stream<AuthUser?> get userChanges;

  /// Emails a one-time code, creating the account on first use.
  Future<void> sendCode(String email);

  Future<AuthUser> verifyCode({required String email, required String code});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final sb.GoTrueClient _auth;

  static AuthUser? _map(sb.User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges =>
      _auth.onAuthStateChange.map((state) => _map(state.session?.user));

  @override
  Future<void> sendCode(String email) => _guard(
        () => _auth.signInWithOtp(email: email, shouldCreateUser: true),
      );

  @override
  Future<AuthUser> verifyCode({required String email, required String code}) =>
      _guard(() async {
        final res = await _auth.verifyOTP(
          email: email,
          token: code,
          type: sb.OtpType.email,
        );
        final user = _map(res.user);
        if (user == null) throw const AuthFailure('That code did not work.');
        return user;
      });

  @override
  Future<void> signOut() => _auth.signOut();

  /// Turns Supabase errors into messages fit to show on screen.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthFailure {
      rethrow;
    } on sb.AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on Exception {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  static String _messageFor(sb.AuthException e) {
    final status = int.tryParse(e.statusCode ?? '');
    if (status == 429 || e.code == 'over_email_send_rate_limit') {
      return 'Too many codes requested. Wait a minute and try again.';
    }
    if (e.code == 'otp_expired' || e.code == 'invalid_credentials') {
      return 'That code is wrong or has expired. Request a new one.';
    }
    if (e.code == 'email_address_invalid' || e.code == 'validation_failed') {
      return 'That email address does not look right.';
    }
    return 'Sign-in failed. Try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider).auth),
);

/// The signed-in user, or null. Supabase restores a saved session before the
/// first frame, so this is already correct when the splash reads it.
class CurrentUser extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.userChanges.listen((user) {
      // Token refreshes re-emit the same user; only a real change matters.
      if (user?.id != state?.id) state = user;
    });
    ref.onDispose(sub.cancel);
    return repo.currentUser;
  }

  /// Picks up a sign-in right away instead of waiting for the auth stream,
  /// so work started straight after sign-in already sees the user.
  void refresh() => state = ref.read(authRepositoryProvider).currentUser;
}

final currentUserProvider = NotifierProvider<CurrentUser, AuthUser?>(
  CurrentUser.new,
);
