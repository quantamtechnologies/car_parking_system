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
  late final TextEditingController _ownerController;
  late final TextEditingController _phoneController;
  String? _vehicleType;
  late Future<List<ParkingSessionSummary>> _recentFuture;
  VehicleRecord? _matchedVehicle;
  int _lookupToken = 0;
  String _lastLookupPlate = '';
  bool _syncingPlateText = false;

  bool _busy = false;
  bool _lookupBusy = false;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(
      text: widget.initialPlate.trim().isNotEmpty
          ? widget.initialPlate.trim().toUpperCase()
          : '',
    );
    _ownerController = TextEditingController();
    _phoneController = TextEditingController();
    _vehicleType = widget.initialVehicleType.trim().isNotEmpty
        ? widget.initialVehicleType
        : null;
    _recentFuture = _loadRecentEntries();
    _plateController.addListener(_handlePlateChanged);

    if (widget.initialPlate.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lookupVehicle(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handlePlateChanged() {
    if (_syncingPlateText) return;

    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      _clearVehicleForm(resetPlateMemory: true, preservePlate: true);
      return;
    }
    if (plate.length < 4) {
      _clearVehicleForm(resetPlateMemory: false, preservePlate: true);
      return;
    }
    if (plate == _lastLookupPlate && _matchedVehicle != null) return;
    unawaited(_lookupVehicle(silent: true));
  }

  Future<List<ParkingSessionSummary>> _loadRecentEntries() async {
    final api = context.read<SmartParkingApi>();
    final sessions = await api.sessions(pageSize: 24, ordering: '-entry_time');
    return sessions
        .where((session) => session.status.toUpperCase() == 'ACTIVE')
        .toList();
  }

  Future<void> _refreshRecent() async {
    setState(() => _recentFuture = _loadRecentEntries());
    await _recentFuture;
  }

  Future<void> _openCamera() async {
    final result = await context.push<Map<String, dynamic>?>(
      '/camera-entry',
      extra: {'source': 'ENTRY', 'plate': _plateController.text},
    );
    if (result == null) return;

    final plate = result['plate']?.toString() ??
        result['confirmed_plate']?.toString() ??
        '';
    if (plate.trim().isEmpty) return;

    setState(() {
      _plateController.text = plate.trim().toUpperCase();
      _plateController.selection =
          TextSelection.collapsed(offset: _plateController.text.length);
    });
    await _lookupVehicle(silent: true);
  }

  Future<void> _lookupVehicle({required bool silent}) async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty || plate.length < 4) return;
    final lookupToken = ++_lookupToken;

    setState(() => _lookupBusy = true);
    try {
      final vehicle =
          await context.read<SmartParkingApi>().vehicleByPlate(plate);
      if (!mounted || lookupToken != _lookupToken) return;
      if (vehicle == null) {
        setState(() {
          _matchedVehicle = null;
          _lastLookupPlate = plate;
          _syncingPlateText = true;
          _plateController.text = plate;
          _plateController.selection =
              TextSelection.collapsed(offset: _plateController.text.length);
          _syncingPlateText = false;
          _ownerController.clear();
          _phoneController.clear();
          _vehicleType = null;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Vehicle not found yet. Fill the form and press ENTER to register it.'),
            ),
          );
        }
        return;
      }

      setState(() {
        _matchedVehicle = vehicle;
        _syncingPlateText = true;
        _plateController.text = vehicle.plateNumber;
        _plateController.selection =
            TextSelection.collapsed(offset: _plateController.text.length);
        _vehicleType = vehicle.vehicleType;
        _ownerController.text = vehicle.ownerName;
        _phoneController.text = vehicle.phoneNumber;
        _lastLookupPlate = vehicle.plateNumber.toUpperCase();
        _syncingPlateText = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle lookup failed: ${apiErrorMessage(e, fallback: 'Please try again in a moment.')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted && lookupToken == _lookupToken) {
        setState(() => _lookupBusy = false);
      }
    }
  }

  Future<void> _handlePlateSubmitted() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;
    await _lookupVehicle(silent: true);
    if (!mounted) return;
    if (_matchedVehicle != null) {
      await _submitEntry();
    }
  }

  void _clearVehicleForm({
    required bool resetPlateMemory,
    required bool preservePlate,
  }) {
    if (!mounted) return;
    setState(() {
      _matchedVehicle = null;
      _ownerController.clear();
      _phoneController.clear();
      _vehicleType = null;
      if (resetPlateMemory) {
        _lastLookupPlate = '';
      } else if (!preservePlate) {
        _lastLookupPlate = _plateController.text.trim().toUpperCase();
      }
    });
  }

  bool get _requiresRegistration => _matchedVehicle == null;

  Future<void> _submitEntry() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;
    if (_lookupBusy) return;

    if (_requiresRegistration) {
      if ((_vehicleType ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select the vehicle type to continue.')),
        );
        return;
      }
      if (_ownerController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter the owner name and phone number before pressing ENTER.',
            ),
          ),
        );
        return;
      }
    }

    final payload = <String, dynamic>{
      'plate_number': plate,
      'vehicle_type': _vehicleType ?? 'CAR',
      'owner_name': _ownerController.text.trim(),
      'phone_number': _phoneController.text.trim(),
    };

    setState(() => _busy = true);
    try {
      final api = context.read<SmartParkingApi>();
      var response = await api.createEntry(payload);
      var registeredNow = false;

      if (response['needs_registration'] == true) {
        registeredNow = true;
        await api.quickRegister(payload);
        response = await api.createEntry(payload);
      }

      if (!mounted) return;

      if (response['needs_registration'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle still needs registration.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requiresRegistration || registeredNow
                ? 'Vehicle registered and parking session started.'
                : 'Parking session started successfully.',
          ),
        ),
      );
      setState(() {
        _matchedVehicle = null;
        _lastLookupPlate = '';
        _vehicleType = null;
        _syncingPlateText = true;
        _plateController.clear();
        _plateController.selection = const TextSelection.collapsed(offset: 0);
        _syncingPlateText = false;
        _ownerController.clear();
        _phoneController.clear();
      });
      await _refreshRecent();
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(
        e,
        fallback: 'Unable to start the session right now.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.toLowerCase().contains('slot')
                ? 'Entry failed: parking space assignment is automatic now. Please try again.'
                : 'Entry failed: $message',
          ),
        ),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('entry', payload);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = DateFormat('d MMM y').format(now);
    final timeLabel = DateFormat('hh:mm a').format(now);
    final existingVehicle = _matchedVehicle != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: ParkingColors.primary,
        onRefresh: _refreshRecent,
        child: FutureBuilder<List<ParkingSessionSummary>>(
          future: _recentFuture,
          builder: (context, snapshot) {
            final recent = (snapshot.data ?? const <ParkingSessionSummary>[])
                .take(4)
                .toList();

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
                        child: const _EntryHeader(),
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
                              _PlateField(
                                controller: _plateController,
                                isBusy: _lookupBusy,
                                onScan: _openCamera,
                                onSearch: () => _lookupVehicle(silent: false),
                                onSubmitted: _handlePlateSubmitted,
                              ),
                              const SizedBox(height: 12),
                              _SelectField(
                                icon: Icons.directions_car_rounded,
                                label: _vehicleType == null
                                    ? ''
                                    : vehicleTypeLabel(_vehicleType!),
                                hint: 'Select vehicle type',
                                enabled: !existingVehicle,
                                onTap: _pickVehicleType,
                              ),
                              const SizedBox(height: 12),
                              _TextFieldShell(
                                controller: _ownerController,
                                hintText: 'Owner name',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                readOnly: existingVehicle,
                              ),
                              const SizedBox(height: 12),
                              _TextFieldShell(
                                controller: _phoneController,
                                hintText: 'Owner phone number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                readOnly: existingVehicle,
                                onSubmitted: (_) => _submitEntry(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: _SectionHeader(title: 'Entry Info'),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE3E9F8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _InfoCell(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'Date',
                                  value: dateLabel,
                                ),
                              ),
                              Container(
                                  width: 1,
                                  height: 68,
                                  color: const Color(0xFFDCE3F3)),
                              Expanded(
                                child: _InfoCell(
                                  icon: Icons.schedule_rounded,
                                  label: 'Time (Auto)',
                                  value: timeLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _PrimaryButton(
                          label: _busy ? 'ENTERING' : 'ENTER',
                          icon: Icons.login_rounded,
                          isBusy: _busy,
                          onPressed: _busy ? null : _submitEntry,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: _SectionHeader(title: 'Entries'),
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
                              if (recent.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                    'No recent entries yet.',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600),
                                  ),
                                )
                              else
                                for (var index = 0;
                                    index < recent.length;
                                    index++) ...[
                                  _RecentEntryRow(
                                    record: recent[index],
                                    onTap: () => context.push(
                                      '/transactions/details',
                                      extra: TransactionRecord(
                                        session: recent[index],
                                      ),
                                    ),
                                  ),
                                  if (index != recent.length - 1)
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
                                  fallback: 'Unable to load recent entries.'),
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

  Future<void> _pickVehicleType() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _VehicleTypePicker(currentValue: _vehicleType ?? 'CAR');
      },
    );

    if (result != null && mounted) {
      setState(() {
        _vehicleType = result;
      });
    }
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final backSize = compact ? 52.0 : 60.0;
        final titleSize = compact ? 20.0 : 24.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
            border: Border.all(color: const Color(0xFFE5EBF5)),
          ),
          child: Row(
            children: [
              Material(
                color: const Color(0xFFEAF1FF),
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
                  'Vehicle Entry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF16233F),
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlateField extends StatelessWidget {
  const _PlateField({
    required this.controller,
    required this.onScan,
    required this.onSearch,
    required this.onSubmitted,
    required this.isBusy,
  });

  final TextEditingController controller;
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final Future<void> Function() onSubmitted;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      prefix: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'P',
          style: TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
        ),
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
                color: Color(0xFF2563EB), size: 20),
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

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      onTap: enabled ? onTap : null,
      prefix: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEAF1FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          size: 28,
        ),
      ),
      suffix: Icon(
        enabled ? Icons.keyboard_arrow_down_rounded : Icons.lock_rounded,
        color: const Color(0xFF8A93A8),
        size: enabled ? 30 : 20,
      ),
      child: Text(
        label.isEmpty ? hint : label,
        style: TextStyle(
          color:
              label.isEmpty ? const Color(0xFF8A93A8) : const Color(0xFF16233F),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TextFieldShell extends StatelessWidget {
  const _TextFieldShell({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

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
        child: Icon(icon, color: const Color(0xFF2563EB), size: 26),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: const TextStyle(
          color: Color(0xFF16233F),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
              color: Color(0xFF8A93A8), fontWeight: FontWeight.w500),
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.prefix,
    required this.child,
    this.suffix,
    this.onTap,
  });

  final Widget prefix;
  final Widget child;
  final Widget? suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = Container(
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

    if (onTap == null) {
      return field;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: field,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF16233F),
                    fontSize: 20,
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
                          fontSize: 22,
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

class _RecentEntryRow extends StatelessWidget {
  const _RecentEntryRow({
    required this.record,
    required this.onTap,
  });

  final ParkingSessionSummary record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = record.entryTime;
    final timeLabel =
        entry == null ? '--:--' : DateFormat('hh:mm a').format(entry);
    final typeLabel = record.displayVehicleType;
    final accent = _vehicleAccent(record.vehicleType);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(_vehicleIcon(record.vehicleType),
                  color: accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.plateNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF16233F),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.ownerDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const StatusBadge(
                  label: 'ACTIVE',
                  color: Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2B5C),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF97A2B8), size: 30),
          ],
        ),
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

class _VehicleTypePicker extends StatelessWidget {
  const _VehicleTypePicker({required this.currentValue});

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
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x250B1630),
                blurRadius: 24,
                offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Vehicle Type',
              style: TextStyle(
                color: Color(0xFF16233F),
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
                    color: option.$1 == currentValue
                        ? const Color(0xFFEAF1FF)
                        : const Color(0xFFF5F7FD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(option.$3, color: const Color(0xFF2563EB), size: 22),
                ),
                title: Text(
                  option.$2,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF16233F)),
                ),
                trailing: option.$1 == currentValue
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
              if (option != options.last)
                const Divider(height: 1, color: Color(0xFFE7EDF7)),
            ],
          ],
        ),
      ),
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

IconData _vehicleIcon(String vehicleType) {
  switch (vehicleType.toUpperCase()) {
    case 'SUV':
    case 'CAR':
      return Icons.directions_car_rounded;
    case 'VAN':
      return Icons.airport_shuttle_rounded;
    case 'TRUCK':
      return Icons.local_shipping_rounded;
    case 'BIKE':
      return Icons.two_wheeler_rounded;
    default:
      return Icons.local_parking_rounded;
  }
}
