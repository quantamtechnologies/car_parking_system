import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_errors.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';
import '../camera/camera_screen.dart';

class ExitScreen extends StatefulWidget {
  const ExitScreen({super.key});

  @override
  State<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends State<ExitScreen> {
  final _plate = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _breakdown;
  String? _scanSummary;
  int? _exitScanId;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _scanPlate() async {
    final result = await context.push<Map<String, dynamic>?>('/camera-exit', extra: {'source': 'EXIT', 'plate': _plate.text});
    if (result == null) return;
    final plate = result['plate']?.toString() ?? '';
    final scan = result['scan'] as OcrResult?;
    setState(() {
      _plate.text = plate;
      _exitScanId = result['scan_id'] as int?;
      _scanSummary = scan == null ? null : '${scan.detectedPlate.isEmpty ? 'Manual' : scan.detectedPlate} (${scan.confidence.toStringAsFixed(0)}%)';
    });
  }

  Future<void> _prepareExit() async {
    if (_plate.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await context.read<SmartParkingApi>().prepareExit({
        'plate_number': _plate.text.trim(),
        if (_exitScanId != null) 'exit_scan_id': _exitScanId,
      });
      setState(() {
        _session = Map<String, dynamic>.from(response['session'] as Map);
        _breakdown = Map<String, dynamic>.from(response['fee_breakdown'] as Map);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exit lookup failed: ${apiErrorMessage(e, fallback: 'Unable to prepare the exit right now.')}')),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('exit', {'plate_number': _plate.text.trim()});
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionHeader(
          title: 'Vehicle exit',
          subtitle: 'Prepare the bill, then move straight to payment confirmation.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: _plate,
                  decoration: InputDecoration(
                    labelText: 'Plate number',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt_rounded),
                      onPressed: _scanPlate,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                if (_scanSummary != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: StatusBadge(label: _scanSummary!, color: const Color(0xFF0F4CFF))),
                ],
                const SizedBox(height: 18),
                GradientActionButton(
                  label: 'Calculate fee',
                  icon: Icons.receipt_long_rounded,
                  isBusy: _loading,
                  onPressed: _loading ? null : _prepareExit,
                ),
              ],
            ),
          ),
        ),
        if (_session != null && _breakdown != null) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text('Plate: ${(_session!['vehicle'] as Map)['plate_number']}'),
                  Text('Slot: ${((_session!['slot'] as Map)['code'])}'),
                  Text('Total fee: ${money(double.tryParse(_session!['total_fee'].toString()) ?? 0)}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      StatusBadge(label: 'Duration ${_breakdown!['duration_minutes']} mins', color: const Color(0xFF0F4CFF)),
                      StatusBadge(label: 'Grace ${_breakdown!['billable_minutes']} billable mins', color: const Color(0xFFF2994A)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GradientActionButton(
                    label: 'Go to payment',
                    icon: Icons.payments_rounded,
                    onPressed: () => context.go('/payment', extra: _session),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
