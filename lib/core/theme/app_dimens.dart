import 'package:flutter/widgets.dart';

/// Spacing scale — an 8pt base grid tuned for one-hand reach.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const xl = 28.0;

  /// Gutter between cards in a row (e.g. the 3-column macro strip).
  static const gutter = 16.0;

  /// Horizontal safe margin on a screen canvas.
  static const screenMargin = 20.0;
}

/// Corner radii — a pill-dominant geometry.
abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 16.0;

  /// Macro mini-cards and nested blocks.
  static const nested = 20.0;

  /// Primary cards and dashboard blocks.
  static const card = 28.0;

  /// Top corners of a bottom sheet.
  static const sheet = 32.0;

  static const pill = 999.0;

  static const cardShape = BorderRadius.all(Radius.circular(card));
  static const nestedShape = BorderRadius.all(Radius.circular(nested));
  static const pillShape = BorderRadius.all(Radius.circular(pill));
  static const sheetShape = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Fixed control heights.
abstract final class AppSizes {
  static const primaryButton = 56.0;
  static const input = 48.0;
  static const ringStroke = 10.0;
}
