import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ExitScreen extends StatefulWidget {
  const ExitScreen({super.key});

  @override
  State<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends State<ExitScreen> {
  final _plate = TextEditingController();
  late Future<_ExitPageData> _future;
  bool _loading = false;
  bool _expandedVehicles = false;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _breakdown;
  String? _scanSummary;
  int? _exitScanId;
  String? _selectedPlate;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<_ExitPageData> _load() async {
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
        .where((vehicle) => vehicle.isActive && activePlates.contains(vehicle.plateNumber))
        .toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );

    return _ExitPageData(
      vehicles: vehicles,
      activePlates: activePlates,
    );
  }

  Future<void> _scanPlate() async {
    final result = await context.push<Map<String, dynamic>?>(
      '/camera-exit',
      extra: {'source': 'EXIT', 'plate': _plate.text},
    );
    if (result == null) return;

    final plate = result['plate']?.toString() ?? '';
    final scan = result['scan'] as OcrResult?;
    setState(() {
      _plate.text = plate;
      _exitScanId = result['scan_id'] as int?;
      _scanSummary = scan == null
          ? null
          : '${scan.detectedPlate.isEmpty ? 'Manual' : scan.detectedPlate} (${scan.confidence.toStringAsFixed(0)}%)';
      _selectedPlate = plate;
    });
  }

  Future<void> _prepareExit([String? plate]) async {
    final targetPlate = (plate ?? _plate.text).trim();
    if (targetPlate.isEmpty) return;

    setState(() => _loading = true);
    try {
      final response = await context.read<SmartParkingApi>().prepareExit({
        'plate_number': targetPlate,
        if (_exitScanId != null) 'exit_scan_id': _exitScanId,
      });
      setState(() {
        _selectedPlate = targetPlate;
        _session = Map<String, dynamic>.from(response['session'] as Map);
        _breakdown = Map<String, dynamic>.from(response['fee_breakdown'] as Map);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exit lookup failed: ${apiErrorMessage(e, fallback: 'Unable to prepare the exit right now.')}',
          ),
        ),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('exit', {'plate_number': targetPlate});
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(String? raw, {String fallback = 'Now'}) {
    final dt = raw == null ? null : DateTime.tryParse(raw);
    if (dt == null) return fallback;
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours <= 0) return '$remaining min';
    if (remaining <= 0) return '$hours hr';
    return '$hours hr ${remaining} min';
  }

  double _asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  Widget _buildHeader(UserProfile? user) {
    return ParkingScreenHeader(
      title: 'Vehicle Exit',
      subtitle: 'Prepare parked vehicles for departure',
      user: user,
      onLeadingTap: () => context.go('/'),
      leadingIcon: Icons.arrow_back_rounded,
      dark: true,
      backgroundGradient: ParkingColors.entryHeaderGradient,
      titleColor: Colors.white,
      subtitleColor: Colors.white.withOpacity(0.80),
      leadingBackground: Colors.white.withOpacity(0.14),
      leadingIconColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      titleSize: 30,
      subtitleSize: 16,
      bottomRadius: 34,
    );
  }

  Widget _buildLoading(UserProfile? user) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 122),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(user),
          const SizedBox(height: 160),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildError(UserProfile? user, Object? error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 122),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(user),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unable to load exit data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    apiErrorMessage(error, fallback: 'Please try again in a moment.'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(UserProfile? user, _ExitPageData data) {
    final displayVehicles = _expandedVehicles ? data.vehicles : data.vehicles.take(6).toList();
    final currentSession = _session;
    final breakdown = _breakdown;
    final activeVehicleCount = data.activePlates.length;

    final receipt = currentSession == null || breakdown == null
        ? null
        : ReceiptCard(
            entryTime: _formatDateTime(currentSession['entry_time']?.toString(), fallback: 'Unknown'),
            exitTime: DateFormat('HH:mm').format(DateTime.now()),
            durationLabel: _formatDuration((breakdown['duration_minutes'] as num?)?.toInt() ?? 0),
            baseFee: _asDouble(breakdown['base_fee']),
            overdueFee: _asDouble(breakdown['hourly_charge']) +
                _asDouble(breakdown['extra_charges']) +
                _asDouble(breakdown['penalty_amount']),
            totalDue: _asDouble(breakdown['total_fee']),
            overdue: _asDouble(breakdown['hourly_charge']) +
                    _asDouble(breakdown['extra_charges']) +
                    _asDouble(breakdown['penalty_amount']) >
                0,
            note: _asDouble(breakdown['hourly_charge']) +
                        _asDouble(breakdown['extra_charges']) +
                        _asDouble(breakdown['penalty_amount']) >
                    0
                ? 'Overdue charges were added automatically because the stay exceeded the grace period.'
                : 'No overdue fee was added for this exit.',
          );

    final sessionTotal = _asDouble(currentSession?['total_fee']);
    final amountPaid = _asDouble(currentSession?['amount_paid']);
    final paymentStatus = currentSession == null
        ? 'Pending'
        : amountPaid >= sessionTotal && sessionTotal > 0
            ? 'Paid'
            : 'Pending';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 122),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(user),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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
                            subtitle: 'Capture the exit plate or pick a parked vehicle from the list below.',
                            badgeLabel: 'EXIT',
                            actionLabel: 'Open camera',
                            onAction: _scanPlate,
                            icon: Icons.camera_alt_rounded,
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
                                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4A35E8)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Exit plate',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Type the number plate or use the camera and prepare the receipt.',
                                            style: TextStyle(color: Color(0xFF667085), height: 1.35),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _plate,
                                  decoration: InputDecoration(
                                    labelText: 'Number plate',
                                    hintText: 'Enter or scan the plate',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.camera_alt_rounded),
                                      tooltip: 'Open camera scanner',
                                      onPressed: _scanPlate,
                                    ),
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
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
                                    label: _loading ? 'Calculating' : 'Calculate fee',
                                    icon: Icons.receipt_long_rounded,
                                    isBusy: _loading,
                                    onPressed: _loading ? null : _prepareExit,
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
                    if (receipt != null) ...[
                      const SizedBox(height: 18),
                      receipt,
                      const SizedBox(height: 18),
                      PaymentStatusCard(
                        statusLabel: paymentStatus,
                        amountPaid: amountPaid,
                        amountDue: sessionTotal,
                        receiptNumber: currentSession?['receipt_number']?.toString(),
                        method: currentSession?['payment_method']?.toString(),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 220,
                          child: GradientActionButton(
                            label: 'Go to payment',
                            icon: Icons.payments_rounded,
                            onPressed: () => context.go('/payment', extra: currentSession),
                          ),
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
                                      'Active vehicles',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$activeVehicleCount parked vehicles ready for exit',
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
                                  'No parked vehicles are ready for exit.',
                                  style: TextStyle(color: Color(0xFF667085)),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (var index = 0; index < displayVehicles.length; index++) ...[
                                  VehicleRowCard(
                                    vehicleType: displayVehicles[index].displayVehicleType,
                                    ownerName: displayVehicles[index].ownerDisplay,
                                    phoneNumber: displayVehicles[index].phoneDisplay,
                                    plateNumber: displayVehicles[index].plateNumber,
                                    statusLabel: 'Ready to exit',
                                    statusColor: const Color(0xFF22A06B),
                                    selected: _selectedPlate == displayVehicles[index].plateNumber,
                                    onTap: () {
                                      setState(() {
                                        _plate.text = displayVehicles[index].plateNumber;
                                        _selectedPlate = displayVehicles[index].plateNumber;
                                      });
                                      _prepareExit(displayVehicles[index].plateNumber);
                                    },
                                  ),
                                  if (index != displayVehicles.length - 1) const SizedBox(height: 12),
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
          ),
      ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<_ExitPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildLoading(user);
            }
            if (snapshot.hasError) {
              return _buildError(user, snapshot.error);
            }
            return _buildSuccess(user, snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _ExitPageData {
  _ExitPageData({
    required this.vehicles,
    required this.activePlates,
  });

  final List<VehicleRecord> vehicles;
  final Set<String> activePlates;
}
