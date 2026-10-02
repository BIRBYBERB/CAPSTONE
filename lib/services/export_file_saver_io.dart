import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> saveExportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final extension = fileName.split('.').last;
  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Simpan partitur',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
  );
  return savedPath != null;
}
