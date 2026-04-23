import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
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
    final sessionId = int.tryParse(_sessionId.text.trim());
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid session ID.')));
      return;
    }
    final cashShiftText = _cashShiftId.text.trim();
    final cashShiftId = cashShiftText.isEmpty ? null : int.tryParse(cashShiftText);
    if (cashShiftText.isNotEmpty && cashShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid cash shift ID.')));
      return;
    }

    setState(() => _busy = true);
    try {
      final receipt = await context.read<SmartParkingApi>().confirmCashPayment({
        'session_id': sessionId,
        'amount_tendered': double.tryParse(_amountTendered.text.trim()) ?? 0,
        if (cashShiftId != null) 'cash_shift_id': cashShiftId,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${apiErrorMessage(e, fallback: 'Unable to confirm payment right now.')}')),
      );
      if (isOfflineDioError(e)) {
        await context.read<AuthController>().queueIfOffline('payment', {
          'session_id': sessionId,
          'amount_tendered': _amountTendered.text.trim(),
          if (cashShiftId != null) 'cash_shift_id': cashShiftId,
          'notes': _notes.text.trim(),
          'override': _override,
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildFieldCard({required Widget child}) {
    return SurfaceCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      color: const Color(0xFFF9FBFF),
      borderColor: const Color(0xFFE5ECF5),
      shadow: const [
        BoxShadow(color: Color(0x0D0B1630), blurRadius: 20, offset: Offset(0, 10)),
      ],
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.initialSession;
    final fee = session == null ? null : double.tryParse(session['total_fee'].toString()) ?? 0;
    final tendered = double.tryParse(_amountTendered.text.trim()) ?? 0;
    final change = tendered - (fee ?? 0);
    final vehicle = session?['vehicle'] as Map?;
    final paidAmount = _receipt?.amountTendered ?? 0;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final summary = PaymentStatusCard(
              statusLabel: _receipt == null ? 'Pending' : 'Paid',
              amountPaid: paidAmount,
              amountDue: fee ?? 0,
              receiptNumber: _receipt?.receiptNumber,
              method: _receipt?.method,
            );

            final summaryCard = _buildFieldCard(
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
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF4A35E8)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment overview',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'A simple snapshot of the session before the cash is closed.',
                              style: TextStyle(color: Color(0xFF667085), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  summary,
                  const SizedBox(height: 14),
                  if (session != null) ...[
                    _InfoRow(label: 'Session ID', value: session['id'].toString()),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Plate', value: vehicle?['plate_number']?.toString() ?? ''),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Amount due', value: money(fee ?? 0)),
                  ] else
                    const Text(
                      'Enter the session ID manually if the vehicle was not passed from the exit page.',
                      style: TextStyle(color: Color(0xFF667085), height: 1.4),
                    ),
                ],
              ),
            );

            final formCard = _buildFieldCard(
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
                              'Cash payment',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Keep the form concise and use the override only when necessary.',
                              style: TextStyle(color: Color(0xFF667085), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _sessionId,
                    decoration: const InputDecoration(labelText: 'Session ID'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountTendered,
                    decoration: const InputDecoration(labelText: 'Cash received'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cashShiftId,
                    decoration: const InputDecoration(labelText: 'Cash shift ID (optional)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Reason / notes'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  if (context.watch<AuthController>().isAdmin)
                    SwitchListTile.adaptive(
                      value: _override,
                      onChanged: (value) => setState(() => _override = value),
                      title: const Text('Admin override'),
                      subtitle: const Text('Allow exit without collecting cash'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GradientActionButton(
                      label: _busy ? 'Confirming payment' : 'Confirm payment',
                      icon: Icons.check_circle_rounded,
                      isBusy: _busy,
                      onPressed: _busy ? null : _confirm,
                    ),
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summaryCard),
                  const SizedBox(width: 16),
                  Expanded(child: formCard),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summaryCard,
                const SizedBox(height: 16),
                formCard,
              ],
            );
          },
        ),
        if (_receipt != null) ...[
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
                          const Text('Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Receipt ${_receipt!.receiptNumber}',
                            style: const TextStyle(color: Color(0xFF667085), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Amount due', value: money(_receipt!.amountDue)),
                const SizedBox(height: 10),
                _InfoRow(label: 'Cash received', value: money(_receipt!.amountTendered)),
                const SizedBox(height: 10),
                _InfoRow(label: 'Change due', value: money(_receipt!.changeDue)),
                const SizedBox(height: 10),
                _InfoRow(label: 'Method', value: _receipt!.method),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Status',
                  value: (_receipt!.status == 'CONFIRMED' || _receipt!.status == 'OVERRIDDEN') ? 'Paid' : 'Pending',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GradientActionButton(
                    label: 'Back to dashboard',
                    icon: Icons.dashboard_rounded,
                    onPressed: () => context.go('/'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
