import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Yumeter logo: a gauge arc sweeping red through amber to green, with the
/// wordmark's Y centred inside it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.tile = true});

  final double size;

  /// Draws the rounded dark tile behind the gauge, as on the splash screen.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final gauge = CustomPaint(
      painter: _GaugePainter(),
      size: Size.square(size * 0.66),
      child: SizedBox.square(
        dimension: size * 0.66,
        child: Center(
          child: Text(
            'Y',
            style: TextStyle(
              fontSize: size * 0.3,
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );

    if (!tile) return gauge;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.track),
      ),
      child: Center(child: gauge),
    );
  }
}

class _GaugePainter extends CustomPainter {
  /// The arc runs from just right of top, clockwise round the bottom, to just
  /// left of top — leaving a gap at the top so it reads as a dial, not a ring.
  static const _start = -math.pi * 0.22;
  static const _sweep = math.pi * 1.44;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.16;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      // The sweep is described from zero and then rotated into place; giving
      // both a start angle and a rotation would offset the colours twice.
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: _sweep,
        // Ordered along the sweep, so green lands at the top right and red at
        // the top left.
        colors: [
          AppColors.success,
          AppColors.carbs,
          AppColors.calories,
          AppColors.error,
        ],
        transform: GradientRotation(_start),
      ).createShader(rect);

    canvas.drawArc(rect, _start, _sweep, false, paint);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) => false;
}
