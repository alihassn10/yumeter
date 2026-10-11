import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Yumeter logo: a gauge arc sweeping red through amber to green, with a
/// Y centred inside it.
///
/// Drawn entirely with paths, the Y included, so the same mark renders
/// identically everywhere: in the app, and in the launcher icons generated
/// from it by `tool/render_app_icon.dart`.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.tile = true});

  final double size;

  /// Draws the rounded dark tile behind the gauge, as on the splash screen.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final gauge = CustomPaint(
      painter: const BrandMarkPainter(),
      size: Size.square(size * 0.66),
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

/// Paints the gauge and its Y into a square. [monochrome] paints both in one
/// flat colour, for Android's themed icons.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.monochrome});

  final Color? monochrome;

  /// The arc runs from just right of top, clockwise round the bottom, to just
  /// left of top — leaving a gap at the top so it reads as a dial, not a ring.
  static const _start = -math.pi * 0.22;
  static const _sweep = math.pi * 1.44;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = side * 0.16;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: (side - stroke) / 2);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (monochrome case final color?) {
      arc.color = color;
    } else {
      // The gradient's wrap-around point sits in the middle of the gap at the
      // top. Anywhere else, the rounded caps, which reach slightly past the
      // arc's ends, pick up the colour from the far end of the sweep.
      const halfGap = (2 * math.pi - _sweep) / 2;
      arc.shader = const SweepGradient(
        startAngle: halfGap,
        endAngle: halfGap + _sweep,
        // Ordered along the sweep, so green lands at the top right and red at
        // the top left.
        colors: [
          AppColors.success,
          AppColors.carbs,
          AppColors.calories,
          AppColors.error,
        ],
        transform: GradientRotation(_start - halfGap),
      ).createShader(rect);
    }
    canvas.drawArc(rect, _start, _sweep, false, arc);

    // The Y: two arms meeting just above centre, then the stem.
    final y = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = monochrome ?? AppColors.textPrimary;
    final h = side * 0.4;
    final top = center.dy - h / 2;
    final join = Offset(center.dx, center.dy + side * 0.01);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - side * 0.13, top)
        ..lineTo(join.dx, join.dy)
        ..lineTo(center.dx + side * 0.13, top)
        ..moveTo(join.dx, join.dy)
        ..lineTo(center.dx, top + h),
      y,
    );
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome;
}
