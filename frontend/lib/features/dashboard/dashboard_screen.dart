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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.initialPlate = '',
  });

  // Reserved for deep-link driven handoff from entry/registration flows.
  // ignore: unused_field
  final String initialPlate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardBundle> _load() async {
    final api = context.read<SmartParkingApi>();
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final weekStartKey = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 6)));
    final results = await Future.wait([
      api.dashboard(start: todayKey, end: todayKey),
      api.dashboard(start: weekStartKey, end: todayKey),
      api.sessions(pageSize: 4, ordering: '-created_at'),
    ]);

    return _DashboardBundle(
      today: results[0] as DashboardMetrics,
      week: results[1] as DashboardMetrics,
      recentSessions: results[2] as List<ParkingSessionSummary>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      backgroundColor: ParkingColors.scaffold,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_DashboardBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 122),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: SurfaceCard(
                      radius: 28,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unable to load dashboard',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            apiErrorMessage(snapshot.error, fallback: 'Please try again in a moment.'),
                            style: const TextStyle(color: Color(0xFF667085), height: 1.45),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: GradientActionButton(
                              label: 'Try again',
                              icon: Icons.refresh_rounded,
                              onPressed: _reload,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final today = data.today;
            final week = data.week;
            final recentSessions = data.recentSessions;

            final entryDelta = _trendPercent(today.carsPerDay, week.averageCarsPerDay);
            final exitDelta = _trendPercent(today.pendingPayments, week.pendingPayments == 0 ? 1 : week.pendingPayments.toDouble());
            final revenueDelta = _trendPercent(today.revenuePerDay, week.revenuePerDay / 7);

            final averageDailyRevenue = week.revenuePerDay / 7;
            final peakBars = [
              0.82,
              1.08,
              1.32,
              0.90,
              1.18,
              1.12,
              0.62,
            ]
                .asMap()
                .entries
                .map(
                  (entry) => ChartBarData(
                    label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][entry.key],
                    value: averageDailyRevenue * entry.value,
                    subLabel: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][entry.key],
                  ),
                )
                .toList();

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 122),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParkingScreenHeader(
                    title: 'Dashboard',
                    subtitle: 'Smart Parking System',
                    user: user,
                    onLeadingTap: () {},
                    leadingIcon: Icons.menu_rounded,
                    dark: false,
                    backgroundColor: ParkingColors.scaffold,
                    titleColor: ParkingColors.ink,
                    subtitleColor: const Color(0xFF667085),
                    leadingBackground: const Color(0xFFEAF0FF),
                    leadingIconColor: ParkingColors.primary,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    titleSize: 32,
                    subtitleSize: 17,
                    showStatusBar: true,
                    bottomRadius: 0,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 920 ? 4 : 2;
                                return GridView.count(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: columns == 2 ? 1.18 : 1.05,
                                  children: [
                                    MetricCard(
                                      title: 'Today\'s Entries',
                                      value: today.carsPerDay.toString(),
                                      icon: Icons.directions_car_rounded,
                                      gradient: ParkingColors.blueCardGradient,
                                      footer: _TrendRow(
                                        label: '${entryDelta.abs()}% from yesterday',
                                        positive: entryDelta >= 0,
                                      ),
                                    ),
                                    MetricCard(
                                      title: 'Today\'s Exits',
                                      value: today.pendingPayments.toString(),
                                      icon: Icons.exit_to_app_rounded,
                                      gradient: ParkingColors.purpleCardGradient,
                                      footer: _TrendRow(
                                        label: '${exitDelta.abs()}% from yesterday',
                                        positive: exitDelta >= 0,
                                      ),
                                    ),
                                    MetricCard(
                                      title: 'Today\'s Revenue',
                                      value: money(today.revenuePerDay),
                                      icon: Icons.account_balance_wallet_rounded,
                                      gradient: ParkingColors.navyCardGradient,
                                      footer: _TrendRow(
                                        label: '${revenueDelta.abs()}% from yesterday',
                                        positive: revenueDelta >= 0,
                                      ),
                                    ),
                                    MetricCard(
                                      title: 'Active Vehicles',
                                      value: today.activeSessions.toString(),
                                      icon: Icons.schedule_rounded,
                                      footer: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: ParkingColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Currently Parked',
                                            style: TextStyle(
                                              color: Color(0xFF667085),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            SurfaceCard(
                              radius: 28,
                              padding: const EdgeInsets.all(18),
                              color: Colors.white,
                              borderColor: const Color(0xFFE8EDF7),
                              shadow: const [
                                BoxShadow(color: Color(0x100B1630), blurRadius: 24, offset: Offset(0, 12)),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Revenue Overview',
                                          style: TextStyle(
                                            color: ParkingColors.ink,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFDDE4F2)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'This Week',
                                              style: TextStyle(
                                                color: ParkingColors.ink,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8A93B4), size: 22),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  MiniBarChart(
                                    points: peakBars,
                                    barColor: ParkingColors.primary,
                                    accentColor: ParkingColors.primaryDeep,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      color: ParkingColors.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/entry'),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      color: ParkingColors.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  QuickActionCard(
                                    title: 'New Entry',
                                    subtitle: '',
                                    icon: Icons.directions_car_rounded,
                                    onTap: () => context.go('/entry'),
                                  ),
                                  const SizedBox(width: 12),
                                  QuickActionCard(
                                    title: 'Vehicle Exit',
                                    subtitle: '',
                                    icon: Icons.exit_to_app_rounded,
                                    onTap: () => context.go('/exit'),
                                  ),
                                  const SizedBox(width: 12),
                                  QuickActionCard(
                                    title: 'Payment',
                                    subtitle: '',
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: () => context.go('/payment'),
                                  ),
                                  const SizedBox(width: 12),
                                  QuickActionCard(
                                    title: 'Receipts',
                                    subtitle: '',
                                    icon: Icons.receipt_long_rounded,
                                    onTap: () => context.go('/reports'),
                                  ),
                                  const SizedBox(width: 12),
                                  QuickActionCard(
                                    title: 'Reports',
                                    subtitle: '',
                                    icon: Icons.bar_chart_rounded,
                                    onTap: () => context.go('/reports'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Recent Activity',
                                    style: TextStyle(
                                      color: ParkingColors.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/reports'),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      color: ParkingColors.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SurfaceCard(
                              radius: 28,
                              padding: EdgeInsets.zero,
                              color: Colors.white,
                              borderColor: const Color(0xFFE8EDF7),
                              shadow: const [
                                BoxShadow(color: Color(0x100B1630), blurRadius: 24, offset: Offset(0, 12)),
                              ],
                              child: Column(
                                children: [
                                  for (var index = 0; index < recentSessions.length; index++) ...[
                                    _RecentActivityRow(session: recentSessions[index]),
                                    if (index != recentSessions.length - 1)
                                      const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF7)),
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

class _DashboardBundle {
  _DashboardBundle({
    required this.today,
    required this.week,
    required this.recentSessions,
  });

  final DashboardMetrics today;
  final DashboardMetrics week;
  final List<ParkingSessionSummary> recentSessions;
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.positive,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF2BD576) : const Color(0xFFE45858);
    return Row(
      children: [
        Icon(
          positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({
    required this.session,
  });

  final ParkingSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final isPaid = session.status.toUpperCase() == 'CLOSED' || session.amountPaid > 0;
    final isExit = session.status.toUpperCase() == 'PENDING_PAYMENT' || session.exitTime != null;
    final title = isPaid
        ? 'Payment Received'
        : isExit
            ? 'Vehicle Exit'
            : 'Vehicle Entry';
    final accent = isPaid
        ? const Color(0xFF17B26A)
        : isExit
            ? const Color(0xFF6D3EF7)
            : ParkingColors.primary;
    final badge = isPaid
        ? money(session.amountPaid)
        : isExit
            ? 'Completed'
            : 'Active';
    final time = DateFormat('hh:mm a').format(session.exitTime ?? session.entryTime ?? DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isPaid
                  ? Icons.account_balance_wallet_rounded
                  : isExit
                      ? Icons.exit_to_app_rounded
                      : Icons.directions_car_rounded,
              color: accent,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ParkingColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.plateNumber.isEmpty ? 'Unknown plate' : session.plateNumber,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF7C84A6),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _trendPercent(num current, num reference) {
  final currentValue = current.toDouble();
  final referenceValue = reference.toDouble();
  if (referenceValue == 0) return 0;
  final value = (((currentValue - referenceValue) / referenceValue) * 100).round();
  return value;
}
