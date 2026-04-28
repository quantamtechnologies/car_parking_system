import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String?> showPlateScannerOverlay(
  BuildContext context, {
  required String title,
  String initialPlate = '',
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierLabel: title,
    barrierDismissible: false,
    barrierColor: const Color(0xC0000000),
    pageBuilder: (context, _, __) => _PlateScannerDialog(title: title),
  );
}

class _PlateScannerDialog extends StatefulWidget {
  const _PlateScannerDialog({required this.title});

  final String title;

  @override
  State<_PlateScannerDialog> createState() => _PlateScannerDialogState();
}

class _PlateScannerDialogState extends State<_PlateScannerDialog> {
  static final RegExp _platePattern = RegExp(r'[A-Z0-9]{5,10}');
  static const Map<DeviceOrientation, int> _orientations =
      <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  CameraController? _controller;
  bool _initializing = true;
  bool _streaming = false;
  bool _processing = false;
  bool _closing = false;
  bool _disposed = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (!mounted) return;
      setState(() {
        _status = 'Real-time scanning is available on Android and iOS only.';
        _initializing = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no-camera', 'No available camera found.');
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      await controller.startImageStream(_processFrame);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _streaming = true;
        _initializing = false;
        _status = 'Align the number plate inside the frame.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Unable to start the camera right now.';
        _initializing = false;
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _closing || !mounted) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _processing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image, controller);
      if (inputImage == null) return;

      final recognizedText = await _recognizer.processImage(inputImage);
      final plate = _extractPlate(recognizedText);
      if (plate == null || plate.isEmpty || !mounted || _closing) return;

      await _closeWithPlate(plate);
    } catch (_) {
      if (mounted && !_closing) {
        setState(() {
          _status = 'Scanning... keep the plate steady.';
        });
      }
    } finally {
      _processing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    final rotation = _rotationFromController(controller);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) {
      return null;
    }

    if ((Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationFromController(CameraController controller) {
    final sensorOrientation = controller.description.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (!Platform.isAndroid) {
      return null;
    }

    final deviceRotation = _orientations[controller.value.deviceOrientation];
    if (deviceRotation == null) return null;

    final rotationCompensation =
        (sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  String? _extractPlate(RecognizedText recognizedText) {
    final candidates = <String>[
      for (final block in recognizedText.blocks) ...[
        for (final line in block.lines) line.text,
        block.text,
      ],
      recognizedText.text,
    ];

    for (final raw in candidates) {
      final normalized = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (normalized.isEmpty) continue;

      for (final match in _platePattern.allMatches(normalized)) {
        final candidate = match.group(0);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  Future<void> _closeWithPlate(String plate) async {
    if (_closing) return;
    _closing = true;
    await _disposeResources();
    if (mounted) {
      Navigator.of(context).pop(plate);
    }
  }

  Future<void> _disposeResources() async {
    if (_disposed) return;
    _disposed = true;

    if (_streaming) {
      _streaming = false;
      final controller = _controller;
      if (controller != null && controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
    }

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }

    try {
      await _recognizer.close();
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    await _disposeResources();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final previewReady = controller != null && controller.value.isInitialized;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: const Color(0xFF081532),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF1E2B4D)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SizedBox(),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: previewReady
                        ? controller.value.aspectRatio
                        : 1.45,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        color: const Color(0xFF101C38),
                        child: previewReady
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(controller),
                                  Container(
                                    margin: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_initializing)
                                      const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    else
                                      const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _status ?? 'Preparing camera...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFB0BBDD),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _status ?? 'Preparing camera...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB0BBDD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
