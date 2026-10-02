import 'dart:typed_data';

import 'export_file_saver_stub.dart'
    if (dart.library.io) 'export_file_saver_io.dart'
    if (dart.library.js_interop) 'export_file_saver_web.dart'
    as platform;

Future<bool> saveExportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  return platform.saveExportFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes,
  );
}
