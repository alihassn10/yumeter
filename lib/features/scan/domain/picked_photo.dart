import 'dart:typed_data';

/// A meal photo from the camera or the gallery, ready to upload.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// File extension without the dot, e.g. `jpg`, used for the storage path
  /// and content type.
  final String extension;

  /// Takes the extension from a picked file's name, defaulting to JPEG, which
  /// is what the camera produces.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'}.contains(ext)
        ? ext
        : 'jpg';
  }
}
