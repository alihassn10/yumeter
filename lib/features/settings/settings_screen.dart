import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/utils/format.dart';
import '../auth/data/account_sync.dart';
import '../auth/data/auth_repository.dart';
import '../meals/state/meal_log_controller.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../onboarding/state/onboarding_controller.dart';
import '../plan/plan_providers.dart';
import '../progress/weight_log_sheet.dart';
import 'profile_edit_sheet.dart';

/// The account, the plan's inputs and targets, and account actions.
///
/// Every row here edits something the app actually uses. The design's
/// integrations, camera toggles and reminders are left out until they exist.
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
              foregroundColor: unsynced == 0 ? null : context.colors.error,
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
    final profile = ref.watch(storedProfileProvider);
    final plan = ref.watch(activePlanProvider);
    final meals = ref.watch(mealLogProvider);
    final streak = ref.watch(streakProvider);
    final loggedDays = ref.watch(loggedDaysProvider);

    void edit(String title, List<OnboardingStep> steps) =>
        showProfileEditor(context, ref, title: title, steps: steps);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.xl * 3,
          ),
          children: [
            Text('Settings', style: context.text.headlineLarge),
            const SizedBox(height: AppSpacing.lg),
            _AccountCard(
              email: user?.email,
              streak: streak,
              meals: meals.length,
              days: loggedDays.length,
            ),
            if (profile != null) ...[
              const _SectionTitle('Nutrition and goals'),
              _Group(
                children: [
                  _Row(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Daily calorie target',
                    subtitle: 'Worked out from your profile and goal',
                    value: plan == null
                        ? null
                        : '${groupedNumber(plan.calories)} kcal',
                    onTap: plan == null
                        ? null
                        : () => _showTargetBreakdown(context, plan, profile),
                  ),
                  _Row(
                    icon: Icons.flag_rounded,
                    title: 'Goal',
                    subtitle: _goalSummary(profile),
                    onTap: () => edit('Your goal', const [
                      OnboardingStep.goal,
                      OnboardingStep.targetWeight,
                      OnboardingStep.pace,
                    ]),
                  ),
                  if (profile.goal != WeightGoal.maintain &&
                      profile.targetWeightKg != null)
                    _Row(
                      icon: Icons.track_changes_rounded,
                      title: 'Target weight',
                      subtitle: _toGo(profile),
                      value: _weight(profile.targetWeightKg!, profile),
                      onTap: () => edit(
                        'Target weight',
                        const [OnboardingStep.targetWeight],
                      ),
                    ),
                  _Row(
                    icon: Icons.pie_chart_rounded,
                    title: 'Diet and macros',
                    subtitle: _macroSummary(profile.dietType, plan),
                    value: profile.dietType.label,
                    onTap: () =>
                        edit('How you eat', const [OnboardingStep.diet]),
                  ),
                ],
              ),
              const _SectionTitle('Your profile'),
              _Group(
                children: [
                  _Row(
                    icon: Icons.monitor_weight_rounded,
                    title: 'Current weight',
                    subtitle: 'Logging a weigh-in updates your targets',
                    value: profile.weightKg == null
                        ? null
                        : _weight(profile.weightKg!, profile),
                    onTap: () => showWeightLogSheet(context),
                  ),
                  _Row(
                    icon: Icons.height_rounded,
                    title: 'Height',
                    value: profile.heightCm == null
                        ? null
                        : _height(profile.heightCm!, profile),
                    onTap: () => edit(
                      'Height and weight',
                      const [OnboardingStep.measurements],
                    ),
                  ),
                  _Row(
                    icon: Icons.cake_rounded,
                    title: 'Age',
                    value: profile.age == null ? null : '${profile.age}',
                    onTap: () =>
                        edit('Your age', const [OnboardingStep.birthDate]),
                  ),
                  _Row(
                    icon: Icons.person_rounded,
                    title: 'Sex',
                    value: switch (profile.sex) {
                      Sex.female => 'Female',
                      Sex.male => 'Male',
                      Sex.other => 'Not specified',
                      null => null,
                    },
                    onTap: () => edit('About you', const [OnboardingStep.sex]),
                  ),
                  _Row(
                    icon: Icons.directions_run_rounded,
                    title: 'Activity',
                    value: profile.activityLevel?.label,
                    onTap: () => edit(
                      'How active you are',
                      const [OnboardingStep.activity],
                    ),
                  ),
                  _UnitsRow(profile: profile),
                ],
              ),
            ],
            const _SectionTitle('Appearance'),
            const _Group(children: [_ThemeRow()]),
            const _SectionTitle('Account'),
            _Group(
              children: [
                _Row(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  onTap: user == null ? null : () => _signOut(context, ref),
                ),
                _Row(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete account',
                  subtitle: 'Your meals, weigh-ins, photos and plan',
                  destructive: true,
                  onTap: user == null
                      ? null
                      : () => context.push(AppRoutes.deleteAccount),
                ),
              ],
            ),
            const _SectionTitle('Legal'),
            _Group(
              children: [
                _Row(
                  icon: Icons.shield_outlined,
                  title: 'Privacy policy',
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                _Row(
                  icon: Icons.description_outlined,
                  title: 'Terms of use',
                  onTap: () => context.push(AppRoutes.terms),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Yumeter gives estimates from a standard formula and from '
              'photos. It is not a medical device and does not give medical '
              'advice. Talk to a doctor or dietitian before big changes to '
              'what you eat.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _weight(double kg, OnboardingAnswers p) =>
      p.units == UnitSystem.imperial
          ? '${Units.kgToLb(kg).toStringAsFixed(1)} lb'
          : '${kg.toStringAsFixed(1)} kg';

  static String _height(double cm, OnboardingAnswers p) {
    if (p.units == UnitSystem.metric) return '${cm.round()} cm';
    final (feet, inches) = Units.cmToFeetInches(cm);
    return '$feet′ $inches″';
  }

  static String _goalSummary(OnboardingAnswers p) {
    final goal = p.goal;
    if (goal == null) return 'Not set';
    if (goal == WeightGoal.maintain) return goal.label;
    final pace = p.units == UnitSystem.imperial
        ? '${Units.kgToLb(p.paceKgPerWeek).toStringAsFixed(1)} lb'
        : '${p.paceKgPerWeek.toStringAsFixed(1)} kg';
    return '${goal.label} · $pace a week';
  }

  static String? _toGo(OnboardingAnswers p) {
    final current = p.weightKg, target = p.targetWeightKg;
    if (current == null || target == null) return null;
    final diff = (current - target).abs();
    if (diff < 0.05) return 'You are at your target';
    return '${_weight(diff, p)} to go';
  }

  static String _macroSummary(DietType diet, NutritionPlan? plan) {
    String pct(double r) => '${(r * 100).round()}%';
    final split = 'Protein ${pct(diet.proteinRatio)}, carbs '
        '${pct(diet.carbRatio)}, fat ${pct(diet.fatRatio)}';
    return plan == null
        ? split
        : '$split · ${plan.proteinGrams}g, ${plan.carbGrams}g, '
            '${plan.fatGrams}g a day';
  }

  /// Shows how the target was reached, so it reads as a worked estimate
  /// rather than a figure from nowhere.
  static void _showTargetBreakdown(
    BuildContext context,
    NutritionPlan plan,
    OnboardingAnswers profile,
  ) {
    final adjustment = plan.calories - plan.tdee;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          0,
          AppSpacing.screenMargin,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How your target is worked out',
                style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            _BreakdownLine(
              'Energy at rest',
              '${groupedNumber(plan.bmr)} kcal',
              'Mifflin-St Jeor, from your age, sex, height and weight',
            ),
            _BreakdownLine(
              'With your activity',
              '${groupedNumber(plan.tdee)} kcal',
              profile.activityLevel?.label ?? '',
            ),
            _BreakdownLine(
              'Goal adjustment',
              '${adjustment > 0 ? '+' : adjustment < 0 ? '−' : ''}'
                  '${groupedNumber(adjustment.abs())} kcal',
              _goalSummary(profile),
            ),
            Divider(color: context.colors.track),
            _BreakdownLine(
              'Daily target',
              '${groupedNumber(plan.calories)} kcal',
              null,
            ),
            if (plan.clampedToFloor) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your target is held at a safe minimum, so you may move more '
                'slowly than the pace you chose.',
                style: context.text.bodySmall
                    .copyWith(color: context.colors.carbs),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'An estimate, not a measurement or medical advice. It updates '
              'when you log a new weight or change your profile.',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.email,
    required this.streak,
    required this.meals,
    required this.days,
  });

  final String? email;
  final int streak;
  final int meals;
  final int days;

  @override
  Widget build(BuildContext context) {
    final initial = (email ?? '?').substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.tint(context.colors.calories),
                child: Text(
                  initial,
                  style: context.text.headlineSmall
                      .copyWith(color: context.colors.calories),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signed in as', style: context.text.bodySmall),
                    Text(
                      email ?? 'Not signed in',
                      style: context.text.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Figure(label: 'Streak', value: '$streak d'),
              _Figure(label: 'Meals logged', value: groupedNumber(meals)),
              _Figure(label: 'Days logged', value: groupedNumber(days)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: context.text.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: context.text.metricSub),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        0,
        AppSpacing.sm,
      ),
      child: Text(text.toUpperCase(), style: context.text.labelMedium),
    );
  }
}

/// Rows on one rounded card, separated by hairlines. A Material rather than
/// a coloured box, so each row's ink shows when tapped.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardShape),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 56, color: context.colors.track),
            child,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : null;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? context.colors.textSecondary),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: context.text.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value case final v?)
            Text(v, style: context.text.labelLarge),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: context.colors.textHint),
        ],
      ),
    );
  }
}

class _UnitsRow extends ConsumerWidget {
  const _UnitsRow({required this.profile});

  final OnboardingAnswers profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(Icons.straighten_rounded,
          color: context.colors.textSecondary),
      title: const Text('Units'),
      trailing: SegmentedButton<UnitSystem>(
        segments: const [
          ButtonSegment(value: UnitSystem.metric, label: Text('kg, cm')),
          ButtonSegment(value: UnitSystem.imperial, label: Text('lb, ft')),
        ],
        selected: {profile.units},
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (s) => ref
            .read(accountSyncProvider)
            .saveProfile(profile.copyWith(units: s.first)),
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodyLarge),
                if (detail case final d? when d.isNotEmpty)
                  Text(d, style: context.text.bodySmall),
              ],
            ),
          ),
          Text(value, style: context.text.labelLarge),
        ],
      ),
    );
  }
}

/// Light, dark or the phone's own setting. Changes apply at once.
class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.contrast_rounded, color: context.colors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Text('Theme', style: context.text.bodyLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.phone_android_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {ref.watch(themeModeProvider)},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}
