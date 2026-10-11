import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'domain/picked_photo.dart';

/// Takes or picks a meal photo and hands it to the result screen.
///
/// The camera runs at a 720p preset: plenty for recognising food, and small
/// enough to upload quickly on a mobile connection without a separate
/// compression step.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraProblem;
  FlashMode _flash = FlashMode.off;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  // The camera is a shared device: release it while backgrounded so other
  // apps can use it, and reopen it on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final camera = _camera;
      _camera = null;
      camera?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera on this device');
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      await camera.setFlashMode(_flash);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraProblem = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraProblem = e.code.contains('AccessDenied')
            ? 'Camera access is off. Allow it in your phone settings, or '
                'upload a photo instead.'
            : 'The camera is not available. You can upload a photo instead.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _cameraProblem =
          'The camera is not available. You can upload a photo instead.');
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final next = _flash == FlashMode.off ? FlashMode.always : FlashMode.off;
    try {
      await camera.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException {
      // No flash on this camera; leave the toggle where it was.
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy || camera.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final file = await camera.takePicture();
      await _open(PickedPhoto(
        bytes: await file.readAsBytes(),
        extension: PickedPhoto.extensionOf(file.name),
      ));
    } on CameraException {
      _showMessage('Could not take the photo. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Resized on the device so large gallery photos upload quickly.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      await _open(PickedPhoto(
        bytes: await file.readAsBytes(),
        extension: PickedPhoto.extensionOf(file.name),
      ));
    } on Exception {
      _showMessage('Could not open that photo. Try another one.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(PickedPhoto photo) async {
    if (!mounted) return;
    await context.push(AppRoutes.mealResult, extra: photo);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        title: const Text('Scan food'),
        actions: [
          if (ready)
            IconButton(
              onPressed: _toggleFlash,
              tooltip: _flash == FlashMode.off ? 'Flash off' : 'Flash on',
              icon: Icon(
                _flash == FlashMode.off
                    ? Icons.flash_off_rounded
                    : Icons.flash_on_rounded,
              ),
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
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: ready
                        ? _Viewfinder(camera: camera)
                        : _CameraPlaceholder(problem: _cameraProblem),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Keep the whole plate in frame and well lit.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SideAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload',
                  onPressed: _busy ? null : _upload,
                ),
                _Shutter(onPressed: ready && !_busy ? _capture : null),
                _SideAction(
                  icon: Icons.edit_note_rounded,
                  label: 'Type it in',
                  onPressed: () =>
                      context.pushReplacement(AppRoutes.quickAdd),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    // Fill the frame without distorting: cover-fit the preview.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        // previewSize is reported in landscape; the screen is portrait.
        width: camera.value.previewSize?.height ?? 720,
        height: camera.value.previewSize?.width ?? 1280,
        child: CameraPreview(camera),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({this.problem});

  final String? problem;

  @override
  Widget build(BuildContext context) {
    final problem = this.problem;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: problem == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.no_photography_rounded,
                    size: 40,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    problem,
                    style: context.text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.calories, width: 3),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.calories,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: context.colors.canvas,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 26,
          style: IconButton.styleFrom(
            backgroundColor: context.colors.surface,
            foregroundColor: context.colors.textPrimary,
            minimumSize: const Size.square(52),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}
