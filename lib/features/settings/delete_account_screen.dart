import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../auth/data/account_remote.dart';
import '../auth/data/account_sync.dart';
import '../meals/state/meal_log_controller.dart';

/// Permanently deletes the account after the user types DELETE.
///
/// App Store guideline 5.1.1(v) and Google Play both require in-app account
/// deletion for apps that let people create an account.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const confirmWord = 'DELETE';

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      _confirm.text.trim().toUpperCase() == DeleteAccountScreen.confirmWord;

  Future<void> _delete() async {
    if (!_confirmed || _deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(accountSyncProvider).deleteAccount();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.welcome);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = switch (e.reason) {
          AccountDeletionFailure.offline =>
            'You are offline. Connect to the internet to delete your account.',
          AccountDeletionFailure.failed =>
            'Your account could not be deleted. Nothing was removed. Try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealLogProvider);
    final photos = meals.where((m) => m.photoPath != null).length;
    final streak = ref.watch(streakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Color(0x33F87171),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 36,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Delete your Yumeter account?',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This permanently deletes your account and everything in it. '
              'It cannot be undone.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardShape,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What gets deleted', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.md),
                  _Erased(
                    icon: Icons.restaurant_rounded,
                    title: _count(meals.length, 'logged meal'),
                    detail: 'Every meal and its calories and macros.',
                  ),
                  _Erased(
                    icon: Icons.photo_library_rounded,
                    title: _count(photos, 'meal photo'),
                    detail: 'Removed from storage along with the meals.',
                  ),
                  const _Erased(
                    icon: Icons.flag_rounded,
                    title: 'Your plan and profile',
                    detail: 'Your answers and daily targets.',
                  ),
                  if (streak > 0)
                    _Erased(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Your ${_count(streak, 'day')} streak',
                      detail: 'Starts again from zero if you come back.',
                    ),
                  const _Erased(
                    icon: Icons.credit_card_rounded,
                    title: 'Subscriptions are not cancelled',
                    detail: 'If you subscribed through the App Store or '
                        'Google Play, cancel it there as well.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text.rich(
              TextSpan(
                text: 'Type ',
                style: AppTypography.bodyMedium,
                children: [
                  TextSpan(
                    text: DeleteAccountScreen.confirmWord,
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.error),
                  ),
                  const TextSpan(text: ' to confirm'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _confirm,
              enabled: !_deleting,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: DeleteAccountScreen.confirmWord,
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  error,
                  style:
                      AppTypography.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: _deleting ? null : () => context.pop(),
              child: const Text('Keep my account'),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _confirmed && !_deleting ? _delete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.canvas,
              ),
              child: _deleting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Delete my account and data'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Need a break instead? You can sign out from Settings and come '
              'back to everything later.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _count(int n, String noun) =>
      '${groupedNumber(n)} $noun${n == 1 ? '' : 's'}';
}

class _Erased extends StatelessWidget {
  const _Erased({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge),
                Text(detail, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
