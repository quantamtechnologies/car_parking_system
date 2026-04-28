import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  late Future<_ReceiptsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReceiptsBundle> _load() async {
    final api = context.read<SmartParkingApi>();
    final payments =
        await api.payments(pageSize: 20, ordering: '-confirmed_at');
    final totalCollected =
        payments.fold<double>(0, (sum, payment) => sum + payment.amountDue);

    return _ReceiptsBundle(
      payments: payments,
      totalCollected: totalCollected,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_ReceiptsBundle>(
          future: _future,
          builder: (context, snapshot) {
            final header = ParkingScreenHeader(
              title: 'Receipts',
              subtitle: 'Recent paid transactions',
              user: null,
              onLeadingTap: () => context.go('/'),
              leadingIcon: Icons.arrow_back_rounded,
              backgroundColor: Colors.white,
              titleColor: const Color(0xFF16233F),
              subtitleColor: const Color(0xFF667085),
              leadingBackground: const Color(0xFFEAF1FF),
              leadingIconColor: ParkingColors.primary,
              trailingIcon: Icons.refresh_rounded,
              trailingOnTap: () {
                _reload();
              },
              trailingBackground: const Color(0xFFEAF1FF),
              trailingIconColor: ParkingColors.primary,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              titleSize: 26,
              subtitleSize: 13.5,
              bottomRadius: 26,
            );

            if (snapshot.connectionState != ConnectionState.done) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 140),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: SurfaceCard(
                        radius: 24,
                        padding: const EdgeInsets.all(14),
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
                              'Unable to load receipts',
                              style: TextStyle(
                                  color: Color(0xFF16233F),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              apiErrorMessage(snapshot.error,
                                  fallback: 'Please try again in a moment.'),
                              style: const TextStyle(
                                  color: Color(0xFF667085), height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: GradientActionButton(
                                label: 'Try again',
                                icon: Icons.refresh_rounded,
                                onPressed: () {
                                  _reload();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final recent = data.payments;
            final total = data.totalCollected;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
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
                              padding: const EdgeInsets.all(14),
                              color: Colors.white,
                              borderColor: const Color(0xFFE5EBF5),
                              shadow: const [
                                BoxShadow(
                                    color: Color(0x14050A15),
                                    blurRadius: 18,
                                    offset: Offset(0, 10)),
                              ],
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF1FF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Recent receipts',
                                          style: TextStyle(
                                              color: Color(0xFF16233F),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${recent.length} paid transactions - ${money(total)} collected',
                                          style: const TextStyle(
                                              color: Color(0xFF667085),
                                              fontSize: 12.5,
                                              height: 1.35),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const StatusBadge(
                                      label: 'Cash only',
                                      color: Color(0xFF10B981)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SurfaceCard(
                              radius: 24,
                              padding: EdgeInsets.zero,
                              color: Colors.white,
                              borderColor: const Color(0xFFE5EBF5),
                              shadow: const [
                                BoxShadow(
                                    color: Color(0x14050A15),
                                    blurRadius: 18,
                                    offset: Offset(0, 10)),
                              ],
                              child: Column(
                                children: [
                                  if (recent.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        children: const [
                                          Icon(Icons.receipt_long_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 34),
                                          SizedBox(height: 10),
                                          Text(
                                            'No receipts yet',
                                            style: TextStyle(
                                                color: Color(0xFF16233F),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Confirmed payments will appear here once they are saved.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Color(0xFF667085),
                                                height: 1.35),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    for (var index = 0;
                                        index < recent.length;
                                        index++) ...[
                                      _ReceiptTile(
                                        payment: recent[index],
                                      ),
                                      if (index != recent.length - 1)
                                        const Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Color(0xFFE5EBF5)),
                                    ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReceiptsBundle {
  _ReceiptsBundle({
    required this.payments,
    required this.totalCollected,
  });

  final List<PaymentRecord> payments;
  final double totalCollected;
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final session = payment.session;
    if (session == null) {
      return const SizedBox.shrink();
    }
    final transaction = TransactionRecord(session: session, payment: payment);
    final status = payment.status.toUpperCase();
    final accent = status == 'OVERRIDDEN'
        ? const Color(0xFFF59E0B)
        : status == 'CONFIRMED'
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);
    final entryTime = session.entryTime == null
        ? 'N/A'
        : DateFormat('dd MMM HH:mm').format(session.entryTime!);
    final exitTime = session.exitTime == null
        ? 'N/A'
        : DateFormat('dd MMM HH:mm').format(session.exitTime!);

    return InkWell(
      onTap: () => context.push('/receipts/view', extra: transaction),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.receipt_long_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.plateNumber,
                    style: const TextStyle(
                        color: Color(0xFF16233F),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.displayVehicleType} • ${session.ownerDisplay}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Entry $entryTime  Exit $exitTime',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBadge(
                          label: payment.methodLabel.toUpperCase(),
                          color: const Color(0xFF2563EB)),
                      StatusBadge(label: 'PAID', color: accent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(payment.amountDue),
                  style: TextStyle(
                      color: accent, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.receiptNumber,
                  style: const TextStyle(
                      color: Color(0xFF16233F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
