import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

/// Why deleting the account did not go through.
enum AccountDeletionFailure { offline, failed }

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.reason);

  final AccountDeletionFailure reason;
}

/// Server-side account actions that need more than the user's own rights.
abstract interface class AccountRemote {
  /// Deletes the signed-in account, its profile, meals and photos for good.
  Future<void> deleteAccount();
}

class SupabaseAccountRemote implements AccountRemote {
  SupabaseAccountRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException {
      throw const AccountDeletionException(AccountDeletionFailure.failed);
    } on Exception {
      throw const AccountDeletionException(AccountDeletionFailure.offline);
    }
  }
}

final accountRemoteProvider = Provider<AccountRemote>(
  (ref) => SupabaseAccountRemote(ref.watch(supabaseClientProvider)),
);
