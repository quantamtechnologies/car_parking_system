import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.initialSession});

  final Map<String, dynamic>? initialSession;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _sessionId = TextEditingController();
  final _amountTendered = TextEditingController();
  final _cashShiftId = TextEditingController();
  final _notes = TextEditingController();
  bool _override = false;
  bool _busy = false;
  PaymentReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    if (widget.initialSession != null) {
      _sessionId.text = widget.initialSession!['id'].toString();
      _amountTendered.text = widget.initialSession!['total_fee']?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    _sessionId.dispose();
    _amountTendered.dispose();
    _cashShiftId.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_sessionId.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final receipt = await context.read<SmartParkingApi>().confirmCashPayment({
        'session_id': int.parse(_sessionId.text.trim()),
        'amount_tendered': double.tryParse(_amountTendered.text.trim()) ?? 0,
        if (_cashShiftId.text.trim().isNotEmpty) 'cash_shift_id': int.parse(_cashShiftId.text.trim()),
        'notes': _notes.text.trim(),
        'override': _override,
        'override_reason': _override ? _notes.text.trim() : '',
      });
      setState(() => _receipt = receipt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed. Exit can proceed.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      await context.read<AuthController>().queueIfOffline('payment', {
        'session_id': _sessionId.text.trim(),
        'amount_tendered': _amountTendered.text.trim(),
        'cash_shift_id': _cashShiftId.text.trim(),
        'notes': _notes.text.trim(),
        'override': _override,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.initialSession;
    final fee = session == null ? null : double.tryParse(session['total_fee'].toString()) ?? 0;
    final tendered = double.tryParse(_amountTendered.text.trim()) ?? 0;
    final change = tendered - (fee ?? 0);
    final vehicle = session?['vehicle'] as Map?;
    final auth = context.watch<AuthController>();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionHeader(
          title: 'Cash payment',
          subtitle: 'Confirm the amount, generate a receipt, and release the vehicle.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session != null) ...[
                  Text('Plate: ${vehicle?['plate_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Amount due: ${money(fee ?? 0)}'),
                  const SizedBox(height: 10),
                ],
                TextField(controller: _sessionId, decoration: const InputDecoration(labelText: 'Session ID')),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountTendered,
                  decoration: const InputDecoration(labelText: 'Cash received'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(controller: _cashShiftId, decoration: const InputDecoration(labelText: 'Cash shift ID (optional)'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Reason / notes')),
                const SizedBox(height: 10),
                if (auth.isAdmin)
                  SwitchListTile.adaptive(
                    value: _override,
                    onChanged: (value) => setState(() => _override = value),
                    title: const Text('Admin override'),
                    subtitle: const Text('Allow exit without collecting cash'),
                  ),
                const SizedBox(height: 10),
                GradientActionButton(
                  label: 'Confirm payment',
                  icon: Icons.check_circle_rounded,
                  isBusy: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
              ],
            ),
          ),
        ),
        if (_receipt != null) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text('Receipt number: ${_receipt!.receiptNumber}'),
                  Text('Amount due: ${money(_receipt!.amountDue)}'),
                  Text('Cash received: ${money(_receipt!.amountTendered)}'),
                  Text('Change: ${money(_receipt!.changeDue)}'),
                  Text('Method: ${_receipt!.method}'),
                  Text('Expected change preview: ${money(change < 0 ? 0 : change)}'),
                  const SizedBox(height: 12),
                  GradientActionButton(
                    label: 'Back to dashboard',
                    icon: Icons.dashboard_rounded,
                    onPressed: () => context.go('/'),
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
