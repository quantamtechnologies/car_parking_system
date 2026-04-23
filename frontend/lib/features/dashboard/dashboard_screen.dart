import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_errors.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
    ]);

    return _DashboardBundle(
      today: results[0],
      week: results[1],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<_DashboardBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SurfaceCard(
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
                            onPressed: () => setState(() => _future = _load()),
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
          final averageRevenue = week.revenuePerDay / 7;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1200
                            ? 4
                            : constraints.maxWidth >= 760
                                ? 2
                                : 1;
                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: columns == 1 ? 2.8 : 1.9,
                          children: [
                            MetricCard(
                              title: 'Cars Today',
                              value: today.carsPerDay.toString(),
                              subtitle: 'Live count',
                              icon: Icons.directions_car_rounded,
                              gradient: const LinearGradient(colors: [Color(0xFF4A35E8), Color(0xFF2EC7FF)]),
                            ),
                            MetricCard(
                              title: 'Average Cars (Weekly)',
                              value: week.averageCarsPerDay.toStringAsFixed(1),
                              subtitle: 'Last 7 days',
                              icon: Icons.insights_rounded,
                              gradient: const LinearGradient(colors: [Color(0xFF11162C), Color(0xFF4A35E8)]),
                            ),
                            MetricCard(
                              title: 'Revenue Today',
                              value: money(today.revenuePerDay),
                              subtitle: 'Cash confirmed',
                              icon: Icons.payments_rounded,
                              gradient: const LinearGradient(colors: [Color(0xFF1E2A52), Color(0xFF0E4D7A)]),
                            ),
                            MetricCard(
                              title: 'Average Revenue (Weekly)',
                              value: money(averageRevenue),
                              subtitle: 'Last 7 days',
                              icon: Icons.bar_chart_rounded,
                              gradient: const LinearGradient(colors: [Color(0xFF2A1F66), Color(0xFF4A35E8)]),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      radius: 28,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick actions',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Shortcuts for the most common gate workflows.',
                                      style: TextStyle(color: Color(0xFF667085), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Entry / Exit / Payment / Reports',
                                style: TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                QuickActionCard(
                                  title: 'Entry',
                                  subtitle: 'Scan plate',
                                  icon: Icons.directions_car_rounded,
                                  onTap: () => context.go('/entry'),
                                ),
                                const SizedBox(width: 12),
                                QuickActionCard(
                                  title: 'Exit',
                                  subtitle: 'Prepare receipt',
                                  icon: Icons.exit_to_app_rounded,
                                  onTap: () => context.go('/exit'),
                                ),
                                const SizedBox(width: 12),
                                QuickActionCard(
                                  title: 'Payment',
                                  subtitle: 'Confirm cash',
                                  icon: Icons.payments_rounded,
                                  onTap: () => context.go('/payment'),
                                ),
                                const SizedBox(width: 12),
                                QuickActionCard(
                                  title: 'Reports',
                                  subtitle: 'Review trends',
                                  icon: Icons.bar_chart_rounded,
                                  onTap: () => context.go('/reports'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBundle {
  _DashboardBundle({
    required this.today,
    required this.week,
  });

  final DashboardMetrics today;
  final DashboardMetrics week;
}
