// Renders the launcher icon artwork from the app's own BrandMarkPainter, so
// the icon and the in-app logo never drift apart.
//
// Regenerate after changing the mark:
//   flutter test tool/render_app_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_colors.dart';
import 'package:yumeter/core/widgets/brand_mark.dart';

const _px = 1024.0;

/// Paints the mark at [scale] of the canvas, on [background] or transparent.
Future<void> _render(
  String path, {
  required double scale,
  Color? background,
  Color? monochrome,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _px, _px), Paint()..color = background);
  }
  final side = _px * scale;
  canvas.translate((_px - side) / 2, (_px - side) / 2);
  BrandMarkPainter(monochrome: monochrome).paint(canvas, Size.square(side));

  final image = await recorder.endRecording().toImage(_px.toInt(), _px.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render launcher icon artwork', () async {
    // iOS and legacy Android: the whole square; the system rounds the corners.
    await _render('assets/icon/icon.png', scale: 0.62, background: AppColors.canvas);
    // Android adaptive icon: launchers crop to any shape inside the middle
    // 66%, so the mark stays well within it.
    await _render('assets/icon/foreground.png', scale: 0.5);
    // Android 13+ themed icons recolour a flat silhouette.
    await _render('assets/icon/monochrome.png', scale: 0.5, monochrome: Colors.white);
  });
}
