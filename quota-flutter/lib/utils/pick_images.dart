import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final _picker = ImagePicker();

// Downscale + re-encode on pick so huge camera photos don't blow out
// uploads or the server's size cap.
const _maxDimension = 2048.0;
const _jpegQuality = 80;

/// Let the user pick images from the gallery or take a photo,
/// compressed client-side. Returns an empty list if cancelled.
Future<List<XFile>> pickCompressedImages(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("From gallery"),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text("Take photo"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return [];

  try {
    if (source == ImageSource.gallery) {
      return await _picker.pickMultiImage(
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _jpegQuality,
      );
    }
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _jpegQuality,
    );
    return photo == null ? [] : [photo];
  } catch (_) {
    // Picker unavailable (e.g. permissions); treat as cancelled.
    return [];
  }
}
