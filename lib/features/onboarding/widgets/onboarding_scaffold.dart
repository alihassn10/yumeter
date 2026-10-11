import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';

/// Shared chrome for every quiz step: progress header, heading block, the
/// step's own content, and the continue button.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.child,
    required this.onBack,
    required this.onContinue,
    this.subtitle,
    this.eyebrow,
    this.footnote,
    this.continueLabel = 'Continue',
    this.scrollable = true,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;

  /// Small all-caps line above the title.
  final String? eyebrow;

  final String? footnote;
  final Widget child;
  final VoidCallback onBack;

  /// Null disables the button — the step is not answered yet.
  final VoidCallback? onContinue;

  final String continueLabel;

  /// False when the step owns its own scrolling or must fill the height.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.tint(context.colors.calories),
              borderRadius: AppRadii.pillShape,
            ),
            child: Text(
              eyebrow!.toUpperCase(),
              style: context.text.labelSmall
                  .copyWith(color: context.colors.calories),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(title, style: context.text.headlineLarge),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!, style: context.text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: step, total: totalSteps, onBack: onBack),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                child: scrollable
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [heading, child],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [heading, Expanded(child: child)],
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
                    onPressed: onContinue,
                    child: Text(continueLabel),
                  ),
                  if (footnote != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      footnote!,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          .copyWith(color: context.colors.textHint),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.total,
    required this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'STEP ',
                    style: context.text.labelSmall,
                    children: [
                      TextSpan(
                        text: '$step',
                        style: context.text.labelSmall
                            .copyWith(color: context.colors.calories),
                      ),
                      TextSpan(text: ' OF $total'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Balances the leading icon so the counter stays centred.
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: step / total),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: context.colors.calories,
                  backgroundColor: context.colors.track,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
