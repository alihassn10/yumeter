import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';

/// Horizontal ruler for picking a measurement by dragging, with a fixed centre
/// indicator and haptic ticks.
///
/// Positions are tracked as integer tick indices rather than as the value
/// itself, so repeated scrolling cannot accumulate floating-point drift.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 0.1,
    this.majorEvery = 10,
    this.height = 96,
    this.labelBuilder,
  }) : assert(min < max, 'min must be below max'),
       assert(step > 0, 'step must be positive');

  final double value;
  final double min;
  final double max;
  final double step;

  /// Draw a taller, labelled tick every this many steps.
  final int majorEvery;

  final double height;
  final ValueChanged<double> onChanged;

  /// Formats the label under a major tick. Defaults to a whole number.
  final String Function(double value)? labelBuilder;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  static const _tickSpacing = 10.0;

  /// Height of the band the tick marks and the centre indicator occupy. Labels
  /// sit below it, so the indicator never crosses one.
  static const _tickZone = 56.0;

  final _controller = ScrollController();
  late int _index = _indexOf(widget.value);
  double _viewportWidth = 0;

  int get _tickCount => ((widget.max - widget.min) / widget.step).round() + 1;

  int _indexOf(double value) => ((value.clamp(widget.min, widget.max) -
              widget.min) /
          widget.step)
      .round()
      .clamp(0, _tickCount - 1);

  double _valueOf(int index) => widget.min + index * widget.step;

  @override
  void didUpdateWidget(RulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-centre when the value is changed from outside (e.g. a unit switch),
    // but not while the user is mid-drag.
    final incoming = _indexOf(widget.value);
    if (incoming != _index && !_controller.position.isScrollingNotifier.value) {
      _index = incoming;
      _jumpToIndex(incoming);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToIndex(int index) {
    if (!_controller.hasClients) return;
    _controller.jumpTo(index * _tickSpacing);
  }

  void _onScroll(double offset) {
    final next = (offset / _tickSpacing).round().clamp(0, _tickCount - 1);
    if (next == _index) return;
    setState(() => _index = next);
    HapticFeedback.selectionClick();
    widget.onChanged(_valueOf(next));
  }

  void _snap() {
    if (!_controller.hasClients) return;
    final target = _index * _tickSpacing;
    if ((_controller.offset - target).abs() < 0.5) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.labelBuilder ?? (v) => v.toStringAsFixed(1);

    return Column(
      children: [
        Text(label(_valueOf(_index)), style: AppTypography.displaySmall),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The centre indicator is fixed, so half a viewport of padding on
              // each end lets the first and last ticks reach it.
              final width = constraints.maxWidth;
              if (width != _viewportWidth) {
                _viewportWidth = width;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _jumpToIndex(_index);
                });
              }
              final sidePadding = (width - _tickSpacing) / 2;

              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        _onScroll(notification.metrics.pixels);
                      } else if (notification is ScrollEndNotification) {
                        _snap();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      itemExtent: _tickSpacing,
                      itemCount: _tickCount,
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, i) => _Tick(
                        major: i % widget.majorEvery == 0,
                        tickZone: _tickZone,
                        label: i % widget.majorEvery == 0
                            ? label(_valueOf(i))
                            : null,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 3,
                      height: _tickZone,
                      decoration: BoxDecoration(
                        color: AppColors.calories,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.major, required this.tickZone, this.label});

  final bool major;
  final double tickZone;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Marks hang from a common baseline so the long and short ticks line
        // up along the bottom of the band rather than around its middle.
        SizedBox(
          height: tickZone,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 1.5,
              height: major ? 32 : 18,
              color: major ? AppColors.textSecondary : AppColors.track,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            label!,
            style: AppTypography.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ],
      ],
    );
  }
}
