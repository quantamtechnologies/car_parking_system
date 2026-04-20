import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';
import '../camera/camera_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _plate = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  bool _quickRegisterVisible = false;
  Map<String, dynamic>? _prefill;
  String _vehicleType = 'CAR';
  String? _scanSummary;
  int? _entryScanId;

  @override
  void dispose() {
    _plate.dispose();
    _owner.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _scanPlate() async {
    final result = await context.push<Map<String, dynamic>?>('/camera-entry', extra: {'source': 'ENTRY', 'plate': _plate.text});
    if (result == null) return;
    final plate = result['plate']?.toString() ?? '';
    final scan = result['scan'] as OcrResult?;
    setState(() {
      _plate.text = plate;
      _entryScanId = result['scan_id'] as int?;
      _scanSummary = scan == null ? null : '${scan.detectedPlate.isEmpty ? 'Manual' : scan.detectedPlate} (${scan.confidence.toStringAsFixed(0)}%)';
    });
  }

  Future<void> _submitEntry() async {
    if (_plate.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final api = context.read<SmartParkingApi>();
      final response = await api.createEntry({
        'plate_number': _plate.text.trim(),
        'vehicle_type': _vehicleType,
        'owner_name': _owner.text.trim(),
        'phone_number': _phone.text.trim(),
        if (_entryScanId != null) 'entry_scan_id': _entryScanId,
      });

      if (response['needs_registration'] == true) {
        setState(() {
          _quickRegisterVisible = true;
          _prefill = Map<String, dynamic>.from(response['prefill'] as Map);
          _vehicleType = _prefill?['vehicle_type']?.toString() ?? 'CAR';
        });
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry session created successfully.')));
      _quickRegisterVisible = false;
      _prefill = null;
      _scanSummary = null;
      _entryScanId = null;
      _owner.clear();
      _phone.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Entry failed: $e')));
      await context.read<AuthController>().queueIfOffline('entry', {
        'plate_number': _plate.text.trim(),
        'vehicle_type': _vehicleType,
        'owner_name': _owner.text.trim(),
        'phone_number': _phone.text.trim(),
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _registerMissingVehicle() async {
    setState(() => _submitting = true);
    try {
      await context.read<SmartParkingApi>().quickRegister({
        'plate_number': _prefill?['plate_number'] ?? _plate.text.trim(),
        'vehicle_type': _vehicleType,
        'owner_name': _owner.text.trim(),
        'phone_number': _phone.text.trim(),
      });
      setState(() => _quickRegisterVisible = false);
      await _submitEntry();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionHeader(
          title: 'Vehicle entry',
          subtitle: 'Capture the plate, confirm it, and start the parking session in seconds.',
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _vehicleType,
                        decoration: const InputDecoration(labelText: 'Vehicle type'),
                        items: const [
                          DropdownMenuItem(value: 'CAR', child: Text('Car')),
                          DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                          DropdownMenuItem(value: 'VAN', child: Text('Van')),
                          DropdownMenuItem(value: 'TRUCK', child: Text('Truck')),
                          DropdownMenuItem(value: 'BIKE', child: Text('Bike')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (value) => setState(() => _vehicleType = value ?? 'CAR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner name (optional)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)'))),
                  ],
                ),
                if (_scanSummary != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: StatusBadge(label: _scanSummary!, color: const Color(0xFF0F4CFF))),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GradientActionButton(
                        label: 'Start entry',
                        icon: Icons.play_arrow_rounded,
                        isBusy: _submitting,
                        onPressed: _submitting ? null : _submitEntry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.dashboard_rounded),
                        label: const Text('Back to dashboard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_quickRegisterVisible) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vehicle not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Quick-register this vehicle in less than 10 seconds.', style: TextStyle(color: Colors.black.withOpacity(0.65))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner name (optional)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradientActionButton(
                    label: 'Quick register',
                    icon: Icons.person_add_alt_1_rounded,
                    isBusy: _submitting,
                    onPressed: _submitting ? null : _registerMissingVehicle,
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
