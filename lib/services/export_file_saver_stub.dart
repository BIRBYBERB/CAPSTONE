import 'dart:typed_data';

Future<bool> saveExportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  throw UnsupportedError('File export is not supported on this platform.');
}
