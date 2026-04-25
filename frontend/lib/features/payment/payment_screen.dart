import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/theme.dart';
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

  Widget _buildDarkCard({required Widget child}) {
    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF0F1B3A),
      borderColor: const Color(0xFF1E2B4D),
      shadow: const [
        BoxShadow(color: Color(0x40050A15), blurRadius: 18, offset: Offset(0, 10)),
      ],
      child: child,
    );
  }

  Widget _buildHeader(UserProfile? user) {
    return ParkingScreenHeader(
      title: 'Payment',
      subtitle: 'Cash-only exit payments',
      user: user,
      onLeadingTap: () => context.go('/'),
      leadingIcon: Icons.arrow_back_rounded,
      dark: true,
      backgroundGradient: ParkingColors.entryHeaderGradient,
      titleColor: Colors.white,
      subtitleColor: Colors.white.withOpacity(0.80),
      leadingBackground: const Color(0xFF1B2D5F),
      leadingIconColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      titleSize: 26,
      subtitleSize: 13.5,
      bottomRadius: 26,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final session = widget.initialSession;
    final fee = session == null ? null : double.tryParse(session['total_fee'].toString()) ?? 0;
    final vehicle = session?['vehicle'] as Map?;
    final paidAmount = _receipt?.amountTendered ?? 0;
    final admin = context.watch<AuthController>().isAdmin;

    final summaryCard = PaymentStatusCard(
      statusLabel: _receipt == null ? 'Pending' : 'Paid',
      amountPaid: paidAmount,
      amountDue: fee ?? 0,
      receiptNumber: _receipt?.receiptNumber,
      method: _receipt?.method,
    );

    final sessionSnapshotCard = _buildDarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF142348),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.payments_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session snapshot',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'The exit screen should hand this session over automatically.',
                      style: TextStyle(color: Color(0xFF9EABC9), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session != null) ...[
            _InfoRow(label: 'Session ID', value: session['id'].toString()),
            const SizedBox(height: 8),
            _InfoRow(label: 'Plate', value: vehicle?['plate_number']?.toString() ?? ''),
            const SizedBox(height: 8),
            _InfoRow(label: 'Amount due', value: money(fee ?? 0)),
          ] else
            const Text(
              'If the session did not arrive from exit, type the session ID below to continue.',
              style: TextStyle(color: Color(0xFF9EABC9), height: 1.35),
            ),
        ],
      ),
    );

    final formCard = _buildDarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF142348),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash payment',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cash only. Confirm the amount, then close the session.',
                      style: TextStyle(color: Color(0xFF9EABC9), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session == null) ...[
            TextField(
              controller: _sessionId,
              decoration: const InputDecoration(labelText: 'Session ID'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
          ] else ...[
            StatusBadge(label: 'Session locked', color: const Color(0xFF10B981)),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _amountTendered,
            decoration: const InputDecoration(labelText: 'Cash received'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cashShiftId,
            decoration: const InputDecoration(labelText: 'Cash shift ID (optional)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Reason / notes'),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          if (admin)
            SwitchListTile.adaptive(
              value: _override,
              onChanged: (value) => setState(() => _override = value),
              title: const Text('Admin override'),
              subtitle: const Text('Allow exit without collecting cash'),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: GradientActionButton(
              label: _busy ? 'Confirming payment' : 'Confirm payment',
              icon: Icons.check_circle_rounded,
              minHeight: 48,
              isBusy: _busy,
              onPressed: _busy ? null : () {
                _confirm();
              },
            ),
          ),
        ],
      ),
    );

    final receiptCard = _receipt == null
        ? const SizedBox.shrink()
        : _buildDarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF142348),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Receipt ${_receipt!.receiptNumber}',
                            style: const TextStyle(color: Color(0xFF9EABC9), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Amount due', value: money(_receipt!.amountDue)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Cash received', value: money(_receipt!.amountTendered)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Change due', value: money(_receipt!.changeDue)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Method', value: _receipt!.method),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Status',
                  value: (_receipt!.status == 'CONFIRMED' || _receipt!.status == 'OVERRIDDEN') ? 'Paid' : 'Pending',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GradientActionButton(
                    label: 'Back to dashboard',
                    icon: Icons.dashboard_rounded,
                    minHeight: 48,
                    onPressed: () => context.go('/'),
                  ),
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 112),
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
                    summaryCard,
                    const SizedBox(height: 12),
                    sessionSnapshotCard,
                    const SizedBox(height: 12),
                    formCard,
                  ],
                ),
              ),
            ),
          ),
          if (_receipt != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: receiptCard,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF9EABC9), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
