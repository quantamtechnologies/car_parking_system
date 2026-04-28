import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({
    super.key,
    required this.plateNumber,
    this.initialVehicleType = 'CAR',
  });

  final String plateNumber;
  final String initialVehicleType;

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  late String _vehicleType;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.initialVehicleType.isNotEmpty ? widget.initialVehicleType : 'CAR';
  }

  Future<void> _submit() async {
    if (widget.plateNumber.trim().isEmpty) return;
    setState(() => _busy = true);
    final api = context.read<SmartParkingApi>();
    try {
      await api.quickRegister({
        'plate_number': widget.plateNumber.trim(),
        'vehicle_type': _vehicleType,
      });
      final entry = await api.createEntry({
        'plate_number': widget.plateNumber.trim(),
        'vehicle_type': _vehicleType,
      });
      if (!mounted) return;
      if (entry['needs_registration'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle still needs registration.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle registered and parking entry started.')),
      );
      context.go('/entry', extra: {'plate': widget.plateNumber.trim(), 'vehicle_type': _vehicleType});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: ${apiErrorMessage(e, fallback: 'Please try again in a moment.')}',
          ),
        ),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('vehicle_registration', {
          'plate_number': widget.plateNumber.trim(),
          'vehicle_type': _vehicleType,
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkInk = Color(0xFF16233F);
    const darkMuted = Color(0xFF667085);
    const vehicleItemStyle = TextStyle(
      color: darkInk,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ParkingScreenHeader(
              title: 'Vehicle Registration',
              subtitle: 'Plate not found. Add the vehicle type to continue.',
              user: context.read<AuthController>().user,
              onLeadingTap: () => context.go('/entry'),
              leadingIcon: Icons.arrow_back_rounded,
              dark: true,
              backgroundGradient: ParkingColors.entryHeaderGradient,
              titleColor: Colors.white,
              subtitleColor: Colors.white.withOpacity(0.82),
              leadingBackground: Colors.white.withOpacity(0.14),
              leadingIconColor: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              titleSize: 28,
              subtitleSize: 15,
              bottomRadius: 34,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SurfaceCard(
                    radius: 30,
                    padding: const EdgeInsets.all(18),
                    color: Colors.white,
                    borderColor: const Color(0xFFE8EDF7),
                    shadow: const [
                      BoxShadow(color: Color(0x120B1630), blurRadius: 26, offset: Offset(0, 14)),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                gradient: ParkingColors.primaryGradient,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 40),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Registration',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: darkInk,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Only the vehicle type is required. The plate number is already filled in.',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: darkMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'License Plate Number',
                          style: const TextStyle(
                            color: darkInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE3F4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF006A44), Color(0xFFD71F2A)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text('KE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.plateNumber.trim().isEmpty ? 'Plate Number' : widget.plateNumber.trim(),
                                  style: const TextStyle(
                                    color: darkInk,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Icon(Icons.lock_rounded, color: ParkingColors.primary, size: 24),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Vehicle Type',
                          style: const TextStyle(
                            color: darkInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE3F4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _vehicleType,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7780A3), size: 30),
                              style: vehicleItemStyle,
                              items: const [
                                DropdownMenuItem(value: 'CAR', child: Text('Car', style: vehicleItemStyle)),
                                DropdownMenuItem(value: 'SUV', child: Text('SUV', style: vehicleItemStyle)),
                                DropdownMenuItem(value: 'VAN', child: Text('Van', style: vehicleItemStyle)),
                                DropdownMenuItem(value: 'TRUCK', child: Text('Truck', style: vehicleItemStyle)),
                                DropdownMenuItem(value: 'BIKE', child: Text('Motorbike', style: vehicleItemStyle)),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other', style: vehicleItemStyle)),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _vehicleType = value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: GradientActionButton(
                            label: _busy ? 'Registering' : 'Register Vehicle',
                            icon: Icons.arrow_forward_rounded,
                            isBusy: _busy,
                            onPressed: _busy ? null : _submit,
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
    );
  }
}
