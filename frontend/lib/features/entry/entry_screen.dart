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

class EntryScreen extends StatefulWidget {
  const EntryScreen({
    super.key,
    this.initialPlate = '',
    this.initialVehicleType = 'CAR',
  });

  final String initialPlate;
  final String initialVehicleType;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _plateController;
  late String _vehicleType;
  VehicleRecord? _resolvedVehicle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(
      text: widget.initialPlate.isNotEmpty ? widget.initialPlate : 'KCD 123A',
    );
    _vehicleType = widget.initialVehicleType.isNotEmpty ? widget.initialVehicleType : 'CAR';
    if (widget.initialPlate.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lookupVehicle(redirectToRegistration: true);
      });
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final result = await context.push<Map<String, dynamic>?>(
      '/camera-entry',
      extra: {'source': 'ENTRY', 'plate': _plateController.text},
    );
    if (result == null) return;

    final plate = result['plate']?.toString() ?? result['confirmed_plate']?.toString() ?? '';
    if (plate.trim().isEmpty) return;

    setState(() {
      _plateController.text = plate.trim();
    });
    await _lookupVehicle(redirectToRegistration: true);
  }

  Future<void> _lookupVehicle({required bool redirectToRegistration}) async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return;

    final api = context.read<SmartParkingApi>();
    try {
      final vehicle = await api.vehicleByPlate(plate);
      if (!mounted) return;
      if (vehicle == null) {
        setState(() => _resolvedVehicle = null);
        if (redirectToRegistration) {
          context.go(
            '/entry/register',
            extra: {
              'plate': plate,
              'vehicle_type': _vehicleType,
            },
          );
        }
        return;
      }

      setState(() {
        _resolvedVehicle = vehicle;
        _vehicleType = vehicle.vehicleType;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vehicle lookup failed: ${apiErrorMessage(e, fallback: 'Please try again in a moment.')}',
          ),
        ),
      );
    }
  }

  Future<void> _startSession() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return;

    setState(() => _busy = true);
    try {
      if (_resolvedVehicle == null) {
        final lookup = await context.read<SmartParkingApi>().vehicleByPlate(plate);
        if (lookup == null) {
          if (!mounted) return;
          context.go(
            '/entry/register',
            extra: {
              'plate': plate,
              'vehicle_type': _vehicleType,
            },
          );
          return;
        }
        _resolvedVehicle = lookup;
        _vehicleType = lookup.vehicleType;
      }

      final response = await context.read<SmartParkingApi>().createEntry({
        'plate_number': plate,
        'vehicle_type': _vehicleType,
      });

      if (!mounted) return;

      if (response['needs_registration'] == true) {
        context.go(
          '/entry/register',
          extra: {
            'plate': plate,
            'vehicle_type': _vehicleType,
          },
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking session started successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entry failed: ${apiErrorMessage(e, fallback: 'Unable to start the session right now.')}',
          ),
        ),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('entry', {
          'plate_number': plate,
          'vehicle_type': _vehicleType,
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final now = DateTime.now();
    final dateLabel = DateFormat('d MMM y').format(now);
    final timeLabel = DateFormat('hh:mm a').format(now);
    final recordedBy = user?.displayName ?? 'Joel Ndege';

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 122),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ParkingScreenHeader(
              title: 'Vehicle Entry',
              subtitle: 'Record new vehicle entry',
              user: user,
              onLeadingTap: () => context.go('/'),
              leadingIcon: Icons.arrow_back_rounded,
              dark: true,
              backgroundGradient: ParkingColors.entryHeaderGradient,
              titleColor: Colors.white,
              subtitleColor: const Color(0xFFE4E8FF),
              leadingBackground: Colors.white.withOpacity(0.16),
              leadingIconColor: Colors.white,
              trailingIcon: Icons.qr_code_scanner_rounded,
              trailingOnTap: _openCamera,
              trailingBackground: Colors.white.withOpacity(0.16),
              trailingIconColor: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              titleSize: 28,
              subtitleSize: 15,
              bottomRadius: 30,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1040;
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
                                  child: const Icon(Icons.local_parking_rounded, color: Color(0xFF7FB2FF), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'License Plate Number',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Type the plate or use the small scanner button to capture it.',
                                        style: TextStyle(
                                          color: Color(0xFF9EABC9),
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _openCamera,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF132246),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF243559)),
                                      ),
                                      child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                                    ),
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
                                      controller: _plateController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (_) => _lookupVehicle(redirectToRegistration: true),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _lookupVehicle(redirectToRegistration: true),
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
                          ],
                        ),
                      );

                      final vehicleCard = SurfaceCard(
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
                                  child: const Icon(Icons.directions_car_rounded, color: Color(0xFF7FB2FF), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vehicle Type',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Select type',
                                        style: TextStyle(
                                          color: Color(0xFF9EABC9),
                                          fontSize: 12.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _SelectionField(
                              value: vehicleTypeLabel(_vehicleType),
                              onTap: () async {
                                final result = await showModalBottomSheet<String>(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return _TypePicker(
                                      currentValue: _vehicleType,
                                    );
                                  },
                                );
                                if (result != null && mounted) {
                                  setState(() => _vehicleType = result);
                                }
                              },
                              trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9EABC9), size: 28),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      );

                      final infoCard = SurfaceCard(
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
                            const Text(
                              'Entry Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 720;
                                final cells = [
                                  _InfoCell(
                                    icon: Icons.calendar_month_rounded,
                                    label: 'Entry Date',
                                    value: dateLabel,
                                  ),
                                  _InfoCell(
                                    icon: Icons.schedule_rounded,
                                    label: 'Entry Time',
                                    value: timeLabel,
                                  ),
                                  _InfoCell(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Recorded By',
                                    value: recordedBy,
                                  ),
                                ];

                                if (stacked) {
                                  return Column(
                                    children: [
                                      for (var i = 0; i < cells.length; i++) ...[
                                        cells[i],
                                        if (i != cells.length - 1) const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: cells[0]),
                                    Container(width: 1, height: 54, color: const Color(0xFF1E2B4D)),
                                    Expanded(child: cells[1]),
                                    Container(width: 1, height: 54, color: const Color(0xFF1E2B4D)),
                                    Expanded(child: cells[2]),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );

                      final startButton = SizedBox(
                        width: double.infinity,
                        child: GradientActionButton(
                          label: _busy ? 'Starting Parking Session' : 'Start Parking Session',
                          icon: Icons.arrow_forward_rounded,
                          isBusy: _busy,
                          onPressed: _busy ? null : _startSession,
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
                                Expanded(flex: 4, child: vehicleCard),
                              ],
                            ),
                            const SizedBox(height: 16),
                            infoCard,
                            const SizedBox(height: 16),
                            startButton,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          plateCard,
                          const SizedBox(height: 16),
                          vehicleCard,
                          const SizedBox(height: 16),
                          infoCard,
                          const SizedBox(height: 16),
                          startButton,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.value,
    required this.onTap,
    this.trailing,
    this.textColor = ParkingColors.ink,
  });

  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF101C38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF243559)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
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

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.currentValue,
  });

  final String currentValue;

  @override
  Widget build(BuildContext context) {
    final options = const [
      ('CAR', 'Car', Icons.directions_car_rounded),
      ('SUV', 'SUV', Icons.sports_motorsports_rounded),
      ('VAN', 'Van', Icons.airport_shuttle_rounded),
      ('TRUCK', 'Truck', Icons.local_shipping_rounded),
      ('BIKE', 'Motorbike', Icons.two_wheeler_rounded),
      ('OTHER', 'Other', Icons.more_horiz_rounded),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B3A),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x40050A15), blurRadius: 26, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Vehicle Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: option.$1 == currentValue ? const Color(0xFF142348) : const Color(0xFF101C38),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(option.$3, color: Colors.white, size: 22),
                ),
                title: Text(
                  option.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                trailing: option.$1 == currentValue
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7FB2FF))
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
              if (option != options.last) const Divider(height: 1, color: Color(0xFF1E2B4D)),
            ],
          ],
        ),
      ),
    );
  }
}
