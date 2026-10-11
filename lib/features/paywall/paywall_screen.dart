import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_badge.dart';

/// A subscription option as shown on the paywall.
///
/// Prices are placeholders until RevenueCat supplies the store's own localised
/// strings — never hard-code them at release, or the paywall will disagree
/// with what the user is actually charged.
class _Option {
  const _Option({
    required this.id,
    required this.title,
    required this.price,
    required this.detail,
    this.badge,
  });

  final String id;
  final String title;
  final String price;
  final String detail;
  final String? badge;
}

const _options = [
  _Option(
    id: 'yearly',
    title: 'Yearly',
    price: r'$39.99 / year',
    detail: r'About $0.77 a week',
    badge: 'Best value',
  ),
  _Option(
    id: 'weekly',
    title: 'Weekly',
    price: r'$4.99 / week',
    detail: 'Cancel any time',
  ),
];

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selected = _options.first.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                // TODO(billing): gate this behind entitlement checks once
                // RevenueCat is wired. It exists now so the flow is walkable.
                onPressed: () => context.go(AppRoutes.today),
                child: const Text('Not now'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Track every meal in\na couple of taps',
                      style: context.text.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _Benefits(),
                    const SizedBox(height: AppSpacing.xl),
                    for (final (i, option) in _options.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _OptionCard(
                        option: option,
                        selected: _selected == option.id,
                        onTap: () => setState(() => _selected = option.id),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  ElevatedButton(
                    // TODO(billing): start the RevenueCat purchase flow.
                    onPressed: () => context.go(AppRoutes.today),
                    child: const Text('Start 3-day free trial'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Apple requires the trial length, the price after it, and
                  // the renewal terms to be legible before purchase.
                  Text(
                    'Free for 3 days, then '
                    '${_options.firstWhere((o) => o.id == _selected).price}. '
                    'Renews automatically until cancelled. Cancel any time in '
                    'your store account settings.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        .copyWith(color: context.colors.textHint),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    // TODO(billing): call RevenueCat restorePurchases.
                    onPressed: () {},
                    child: const Text('Restore purchases'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.photo_camera_rounded, 'Log a meal from a photo'),
    (Icons.tune_rounded, 'Edit any result in one tap'),
    (Icons.qr_code_scanner_rounded, 'Scan barcodes and labels'),
    (Icons.insights_rounded, 'See your weight trend over time'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, label) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 22, color: context.colors.calories),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: context.text.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Option option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadii.nestedShape,
            border: Border.all(
              color: selected ? context.colors.calories : context.colors.track,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(option.title,
                            style: context.text.headlineSmall),
                        if (option.badge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          AccentBadge(label: option.badge!, tinted: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(option.detail, style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                option.price,
                style: context.text.labelLarge.copyWith(
                  color:
                      selected ? context.colors.calories : context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
