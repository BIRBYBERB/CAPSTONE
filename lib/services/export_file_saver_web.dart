import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> saveExportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(objectUrl),
    ),
  );
  return true;
}
