import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../auth/data/account_sync.dart';
import '../auth/data/auth_repository.dart';

/// Account settings. Only the account section exists so far; the rest of the
/// settings design lands with its own screen work.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final sync = ref.read(accountSyncProvider);

    // Try once more before warning, so a brief offline spell does not nag.
    await sync.syncAll();
    if (!context.mounted) return;

    final unsynced = sync.unsyncedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          unsynced == 0
              ? 'Your meals and plan stay on your account. Sign in again to '
                  'pick up where you left off.'
              : '$unsynced ${unsynced == 1 ? 'change has' : 'changes have'} '
                  'not reached your account yet. Signing out now deletes '
                  '${unsynced == 1 ? 'it' : 'them'} from this phone. Connect '
                  'to the internet first to keep ${unsynced == 1 ? 'it' : 'them'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: unsynced == 0 ? null : AppColors.error,
            ),
            child: Text(unsynced == 0 ? 'Sign out' : 'Sign out anyway'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await sync.signOut();
    if (context.mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Text('Account', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          // A Material, not a coloured box, so the tiles' ink shows on tap.
          Material(
            color: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.cardShape,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('Signed in as'),
                  subtitle: Text(user?.email ?? 'Not signed in'),
                ),
                const Divider(height: 1, color: AppColors.track),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  onTap: user == null ? null : () => _signOut(context, ref),
                ),
                const Divider(height: 1, color: AppColors.track),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Delete account',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: user == null
                      ? null
                      : () => context.push(AppRoutes.deleteAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
