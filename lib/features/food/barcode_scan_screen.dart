import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../meals/domain/meal_entry.dart';
import 'data/food_repository.dart';
import 'food_product_screen.dart';
import 'widgets/food_widgets.dart';

/// Scans a product barcode and looks it up in Open Food Facts.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key, this.mealType});

  final MealType? mealType;

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  // Retail barcodes only, so QR codes and shipping labels are ignored.
  final _scanner = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _looking = false;
  String? _problem;

  /// The last code looked up and when the user came back from it, so a
  /// barcode still in view does not reopen its product at once.
  String? _lastCode;
  DateTime _lastAt = DateTime(0);

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_looking || _problem != null) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && RegExp(r'^\d{8,14}$').hasMatch(code)) {
        final justHandled = code == _lastCode &&
            DateTime.now().difference(_lastAt) < const Duration(seconds: 4);
        if (!justHandled) _lookUp(code);
        return;
      }
    }
  }

  Future<void> _lookUp(String code) async {
    _lastCode = code;
    setState(() {
      _looking = true;
      _problem = null;
    });
    try {
      final product = await ref.read(foodRepositoryProvider).byBarcode(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _problem =
            'This barcode ($code) is not in Open Food Facts yet, or has no '
            'nutrition data. Search by name or type the calories in.');
        return;
      }
      await context.push(
        AppRoutes.foodProduct,
        extra: FoodProductArgs(
          product: product,
          source: MealSource.barcode,
          mealType: widget.mealType,
        ),
      );
      _lastAt = DateTime.now();
    } on FoodLookupException catch (e) {
      if (mounted) setState(() => _problem = foodFailureMessage(e.reason));
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _typeBarcode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Type the barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
          ],
          decoration: const InputDecoration(hintText: 'The digits under the bars'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.length >= 8) await _lookUp(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            onPressed: _scanner.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
            tooltip: 'Torch',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                child: ClipRRect(
                  borderRadius: AppRadii.cardShape,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => _CameraError(
                          denied: error.errorCode ==
                              MobileScannerErrorCode.permissionDenied,
                        ),
                      ),
                      // The aiming box: a barcode is wide and short.
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.8,
                          child: AspectRatio(
                            aspectRatio: 2.2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: context.colors.calories,
                                  width: 3,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_looking)
                        const ColoredBox(
                          color: Color(0x99000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_problem case final problem?) ...[
                    Text(
                      problem,
                      style: context.text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => setState(() => _problem = null),
                      child: const Text('Scan again'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () =>
                          context.pushReplacement(AppRoutes.quickAdd),
                      child: const Text('Type the calories in'),
                    ),
                  ] else
                    Text(
                      'Line the barcode up inside the box.',
                      style: context.text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  TextButton(
                    onPressed: _looking ? null : _typeBarcode,
                    child: const Text('Type the barcode instead'),
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

class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            denied
                ? 'Camera access is off. Allow it in your phone settings, or '
                    'type the barcode instead.'
                : 'The camera is not available. You can type the barcode '
                    'instead.',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
