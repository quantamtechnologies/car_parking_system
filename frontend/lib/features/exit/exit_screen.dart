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
      subtitle: 'Record vehicle departure',
      user: user,
      onLeadingTap: () => context.go('/'),
      leadingIcon: Icons.arrow_back_rounded,
      dark: true,
      backgroundGradient: const LinearGradient(
        colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      titleColor: Colors.white,
      subtitleColor: const Color(0xFFE4D9FF),
      leadingBackground: Colors.white.withOpacity(0.16),
      leadingIconColor: Colors.white,
      trailingIcon: Icons.qr_code_scanner_rounded,
      trailingOnTap: () {
        _scanPlate();
      },
      trailingBackground: Colors.white.withOpacity(0.16),
      trailingIconColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      titleSize: 26,
      subtitleSize: 13.5,
      bottomRadius: 26,
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
    final currentSession = _session;
    final breakdown = _breakdown;
    final vehicle = currentSession?['vehicle'] as Map?;
    final plate = vehicle?['plate_number']?.toString() ?? _selectedPlate ?? _plate.text.trim();
    final entryAt = DateTime.tryParse(currentSession?['entry_time']?.toString() ?? '');
    final now = DateTime.now();
    final hasSession = currentSession != null && breakdown != null;
    final activeVehicleCount = data.activePlates.length;
    final entryDate = entryAt == null ? 'Waiting' : DateFormat('d MMM y').format(entryAt);
    final entryClock = entryAt == null ? '--:--' : DateFormat('hh:mm a').format(entryAt);
    final exitDate = DateFormat('d MMM y').format(now);
    final exitClock = DateFormat('hh:mm a').format(now);
    final durationLabel = hasSession ? _formatDuration((breakdown!['duration_minutes'] as num?)?.toInt() ?? 0) : '--';
    final double amountDue = hasSession ? _asDouble(breakdown!['total_fee']) : 0.0;
    final actionLabel = hasSession ? 'Continue to Payment' : 'Process Exit';

    Widget buildInfoCard({
      required String title,
      required String subtitle,
      required List<Widget> cells,
    }) {
      return SurfaceCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        color: const Color(0xFF0F1B3A),
        borderColor: const Color(0xFF1E2B4D),
        shadow: const [
          BoxShadow(color: Color(0x40050A15), blurRadius: 24, offset: Offset(0, 12)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF9EABC9),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                if (stacked) {
                  return Column(
                    children: [
                      for (var index = 0; index < cells.length; index++) ...[
                        cells[index],
                        if (index != cells.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var index = 0; index < cells.length; index++) ...[
                      if (index > 0) Container(width: 1, height: 54, color: const Color(0xFF1E2B4D)),
                      Expanded(child: cells[index]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 122),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(user),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1040;
                        final compact = constraints.maxWidth < 760;

                        final plateCard = SurfaceCard(
                          radius: 28,
                          padding: const EdgeInsets.all(18),
                          color: const Color(0xFF0F1B3A),
                          borderColor: const Color(0xFF1E2B4D),
                          shadow: const [
                            BoxShadow(color: Color(0x40050A15), blurRadius: 24, offset: Offset(0, 12)),
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
                                      color: const Color(0xFF1A294C),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF8FB5FF), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Exit Plate Number',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Type the plate or use the scanner to load the exit fee.',
                                          style: TextStyle(
                                            color: Color(0xFF9EABC9),
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 64,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF101C38),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFF243559)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF31446B)),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Column(
                                            children: const [
                                              Expanded(child: ColoredBox(color: Color(0xFF000000))),
                                              Expanded(child: ColoredBox(color: Color(0xFFD71F2A))),
                                              Expanded(child: ColoredBox(color: Color(0xFF006A44))),
                                            ],
                                          ),
                                          Center(
                                            child: Container(
                                              width: 8,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9EABC9), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _plate,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          hintText: 'Enter or scan the plate',
                                          hintStyle: TextStyle(color: Color(0xFF7280A5)),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        textCapitalization: TextCapitalization.characters,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                        onSubmitted: (_) => _prepareExit(),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: _prepareExit,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF142348),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_scanSummary != null) ...[
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusBadge(label: _scanSummary!, color: const Color(0xFF8B5CF6)),
                                ),
                              ],
                            ],
                          ),
                        );

                        final entryInfoCard = buildInfoCard(
                          title: 'Entry Information',
                          subtitle: hasSession
                              ? 'Details captured when the vehicle entered the parking lot.'
                              : 'Scan a plate to load the entry details.',
                          cells: [
                            _InfoCell(
                              icon: Icons.calendar_month_rounded,
                              label: 'Entry Date',
                              value: entryDate,
                            ),
                            _InfoCell(
                              icon: Icons.schedule_rounded,
                              label: 'Entry Time',
                              value: entryClock,
                            ),
                            _InfoCell(
                              icon: Icons.receipt_long_rounded,
                              label: 'Plate',
                              value: plate.isEmpty ? 'Waiting' : plate,
                            ),
                          ],
                        );

                        final exitInfoCard = buildInfoCard(
                          title: 'Exit Information',
                          subtitle: hasSession
                              ? 'Review the exit snapshot before moving to payment.'
                              : 'Exit date, time, and fee will appear here once processed.',
                          cells: [
                            _InfoCell(
                              icon: Icons.event_available_rounded,
                              label: 'Exit Date',
                              value: exitDate,
                            ),
                            _InfoCell(
                              icon: Icons.schedule_rounded,
                              label: 'Exit Time',
                              value: exitClock,
                            ),
                            _InfoCell(
                              icon: Icons.payments_rounded,
                              label: 'Amount Due',
                              value: hasSession ? money(amountDue) : 'Pending',
                            ),
                          ],
                        );

                        final inactiveNote = !hasSession
                            ? SurfaceCard(
                                radius: 22,
                                padding: const EdgeInsets.all(14),
                                color: const Color(0xFF101C38),
                                borderColor: const Color(0xFF1E2B4D),
                                shadow: const [
                                  BoxShadow(color: Color(0x40050A15), blurRadius: 18, offset: Offset(0, 10)),
                                ],
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF142348),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$activeVehicleCount vehicles are currently active. Scan a plate to load the exit fee.',
                                        style: const TextStyle(
                                          color: Color(0xFF9EABC9),
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink();

                        final actionButton = SizedBox(
                          width: double.infinity,
                          child: GradientActionButton(
                            label: actionLabel,
                            icon: hasSession ? Icons.payments_rounded : Icons.arrow_forward_rounded,
                            minHeight: 48,
                            isBusy: _loading,
                            onPressed: _loading
                                ? null
                                : () {
                                    if (hasSession) {
                                      context.go('/payment', extra: currentSession);
                                    } else {
                                      _prepareExit();
                                    }
                                  },
                          ),
                        );

                        if (wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: plateCard),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        entryInfoCard,
                                        const SizedBox(height: 16),
                                        exitInfoCard,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!hasSession) ...[
                                const SizedBox(height: 16),
                                inactiveNote,
                              ],
                              const SizedBox(height: 16),
                              actionButton,
                            ],
                          );
                        }

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              plateCard,
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: entryInfoCard),
                                  const SizedBox(width: 10),
                                  Expanded(child: exitInfoCard),
                                ],
                              ),
                              if (!hasSession) ...[
                                const SizedBox(height: 10),
                                inactiveNote,
                              ],
                              const SizedBox(height: 10),
                              actionButton,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: plateCard),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      entryInfoCard,
                                      const SizedBox(height: 10),
                                      exitInfoCard,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!hasSession) ...[
                              const SizedBox(height: 10),
                              inactiveNote,
                            ],
                            const SizedBox(height: 10),
                            actionButton,
                          ],
                        );
                      },
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

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textAlign = MediaQuery.of(context).size.width < 720 ? TextAlign.left : TextAlign.left;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7B8AB1), size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  textAlign: textAlign,
                  style: const TextStyle(
                    color: Color(0xFF9EABC9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  textAlign: textAlign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
