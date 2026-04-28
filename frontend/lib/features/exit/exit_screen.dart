import 'dart:async';

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
  final _plateController = TextEditingController();
  late Future<_ExitPageData> _future;
  Timer? _plateLookupDebounce;
  String _lastPreparedPlate = '';
  bool _syncingPlateText = false;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _breakdown;
  int? _scanId;
  bool _busy = false;
  bool _scanBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _plateController.addListener(_handlePlateChanged);
  }

  @override
  void dispose() {
    _plateLookupDebounce?.cancel();
    _plateController.dispose();
    super.dispose();
  }

  void _handlePlateChanged() {
    if (_syncingPlateText) return;

    final plate = _plateController.text.trim().toUpperCase();
    if (plate.length < 4 || plate == _lastPreparedPlate) return;

    _plateLookupDebounce?.cancel();
    _plateLookupDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      final latest = _plateController.text.trim().toUpperCase();
      if (latest.length < 4 || latest == _lastPreparedPlate) return;
      _fetchVehicleInfo(autoTriggered: true);
    });
  }

  Future<_ExitPageData> _load() async {
    final api = context.read<SmartParkingApi>();
    final results = await Future.wait([
      api.vehicles(),
      api.sessions(ordering: '-exit_time', pageSize: 10),
    ]);

    final vehicles = (results[0] as List<VehicleRecord>).toList();
    final sessions = (results[1] as List<ParkingSessionSummary>)
        .where((session) => session.exitTime != null)
        .toList();

    final typeByPlate = <String, String>{};
    for (final vehicle in vehicles) {
      typeByPlate[vehicle.plateNumber.toUpperCase()] = vehicle.vehicleType;
    }

    final recentExits = sessions
        .take(2)
        .map(
          (session) => _RecentExitRowData(
            plateNumber: session.plateNumber,
            vehicleType:
                typeByPlate[session.plateNumber.toUpperCase()] ?? 'CAR',
            timeLabel: DateFormat('hh:mm a').format(session.exitTime!),
          ),
        )
        .toList();

    return _ExitPageData(
      recentExits: recentExits,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _scanPlate() async {
    if (_scanBusy) return;
    setState(() => _scanBusy = true);
    try {
      final result = await context.push<Map<String, dynamic>?>(
        '/camera-exit',
        extra: {'source': 'EXIT', 'plate': _plateController.text},
      );
      if (result == null) return;

      final plate = result['plate']?.toString() ?? '';
      if (plate.trim().isEmpty) return;

      setState(() {
        _syncingPlateText = true;
        _plateController.text = plate.trim().toUpperCase();
        _plateController.selection =
            TextSelection.collapsed(offset: _plateController.text.length);
        _scanId = result['scan_id'] as int?;
        _syncingPlateText = false;
      });
      await _fetchVehicleInfo(autoTriggered: true);
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _fetchVehicleInfo({bool autoTriggered = false}) async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    final payload = <String, dynamic>{
      'plate_number': plate,
      if (_scanId != null) 'exit_scan_id': _scanId,
    };

    setState(() => _busy = true);
    try {
      final response =
          await context.read<SmartParkingApi>().prepareExit(payload);
      if (!mounted) return;

      setState(() {
        _session = Map<String, dynamic>.from(response['session'] as Map);
        _breakdown =
            Map<String, dynamic>.from(response['fee_breakdown'] as Map);
        _lastPreparedPlate = plate;
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
        await context
            .read<AuthController>()
            .queueIfOffline('exit', {'plate_number': plate});
      }
      if (!autoTriggered) {
        setState(() {
          _session = null;
          _breakdown = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _payAndExit() {
    final session = _session;
    if (session == null) {
      _fetchVehicleInfo();
      return;
    }
    context.go('/payment', extra: session);
  }

  String _money0(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'MK ${NumberFormat('#,##0').format(amount)}';
  }

  String _durationLabel(dynamic value) {
    final minutes = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) {
      return '$remaining m';
    }
    if (remaining == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remaining}m';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: RefreshIndicator(
        color: ParkingColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<_ExitPageData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data ?? _ExitPageData(recentExits: const []);
            final vehicle = _session?['vehicle'] as Map?;
            final breakdown = _breakdown;
            final entryTime =
                DateTime.tryParse(_session?['entry_time']?.toString() ?? '');
            final entryClock = entryTime == null
                ? '--:--'
                : DateFormat('hh:mm a').format(entryTime);
            final currentClock = DateFormat('hh:mm a').format(now);
            final duration = breakdown == null
                ? '--'
                : _durationLabel(breakdown['duration_minutes']);
            final rate = breakdown == null
                ? 'MK 0 / hr'
                : '${_money0(breakdown['rate_per_hour'])} / hr';
            final total =
                breakdown == null ? 'MK 0' : _money0(breakdown['total_fee']);
            final plate = vehicle?['plate_number']?.toString() ??
                _plateController.text.trim();
            final rawType = vehicle?['vehicle_type']?.toString() ?? '';
            final type =
                rawType.trim().isEmpty ? '' : vehicleTypeLabel(rawType);
            final owner = vehicle?['owner_name']?.toString() ?? 'Waiting';
            final phone = vehicle?['phone_number']?.toString() ?? 'Waiting';

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 112),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: _ExitHeader(user: user),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SurfaceCard(
                          radius: 26,
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          borderColor: const Color(0xFFE5EBF5),
                          shadow: const [
                            BoxShadow(
                                color: Color(0x150B1630),
                                blurRadius: 20,
                                offset: Offset(0, 12)),
                          ],
                          child: Column(
                            children: [
                              _PlateSearchField(
                                controller: _plateController,
                                isBusy: _scanBusy,
                                onScan: _scanPlate,
                                onSubmitted: () => _fetchVehicleInfo(),
                              ),
                              const SizedBox(height: 14),
                              _PrimaryButton(
                                label:
                                    _busy ? 'FETCHING' : 'FETCH VEHICLE INFO',
                                icon: Icons.search_rounded,
                                isBusy: _busy,
                                onPressed: _busy ? null : _fetchVehicleInfo,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _DetailCard(
                          title: 'Vehicle Info',
                          children: [
                            _ValueRow(
                                label: 'Plate',
                                value: plate.isEmpty ? 'Waiting' : plate),
                            _ValueRow(
                                label: 'Type',
                                value: type.isEmpty ? 'Waiting' : type),
                            _ValueRow(label: 'Owner', value: owner),
                            _ValueRow(label: 'Phone', value: phone),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _DetailCard(
                          title: 'Parking Info',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniInfoCell(
                                      label: 'Entry Time', value: entryClock),
                                ),
                                Container(
                                    width: 1,
                                    height: 52,
                                    color: const Color(0xFFE2E8F4)),
                                Expanded(
                                  child: _MiniInfoCell(
                                      label: 'Current Time',
                                      value: currentClock),
                                ),
                                Container(
                                    width: 1,
                                    height: 52,
                                    color: const Color(0xFFE2E8F4)),
                                Expanded(
                                  child: _MiniInfoCell(
                                      label: 'Duration', value: duration),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _DetailCard(
                          title: 'Charges',
                          children: [
                            _ValueRow(label: 'Rate', value: rate),
                            _ValueRow(label: 'Total', value: total),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _PrimaryButton(
                          label: 'PAY & EXIT',
                          icon: Icons.payments_rounded,
                          onPressed: _busy ? null : _payAndExit,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: _SectionHeader(title: 'Recent Exits'),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SurfaceCard(
                          radius: 24,
                          padding: EdgeInsets.zero,
                          color: Colors.white,
                          borderColor: const Color(0xFFE5EBF5),
                          shadow: const [
                            BoxShadow(
                                color: Color(0x150B1630),
                                blurRadius: 20,
                                offset: Offset(0, 12)),
                          ],
                          child: Column(
                            children: [
                              if (data.recentExits.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                    'No recent exits yet.',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600),
                                  ),
                                )
                              else
                                for (var index = 0;
                                    index < data.recentExits.length;
                                    index++) ...[
                                  _RecentExitRow(data: data.recentExits[index]),
                                  if (index != data.recentExits.length - 1)
                                    const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Color(0xFFE7EDF7)),
                                ],
                            ],
                          ),
                        ),
                      ),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SurfaceCard(
                            radius: 22,
                            padding: const EdgeInsets.all(14),
                            color: Colors.white,
                            borderColor: const Color(0xFFE5EBF5),
                            shadow: const [
                              BoxShadow(
                                  color: Color(0x150B1630),
                                  blurRadius: 16,
                                  offset: Offset(0, 10)),
                            ],
                            child: Text(
                              apiErrorMessage(snapshot.error,
                                  fallback: 'Unable to load recent exits.'),
                              style: const TextStyle(
                                  color: Color(0xFF64748B), height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExitPageData {
  const _ExitPageData({required this.recentExits});

  final List<_RecentExitRowData> recentExits;
}

class _RecentExitRowData {
  const _RecentExitRowData({
    required this.plateNumber,
    required this.vehicleType,
    required this.timeLabel,
  });

  final String plateNumber;
  final String vehicleType;
  final String timeLabel;
}

class _ExitHeader extends StatelessWidget {
  const _ExitHeader({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName
        : 'Current User';
    final role = (user?.displayRole.trim().isNotEmpty ?? false)
        ? user!.displayRole
        : 'Staff';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final backSize = compact ? 52.0 : 60.0;
        final titleSize = compact ? 20.0 : 24.0;
        final avatarSize = compact ? 50.0 : 60.0;
        final nameSize = compact ? 16.0 : 19.0;
        final roleSize = compact ? 12.0 : 13.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A45E1), Color(0xFF1653EE), Color(0xFF0B60E8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go('/'),
                  child: Container(
                    width: backSize,
                    height: backSize,
                    alignment: Alignment.center,
                    child: Icon(Icons.arrow_back_rounded,
                        color: const Color(0xFF2563EB),
                        size: compact ? 26 : 30),
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 18),
              Expanded(
                child: Text(
                  'Vehicle Exit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 18),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 40),
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: compact ? 130 : 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: nameSize,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: roleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlateSearchField extends StatelessWidget {
  const _PlateSearchField({
    required this.controller,
    required this.onScan,
    required this.onSubmitted,
    required this.isBusy,
  });

  final TextEditingController controller;
  final VoidCallback onScan;
  final VoidCallback onSubmitted;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      prefix: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.search_rounded,
            color: Color(0xFF2563EB), size: 28),
      ),
      suffix: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isBusy ? null : onScan,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Color(0xFF2563EB), size: 26),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: Color(0xFF16233F),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter plate number',
          hintStyle:
              TextStyle(color: Color(0xFF8A93A8), fontWeight: FontWeight.w500),
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.prefix,
    required this.child,
    this.suffix,
  });

  final Widget prefix;
  final Widget child;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E1F2)),
      ),
      child: Row(
        children: [
          prefix,
          const SizedBox(width: 12),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F4)),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (suffix != null) ...[
            const SizedBox(width: 12),
            suffix!,
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      borderColor: const Color(0xFFE5EBF5),
      shadow: const [
        BoxShadow(
            color: Color(0x150B1630), blurRadius: 20, offset: Offset(0, 12)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF16233F),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7EDF7)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF16233F),
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoCell extends StatelessWidget {
  const _MiniInfoCell({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF16233F),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6CF6), Color(0xFF184DE1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x262D6CF6), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 68,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: enabled ? onPressed : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isBusy
                ? const SizedBox(
                    key: ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    key: ValueKey(label),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 24),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RecentExitRow extends StatelessWidget {
  const _RecentExitRow({required this.data});

  final _RecentExitRowData data;

  @override
  Widget build(BuildContext context) {
    final accent = _vehicleAccent(data.vehicleType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              data.plateNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF16233F),
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              vehicleTypeLabel(data.vehicleType),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            data.timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF16233F),
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2D6CF6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF16233F),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

Color _vehicleAccent(String vehicleType) {
  switch (vehicleType.toUpperCase()) {
    case 'SUV':
      return const Color(0xFF16A34A);
    case 'VAN':
    case 'TRUCK':
      return const Color(0xFF7C3AED);
    case 'BIKE':
      return const Color(0xFFF97316);
    case 'OTHER':
      return const Color(0xFF64748B);
    case 'CAR':
    default:
      return const Color(0xFF2563EB);
  }
}
