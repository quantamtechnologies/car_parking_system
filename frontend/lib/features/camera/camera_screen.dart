import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR failed: ${apiErrorMessage(e, fallback: 'Unable to scan the plate right now.')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    final plate = _plateController.text.trim();
    Navigator.of(context).pop({
      'plate': plate,
      'confirmed_plate': plate,
      'scan_id': _scan?.id,
      'scan': _scan,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final title = widget.source.toUpperCase() == 'EXIT' ? 'Exit Scanner' : 'Entry Scanner';
    final subtitle = 'Capture or type the plate';

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ParkingScreenHeader(
                title: title,
                subtitle: subtitle,
                user: user,
                onLeadingTap: () => Navigator.of(context).pop(),
                leadingIcon: Icons.arrow_back_rounded,
                dark: true,
                backgroundGradient: const LinearGradient(
                  colors: [Color(0xFF081532), Color(0xFF0B1C48), Color(0xFF122B63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                titleColor: Colors.white,
                subtitleColor: const Color(0xFFB0BBDD),
                leadingBackground: const Color(0xFF1B2D5F),
                leadingIconColor: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                titleSize: 24,
                subtitleSize: 13.5,
                bottomRadius: 26,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SurfaceCard(
                      radius: 24,
                      padding: const EdgeInsets.all(14),
                      color: const Color(0xFF0F1B3A),
                      borderColor: const Color(0xFF1E2B4D),
                      shadow: const [
                        BoxShadow(color: Color(0x40050A15), blurRadius: 18, offset: Offset(0, 10)),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.42,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF101C38),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF243559)),
                              ),
                              child: _imageBytes == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF142348),
                                            borderRadius: BorderRadius.circular(22),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Tap scan to capture',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'The manual plate field stays below the scanner.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF9EABC9),
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 520;

                              final plateField = TextField(
                                controller: _plateController,
                                onChanged: (_) => setState(() {}),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Plate number',
                                ),
                                onSubmitted: (_) => _confirm(),
                              );

                              final scanButton = SizedBox(
                                width: stacked ? double.infinity : 150,
                                child: GradientActionButton(
                                  label: _loading ? 'Scanning' : 'Scan plate',
                                  icon: Icons.camera_alt_rounded,
                                  minHeight: 48,
                                  isBusy: _loading,
                                  onPressed: _loading ? null : () {
                                    _capture();
                                  },
                                ),
                              );

                              if (stacked) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    plateField,
                                    const SizedBox(height: 10),
                                    scanButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: plateField),
                                  const SizedBox(width: 10),
                                  scanButton,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_scan != null) ...[
                            Text(
                              'OCR: ${_scan!.detectedPlate.isEmpty ? 'No plate found' : _scan!.detectedPlate}',
                              style: const TextStyle(
                                color: Color(0xFF9EABC9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final candidate in _scan!.candidatePlates)
                                  Chip(
                                    label: Text(candidate),
                                    backgroundColor: const Color(0xFF142348),
                                    labelStyle: const TextStyle(color: Colors.white),
                                    side: const BorderSide(color: Color(0xFF243559)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: GradientActionButton(
                              label: 'Use plate',
                              icon: Icons.check_circle_rounded,
                              minHeight: 48,
                              onPressed: _plateController.text.trim().isEmpty ? null : _confirm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
