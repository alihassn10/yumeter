import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import 'widgets/meal_type_chips.dart';

Future<void> showLogSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LogSheet(),
    );

/// Every way into logging, plus the user's recent meals for one-tap repeats.
class LogSheet extends ConsumerStatefulWidget {
  const LogSheet({super.key});

  @override
  ConsumerState<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<LogSheet> {
  late MealType _type = MealType.forTime(DateTime.now());

  /// Closes the sheet first: pushing from inside it would stack the route
  /// under the sheet's own modal route.
  void _open(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(Uri(path: route, queryParameters: {'meal': _type.name}).toString());
  }

  Future<void> _relog(MealEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final day = ref.read(selectedDayProvider);

    await ref
        .read(mealLogProvider.notifier)
        .relog(entry, type: _type, loggedAt: logTimeFor(day));

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added ${entry.name} to ${_type.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentMealsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          0,
          AppSpacing.screenMargin,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Log a meal', style: AppTypography.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              MealTypeChips(
                selected: _type,
                onChanged: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: AppSpacing.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.35,
                children: [
                  _MethodTile(
                    icon: Icons.photo_camera_rounded,
                    title: 'Scan food',
                    subtitle: 'From a photo of your plate',
                    onTap: () => _open(AppRoutes.scan),
                  ),
                  _MethodTile(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Scan barcode',
                    subtitle: 'Packaged food',
                    onTap: () => _open(AppRoutes.barcodeResult),
                  ),
                  _MethodTile(
                    icon: Icons.search_rounded,
                    title: 'Search food',
                    subtitle: 'Find it by name',
                    onTap: () => _open(AppRoutes.foodSearch),
                  ),
                  _MethodTile(
                    icon: Icons.bolt_rounded,
                    title: 'Quick add',
                    subtitle: 'Type in the calories',
                    onTap: () => _open(AppRoutes.quickAdd),
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Recent', style: AppTypography.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                for (final entry in recent)
                  _RecentRow(entry: entry, onAdd: () => _relog(entry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceNested,
      borderRadius: AppRadii.nestedShape,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.nestedShape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.calories),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.calories),
              ),
              const Spacer(),
              Text(title, style: AppTypography.labelLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.onAdd});

  final MealEntry entry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  style: AppTypography.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${entry.calories} kcal', style: AppTypography.bodySmall),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onAdd,
            tooltip: 'Add ${entry.name}',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
