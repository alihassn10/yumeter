import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../log/log_sheet.dart';

/// The signed-in frame: four tabs with a raised log button between them.
///
/// Each tab keeps its own navigation stack (go_router's indexed stack), so
/// switching away from a scrolled list and back does not reset it.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        // Re-tapping the active tab pops it back to its root, as in most apps.
        onTab: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onLog: () => showLogSheet(context),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Order matches the shell's branches.
const _tabs = [
  _Tab('Today', Icons.today_outlined, Icons.today_rounded),
  _Tab('Progress', Icons.insights_outlined, Icons.insights_rounded),
  _Tab('Meals', Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
  _Tab('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTab,
    required this.onLog,
  });

  final int currentIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    Widget tab(int index) => Expanded(
          child: _TabButton(
            tab: _tabs[index],
            selected: index == currentIndex,
            onTap: () => onTab(index),
          ),
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.track)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(child: Center(child: _LogButton(onTap: onLog))),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.calories : AppColors.textHint;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.selectedIcon : tab.icon, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tab.label,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log a meal',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.calories,
            shape: BoxShape.circle,
            boxShadow: AppColors.glow(AppColors.calories),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 30,
            color: AppColors.canvas,
          ),
        ),
      ),
    );
  }
}
