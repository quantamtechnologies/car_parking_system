import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/widgets.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _plate = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  late Future<_EntryPageData> _future;
  bool _submitting = false;
  bool _expandedVehicles = false;
  bool _quickRegisterVisible = false;
  Map<String, dynamic>? _prefill;
  String _vehicleType = 'CAR';
  String? _scanSummary;
  int? _entryScanId;
  String? _selectedPlate;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _plate.dispose();
    _owner.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<_EntryPageData> _load() async {
    final api = context.read<SmartParkingApi>();
    final results = await Future.wait([
      api.vehicles(),
      api.activeSessions(),
    ]);

    final activePlates = results[1]
        .cast<ParkingSessionSummary>()
        .map((session) => session.plateNumber)
        .where((plate) => plate.isNotEmpty)
        .toSet();

    final vehicles = results[0]
        .cast<VehicleRecord>()
        .where((vehicle) => vehicle.isActive)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    return _EntryPageData(
      vehicles: vehicles,
      activePlates: activePlates,
    );
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
      _selectedPlate = plate;
    });
  }

  void _applyVehicle(VehicleRecord vehicle) {
    setState(() {
      _selectedPlate = vehicle.plateNumber;
      _plate.text = vehicle.plateNumber;
      _vehicleType = vehicle.vehicleType;
      _owner.text = vehicle.ownerName;
      _phone.text = vehicle.phoneNumber;
      _quickRegisterVisible = false;
      _prefill = null;
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
      setState(() {
        _quickRegisterVisible = false;
        _prefill = null;
        _scanSummary = null;
        _entryScanId = null;
        _selectedPlate = null;
        _owner.clear();
        _phone.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entry failed: ${apiErrorMessage(e, fallback: 'Unable to start the session right now.')}')),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('entry', {
          'plate_number': _plate.text.trim(),
          'vehicle_type': _vehicleType,
          'owner_name': _owner.text.trim(),
          'phone_number': _phone.text.trim(),
        });
      }
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

  Widget _buildPlateField() {
    return TextField(
      controller: _plate,
      decoration: InputDecoration(
        labelText: 'Number plate',
        hintText: 'Enter or scan the plate',
        suffixIcon: IconButton(
          icon: const Icon(Icons.camera_alt_rounded),
          onPressed: _scanPlate,
          tooltip: 'Open camera scanner',
        ),
      ),
      textCapitalization: TextCapitalization.characters,
    );
  }

  Widget _buildVehicleTypeField() {
    return DropdownButtonFormField<String>(
      value: _vehicleType,
      decoration: const InputDecoration(labelText: 'Vehicle type'),
      items: const [
        DropdownMenuItem(value: 'CAR', child: Text('Car')),
        DropdownMenuItem(value: 'SUV', child: Text('SUV')),
        DropdownMenuItem(value: 'VAN', child: Text('Van')),
        DropdownMenuItem(value: 'TRUCK', child: Text('Truck')),
        DropdownMenuItem(value: 'BIKE', child: Text('Motorbike')),
        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
      ],
      onChanged: (value) => setState(() => _vehicleType = value ?? 'CAR'),
    );
  }

  Widget _buildOwnerField() {
    return TextField(
      controller: _owner,
      decoration: const InputDecoration(
        labelText: 'Owner name',
        hintText: 'Who is this vehicle registered to?',
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phone,
      decoration: const InputDecoration(
        labelText: 'Phone number',
        hintText: 'Optional contact number',
      ),
      keyboardType: TextInputType.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<_EntryPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unable to load vehicle data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      apiErrorMessage(snapshot.error, fallback: 'Please try again in a moment.'),
                      style: const TextStyle(color: Color(0xFF667085), height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GradientActionButton(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: () => setState(() => _future = _load()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final displayVehicles = _expandedVehicles ? data.vehicles : data.vehicles.take(6).toList();
          final activeVehicleCount = data.vehicles.where((vehicle) => data.activePlates.contains(vehicle.plateNumber)).length;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SurfaceCard(
                      radius: 30,
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1000;
                          final preview = CameraPreviewCard(
                            title: 'Camera preview',
                            subtitle: 'Capture the number plate from a clean split view and keep the workflow focused.',
                            badgeLabel: 'ENTRY',
                            actionLabel: 'Open camera',
                            onAction: _scanPlate,
                          );

                          final form = SurfaceCard(
                            radius: 28,
                            padding: const EdgeInsets.all(18),
                            color: const Color(0xFFF9FBFF),
                            borderColor: const Color(0xFFE5ECF5),
                            shadow: const [
                              BoxShadow(color: Color(0x0D0B1630), blurRadius: 20, offset: Offset(0, 10)),
                            ],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4FF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.edit_document, color: Color(0xFF4A35E8)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Vehicle details',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Keep the fields clean and the entry session moving.',
                                            style: TextStyle(color: Color(0xFF667085), height: 1.35),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildPlateField(),
                                const SizedBox(height: 14),
                                _buildVehicleTypeField(),
                                const SizedBox(height: 14),
                                _buildOwnerField(),
                                const SizedBox(height: 14),
                                _buildPhoneField(),
                                if (_scanSummary != null) ...[
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: StatusBadge(label: _scanSummary!, color: const Color(0xFF4A35E8)),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: GradientActionButton(
                                    label: _submitting ? 'Starting entry' : 'Start entry',
                                    icon: Icons.play_arrow_rounded,
                                    isBusy: _submitting,
                                    onPressed: _submitting ? null : _submitEntry,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: preview),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: form),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              preview,
                              const SizedBox(height: 16),
                              form,
                            ],
                          );
                        },
                      ),
                    ),
                    if (_quickRegisterVisible) ...[
                      const SizedBox(height: 18),
                      SurfaceCard(
                        radius: 28,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDEEEE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFE45858)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Vehicle not registered yet',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Register the plate once, then resume the entry flow.',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF667085)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: GradientActionButton(
                                label: 'Quick register vehicle',
                                icon: Icons.verified_user_rounded,
                                isBusy: _submitting,
                                onPressed: _submitting ? null : _registerMissingVehicle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SurfaceCard(
                      radius: 28,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vehicle list',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${data.vehicles.length} registered vehicles • ${activeVehicleCount} currently parked',
                                      style: const TextStyle(color: Color(0xFF667085), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: data.vehicles.length <= 6
                                    ? null
                                    : () => setState(() => _expandedVehicles = !_expandedVehicles),
                                child: Text(_expandedVehicles ? 'Show less' : 'See more'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (displayVehicles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Center(
                                child: Text(
                                  'No vehicles have been registered yet.',
                                  style: TextStyle(color: Color(0xFF667085)),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (final vehicle in displayVehicles) ...[
                                  VehicleRowCard(
                                    vehicleType: vehicle.displayVehicleType,
                                    ownerName: vehicle.ownerDisplay,
                                    phoneNumber: vehicle.phoneDisplay,
                                    plateNumber: vehicle.plateNumber,
                                    statusLabel: data.activePlates.contains(vehicle.plateNumber) ? 'Parked' : 'Registered',
                                    statusColor: data.activePlates.contains(vehicle.plateNumber)
                                        ? const Color(0xFF22A06B)
                                        : const Color(0xFF4A35E8),
                                    selected: _selectedPlate == vehicle.plateNumber,
                                    onTap: () => _applyVehicle(vehicle),
                                  ),
                                  if (vehicle != displayVehicles.last) const SizedBox(height: 12),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EntryPageData {
  _EntryPageData({
    required this.vehicles,
    required this.activePlates,
  });

  final List<VehicleRecord> vehicles;
  final Set<String> activePlates;
}
