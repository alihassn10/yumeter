import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../data/food_repository.dart';

/// A product photo from Open Food Facts, or a neutral tile when there is none
/// or it cannot load.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.size = 52});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.inventory_2_outlined,
      color: context.colors.textHint,
      size: size * 0.45,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: context.colors.surfaceNested,
          child: url == null
              ? placeholder
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Open Food Facts data is under the Open Database Licence, which asks for
/// attribution wherever it is shown.
class OpenFoodFactsCredit extends StatelessWidget {
  const OpenFoodFactsCredit({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Food data from Open Food Facts, available under the Open Database '
      'Licence. Values come from product labels and may contain mistakes.',
      style: context.text.bodySmall.copyWith(color: context.colors.textHint),
      textAlign: TextAlign.center,
    );
  }
}

/// User-facing wording for a lookup that failed.
String foodFailureMessage(FoodLookupFailure reason) => switch (reason) {
      FoodLookupFailure.offline =>
        'You are offline. Food search needs a connection.',
      FoodLookupFailure.busy =>
        'The food database is busy. Wait a moment and try again.',
      FoodLookupFailure.failed =>
        'The food database did not answer. Try again.',
    };
