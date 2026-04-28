import 'package:flutter/material.dart';

import 'plate_scanner_overlay_stub.dart'
    if (dart.library.io) 'plate_scanner_overlay_mobile.dart' as impl;

Future<String?> showPlateScannerOverlay(
  BuildContext context, {
  required String title,
  String initialPlate = '',
}) {
  return impl.showPlateScannerOverlay(
    context,
    title: title,
    initialPlate: initialPlate,
  );
}
