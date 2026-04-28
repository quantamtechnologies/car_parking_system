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

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.initialPayload});

  final Map<String, dynamic>? initialPayload;

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
  PaymentRecord? _payment;

  @override
  void initState() {
    super.initState();
    final session = _initialSession;
    if (session != null) {
      _sessionId.text = session['id'].toString();
      _amountTendered.text = session['total_fee']?.toString() ?? '0';
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

  Map<String, dynamic>? get _initialSession {
    final payload = widget.initialPayload;
    if (payload == null) return null;
    final session = payload['session'];
    if (session is Map) {
      return Map<String, dynamic>.from(session);
    }
    return payload;
  }

  Map<String, dynamic>? get _initialBreakdown {
    final payload = widget.initialPayload;
    final breakdown = payload?['fee_breakdown'];
    if (breakdown is Map) {
      return Map<String, dynamic>.from(breakdown);
    }
    return null;
  }

  Future<void> _confirm() async {
    if (_sessionId.text.trim().isEmpty) return;
    final sessionId = int.tryParse(_sessionId.text.trim());
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid session ID.')));
      return;
    }

    final cashShiftText = _cashShiftId.text.trim();
    final cashShiftId =
        cashShiftText.isEmpty ? null : int.tryParse(cashShiftText);
    if (cashShiftText.isNotEmpty && cashShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid cash shift ID.')));
      return;
    }

    setState(() => _busy = true);
    try {
      final payment = await context.read<SmartParkingApi>().confirmCashPayment({
        'session_id': sessionId,
        'amount_tendered': double.tryParse(_amountTendered.text.trim()) ?? 0,
        if (cashShiftId != null) 'cash_shift_id': cashShiftId,
        'notes': _notes.text.trim(),
        'override': _override,
        'override_reason': _override ? _notes.text.trim() : '',
      });
      setState(() => _payment = payment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Payment confirmed, session closed, and receipt generated.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Payment failed: ${apiErrorMessage(e, fallback: 'Unable to confirm payment right now.')}')),
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

  Widget _buildCard({required Widget child}) {
    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      borderColor: const Color(0xFFE5EBF5),
      shadow: const [
        BoxShadow(
            color: Color(0x14050A15), blurRadius: 18, offset: Offset(0, 10)),
      ],
      child: child,
    );
  }

  Widget _buildHeader() {
    return ParkingScreenHeader(
      title: 'Payment',
      subtitle: '',
      user: null,
      onLeadingTap: () => context.go('/'),
      leadingIcon: Icons.arrow_back_rounded,
      backgroundColor: Colors.white,
      titleColor: const Color(0xFF16233F),
      leadingBackground: const Color(0xFFEAF1FF),
      leadingIconColor: ParkingColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      titleSize: 26,
      subtitleSize: 13.5,
      bottomRadius: 26,
    );
  }

  TransactionRecord? _transactionRecord() {
    final sessionFromPayment = _payment?.session;
    if (sessionFromPayment != null) {
      return TransactionRecord(session: sessionFromPayment, payment: _payment);
    }
    final initialSession = _initialSession;
    if (initialSession == null) return null;
    return TransactionRecord(
      session: ParkingSessionSummary.fromJson(initialSession),
      payment: _payment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _initialSession;
    final breakdown = _initialBreakdown;
    final fee = session == null
        ? null
        : double.tryParse(session['total_fee'].toString()) ?? 0;
    final vehicle = session?['vehicle'] as Map?;
    final paidAmount = _payment?.amountDue ?? 0;
    final admin = context.watch<AuthController>().isAdmin;
    final transaction = _transactionRecord();

    final summaryCard = PaymentStatusCard(
      statusLabel: _payment == null ? 'Pending' : 'Paid',
      amountPaid: paidAmount,
      amountDue: fee ?? 0,
      receiptNumber: _payment?.receiptNumber,
      method: _payment?.methodLabel,
    );

    final sessionSnapshotCard = _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session snapshot',
                      style: TextStyle(
                          color: Color(0xFF16233F),
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'The exit screen hands over the prepared session before final confirmation.',
                      style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12.5,
                          height: 1.35),
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
            _InfoRow(
                label: 'Plate',
                value: vehicle?['plate_number']?.toString() ?? ''),
            const SizedBox(height: 8),
            _InfoRow(
                label: 'Entry time',
                value: session['entry_time'] == null
                    ? 'N/A'
                    : _formatDateTime(session['entry_time'].toString())),
            const SizedBox(height: 8),
            _InfoRow(
                label: 'Calculated duration',
                value:
                    _durationLabel(_intValue(breakdown?['duration_minutes']))),
            const SizedBox(height: 8),
            _InfoRow(label: 'Amount due', value: money(fee ?? 0)),
          ] else
            const Text(
              'If the session did not arrive from exit, type the session ID below to continue.',
              style: TextStyle(color: Color(0xFF667085), height: 1.35),
            ),
        ],
      ),
    );

    final formCard = _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash payment',
                      style: TextStyle(
                          color: Color(0xFF16233F),
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cash only. Confirm the amount, then close the session.',
                      style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12.5,
                          height: 1.35),
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
            StatusBadge(
                label: 'Session locked', color: const Color(0xFF10B981)),
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
            decoration:
                const InputDecoration(labelText: 'Cash shift ID (optional)'),
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
              onPressed: _busy
                  ? null
                  : () {
                      _confirm();
                    },
            ),
          ),
        ],
      ),
    );

    final receiptCard = _payment == null
        ? const SizedBox.shrink()
        : _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt',
                            style: TextStyle(
                                color: Color(0xFF16233F),
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Receipt ${_payment!.receiptNumber}',
                            style: const TextStyle(
                                color: Color(0xFF667085), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                    label: 'Plate',
                    value: transaction?.plateNumber ??
                        vehicle?['plate_number']?.toString() ??
                        ''),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Entry time',
                    value: _formatDateTime(
                        transaction?.entryTime?.toIso8601String())),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Exit time',
                    value: _formatDateTime(
                        transaction?.exitTime?.toIso8601String())),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Duration',
                    value: _durationLabel(transaction?.durationMinutes ?? 0)),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Amount due', value: money(_payment!.amountDue)),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Cash received',
                    value: money(_payment!.amountTendered)),
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Change due', value: money(_payment!.changeDue)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Method', value: _payment!.methodLabel),
                const SizedBox(height: 8),
                _InfoRow(label: 'Status', value: _payment!.paymentStatusLabel),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GradientActionButton(
                    label: 'View full receipt',
                    icon: Icons.open_in_new_rounded,
                    minHeight: 48,
                    onPressed: transaction == null
                        ? null
                        : () =>
                            context.push('/receipts/view', extra: transaction),
                  ),
                ),
                const SizedBox(height: 10),
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
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          _buildHeader(),
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
          if (_payment != null) ...[
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

  String _formatDateTime(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')} '
        '${_month(date.month)} ${date.year}, '
        '${DateFormat('hh:mm a').format(date)}';
  }

  int _intValue(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _durationLabel(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '${remaining}m';
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
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
            style: const TextStyle(
                color: Color(0xFF667085), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Color(0xFF16233F), fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
