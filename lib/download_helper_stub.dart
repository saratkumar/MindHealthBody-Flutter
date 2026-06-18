import 'dart:typed_data';

Future<void> downloadFileImpl(
    Uint8List bytes, String filename, String mimeType) async {
  // No-op on non-web platforms
}
