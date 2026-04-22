import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.source,
    this.initialPlate = '',
  });

  final String source;
  final String initialPlate;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _plateController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  OcrResult? _scan;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _plateController.text = widget.initialPlate;
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 86);
    if (image == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await image.readAsBytes();
      final result = await context.read<SmartParkingApi>().recognizePlate(image, source: widget.source);
      setState(() {
        _imageBytes = bytes;
        _scan = result;
        _plateController.text = result.detectedPlate.isNotEmpty ? result.detectedPlate : widget.initialPlate;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    Navigator.of(context).pop({
      'plate': _plateController.text.trim(),
      'confirmed_plate': _plateController.text.trim(),
      'scan_id': _scan?.id,
      'scan': _scan,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera-assisted plate capture')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: wide ? 460 : 320,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE4EEFF)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0F0A1F44), blurRadius: 24, offset: Offset(0, 12)),
                            ],
                          ),
                          child: _imageBytes == null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.camera_alt_rounded, size: 72, color: Color(0xFF0F4CFF)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Capture a vehicle plate',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _plateController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Plate number'),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: GradientActionButton(
                                label: _loading ? 'Scanning' : 'Capture',
                                icon: Icons.camera_alt_rounded,
                                isBusy: _loading,
                                onPressed: _loading ? null : _capture,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _plateController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Plate number'),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: GradientActionButton(
                                label: _loading ? 'Scanning' : 'Capture',
                                icon: Icons.camera_alt_rounded,
                                isBusy: _loading,
                                onPressed: _loading ? null : _capture,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (_scan != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'OCR result: ${_scan!.detectedPlate.isEmpty ? 'No plate found' : _scan!.detectedPlate}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final candidate in _scan!.candidatePlates)
                              Chip(label: Text(candidate), backgroundColor: const Color(0xFFEAF3FF)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GradientActionButton(
                          label: 'Use plate',
                          icon: Icons.check_circle_rounded,
                          onPressed: _plateController.text.trim().isEmpty ? null : _confirm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
