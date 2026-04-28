import 'package:flutter/material.dart';

Future<String?> showPlateScannerOverlay(
  BuildContext context, {
  required String title,
  String initialPlate = '',
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierLabel: title,
    barrierDismissible: true,
    barrierColor: const Color(0xC0000000),
    pageBuilder: (context, _, __) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16233F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Real-time plate scanning is available on Android and iOS builds that include ML Kit support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
