import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/services/receipt_printer.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
    this.receiptMode = false,
  });

  final TransactionRecord transaction;
  final bool receiptMode;

  Future<void> _print(BuildContext context) async {
    final printed = await printTransactionReceipt(transaction);
    if (!context.mounted) return;
    if (!printed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printing is available in the web receipt view.'),
        ),
      );
    }
  }

  String _dateTime(DateTime? value) {
    if (value == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }

  String _duration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '${remaining}m';
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  @override
  Widget build(BuildContext context) {
    final title = receiptMode ? 'Receipt View' : 'Transaction Details';
    final subtitle = receiptMode
        ? 'Printable cash receipt'
        : 'Full entry and exit information';
    final amount = transaction.payment == null
        ? transaction.amount
        : transaction.amountPaid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          ParkingScreenHeader(
            title: title,
            subtitle: subtitle,
            user: null,
            onLeadingTap: () => context.pop(),
            leadingIcon: Icons.arrow_back_rounded,
            backgroundColor: Colors.white,
            titleColor: const Color(0xFF16233F),
            subtitleColor: const Color(0xFF667085),
            leadingBackground: const Color(0xFFEAF1FF),
            leadingIconColor: ParkingColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            titleSize: 26,
            subtitleSize: 13.5,
            bottomRadius: 26,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SurfaceCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      borderColor: const Color(0xFFE5EBF5),
                      shadow: const [
                        BoxShadow(
                            color: Color(0x14050A15),
                            blurRadius: 18,
                            offset: Offset(0, 10)),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              color: Color(0xFF16233F),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              StatusBadge(
                                label: transaction.statusLabel,
                                color: transaction.statusLabel == 'PAID'
                                    ? const Color(0xFF16A34A)
                                    : transaction.statusLabel == 'ACTIVE'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFF59E0B),
                              ),
                              if (transaction.hasReceipt)
                                StatusBadge(
                                  label: transaction.receiptNumber,
                                  color: const Color(0xFF111827),
                                ),
                              StatusBadge(
                                label: transaction.paymentMethod.toUpperCase(),
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                              label: 'Plate Number',
                              value: transaction.plateNumber),
                          _DetailRow(
                              label: 'Vehicle Type',
                              value: transaction.vehicleTypeLabelText),
                          _DetailRow(
                              label: 'Owner Name',
                              value: transaction.ownerName),
                          _DetailRow(
                              label: 'Phone Number',
                              value: transaction.phoneNumber),
                          _DetailRow(
                              label: 'Entry Time',
                              value: _dateTime(transaction.entryTime)),
                          _DetailRow(
                              label: 'Exit Time',
                              value: _dateTime(transaction.exitTime)),
                          _DetailRow(
                              label: 'Duration',
                              value: _duration(transaction.durationMinutes)),
                          _DetailRow(label: 'Amount', value: money(amount)),
                          _DetailRow(
                              label: 'Payment Status',
                              value: transaction.paymentStatus),
                          if (transaction.hasReceipt)
                            _DetailRow(
                                label: 'Receipt ID',
                                value: transaction.receiptNumber),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      borderColor: const Color(0xFFE5EBF5),
                      shadow: const [
                        BoxShadow(
                            color: Color(0x14050A15),
                            blurRadius: 18,
                            offset: Offset(0, 10)),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Charges',
                            style: TextStyle(
                              color: Color(0xFF16233F),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                              label: 'Base Fee',
                              value: money(transaction.session.baseFee)),
                          _DetailRow(
                              label: 'Rate Per Hour',
                              value: money(transaction.session.ratePerHour)),
                          _DetailRow(
                              label: 'Extra Charges',
                              value: money(transaction.session.extraCharges)),
                          _DetailRow(
                              label: 'Penalty',
                              value: money(transaction.session.penaltyAmount)),
                          _DetailRow(
                              label: 'Total Amount',
                              value: money(transaction.amount)),
                          _DetailRow(
                              label: 'Amount Paid',
                              value: money(transaction.amountPaid)),
                        ],
                      ),
                    ),
                    if (transaction.hasReceipt) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: GradientActionButton(
                          label: 'PRINT RECEIPT',
                          icon: Icons.print_rounded,
                          onPressed: () => _print(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF16233F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
