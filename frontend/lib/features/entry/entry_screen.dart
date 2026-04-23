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
  String _assignedSlot = 'B2 - 24';
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
              subtitleColor: Colors.white.withOpacity(0.80),
              leadingBackground: Colors.white.withOpacity(0.14),
              leadingIconColor: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              titleSize: 30,
              subtitleSize: 16,
              bottomRadius: 34,
            ),
            Container(
              decoration: const BoxDecoration(
                color: ParkingColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dense = constraints.maxWidth >= 980;
                        final stackSelectors = constraints.maxWidth < 720;

                        final cameraCard = CameraPreviewCard(
                          title: 'Capture License Plate',
                          subtitle: 'Position the license plate within the frame',
                          badgeLabel: 'ENTRY',
                          actionLabel: 'Switch Camera',
                          onAction: _openCamera,
                          icon: Icons.photo_camera_rounded,
                        );

                        final plateCard = SurfaceCard(
                          radius: 28,
                          padding: const EdgeInsets.all(18),
                          color: Colors.white,
                          borderColor: const Color(0xFFE8EDF7),
                          shadow: const [
                            BoxShadow(color: Color(0x100B1630), blurRadius: 22, offset: Offset(0, 12)),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'License Plate Number',
                                style: TextStyle(
                                  color: ParkingColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 72,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFDDE4F2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFD9E2F0)),
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
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF8A93B4),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _plateController,
                                        textCapitalization: TextCapitalization.characters,
                                        style: const TextStyle(
                                          color: ParkingColors.ink,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) => _lookupVehicle(redirectToRegistration: true),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _openCamera,
                                      icon: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: ParkingColors.primary,
                                        size: 28,
                                      ),
                                      tooltip: 'Scan plate',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                        final vehicleCard = SurfaceCard(
                          radius: 26,
                          padding: const EdgeInsets.all(18),
                          color: const Color(0xFFE9EEFF),
                          borderColor: Colors.transparent,
                          shadow: const [
                            BoxShadow(color: Color(0x0F0B1630), blurRadius: 18, offset: Offset(0, 10)),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDDE5FF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(Icons.directions_car_rounded, color: ParkingColors.primary, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Vehicle Type',
                                          style: TextStyle(
                                            color: ParkingColors.ink,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Select type',
                                          style: TextStyle(
                                            color: Color(0xFF6C7592),
                                            fontSize: 13.5,
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
                                trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7980A3), size: 30),
                              ),
                            ],
                          ),
                        );

                        final slotCard = SurfaceCard(
                          radius: 26,
                          padding: const EdgeInsets.all(18),
                          color: const Color(0xFFF5EEFF),
                          borderColor: Colors.transparent,
                          shadow: const [
                            BoxShadow(color: Color(0x0F0B1630), blurRadius: 18, offset: Offset(0, 10)),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE4D8FF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'P',
                                        style: TextStyle(
                                          color: Color(0xFF5F36F4),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Assign Slot',
                                          style: TextStyle(
                                            color: ParkingColors.ink,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Auto assign slot',
                                          style: TextStyle(
                                            color: Color(0xFF6C7592),
                                            fontSize: 13.5,
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
                                value: _assignedSlot,
                                onTap: () {},
                                textColor: const Color(0xFF5F36F4),
                                trailing: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF5F36F4), size: 28),
                              ),
                            ],
                          ),
                        );

                        final infoCard = SurfaceCard(
                          radius: 28,
                          padding: const EdgeInsets.all(18),
                          color: const Color(0xFFF6F3FF),
                          borderColor: Colors.transparent,
                          shadow: const [
                            BoxShadow(color: Color(0x0F0B1630), blurRadius: 18, offset: Offset(0, 10)),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Entry Information',
                                style: TextStyle(
                                  color: ParkingColors.ink,
                                  fontSize: 17,
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
                                      Container(width: 1, height: 54, color: const Color(0xFFD8DAE9)),
                                      Expanded(child: cells[1]),
                                      Container(width: 1, height: 54, color: const Color(0xFFD8DAE9)),
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
                            icon: Icons.open_in_new_rounded,
                            isBusy: _busy,
                            onPressed: _busy ? null : _startSession,
                          ),
                        );

                        if (!dense) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              cameraCard,
                              const SizedBox(height: 18),
                              plateCard,
                              const SizedBox(height: 18),
                              if (stackSelectors)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    vehicleCard,
                                    const SizedBox(height: 18),
                                    slotCard,
                                  ],
                                )
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: vehicleCard),
                                    const SizedBox(width: 18),
                                    Expanded(child: slotCard),
                                  ],
                                ),
                              const SizedBox(height: 18),
                              infoCard,
                              const SizedBox(height: 18),
                              startButton,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: cameraCard),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  plateCard,
                                  const SizedBox(height: 18),
                                  if (stackSelectors)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        vehicleCard,
                                        const SizedBox(height: 18),
                                        slotCard,
                                      ],
                                    )
                                  else
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: vehicleCard),
                                        const SizedBox(width: 18),
                                        Expanded(child: slotCard),
                                      ],
                                    ),
                                  const SizedBox(height: 18),
                                  infoCard,
                                  const SizedBox(height: 18),
                                  startButton,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE4F2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
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
          Icon(icon, color: const Color(0xFF5A628A), size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  textAlign: textAlign,
                  style: const TextStyle(
                    color: Color(0xFF586086),
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
                    color: ParkingColors.ink,
                    fontSize: 17,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x260B1630), blurRadius: 26, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Vehicle Type',
              style: TextStyle(
                color: ParkingColors.ink,
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
                    color: option.$1 == currentValue ? const Color(0xFFEAF0FF) : const Color(0xFFF3F5FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(option.$3, color: ParkingColors.primary, size: 22),
                ),
                title: Text(
                  option.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: ParkingColors.ink),
                ),
                trailing: option.$1 == currentValue
                    ? const Icon(Icons.check_circle_rounded, color: ParkingColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
              if (option != options.last) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
