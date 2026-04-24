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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<_ReportsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportsBundle> _load() async {
    final api = context.read<SmartParkingApi>();
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final weekStartKey = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 6)));
    final results = await Future.wait([
      api.dashboard(start: todayKey, end: todayKey),
      api.dashboard(start: weekStartKey, end: todayKey),
    ]);

    return _ReportsBundle(
      today: results[0],
      week: results[1],
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
        child: FutureBuilder<_ReportsBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 122),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ParkingScreenHeader(
                      title: 'Reports',
                      subtitle: 'Revenue and traffic overview',
                      user: user,
                      onLeadingTap: () => context.go('/'),
                      leadingIcon: Icons.arrow_back_rounded,
                      dark: true,
                      backgroundGradient: const LinearGradient(
                        colors: [Color(0xFFEA7A11), Color(0xFFF59E0B), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      titleColor: Colors.white,
                      subtitleColor: const Color(0xFFFFE7C2),
                      leadingBackground: Colors.white.withOpacity(0.16),
                      leadingIconColor: Colors.white,
                      trailingIcon: Icons.qr_code_scanner_rounded,
                      trailingOnTap: () {},
                      trailingBackground: Colors.white.withOpacity(0.16),
                      trailingIconColor: Colors.white,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      titleSize: 28,
                      subtitleSize: 15,
                      bottomRadius: 30,
                    ),
                    const SizedBox(height: 160),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 122),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ParkingScreenHeader(
                      title: 'Reports',
                      subtitle: 'Revenue and traffic overview',
                      user: user,
                      onLeadingTap: () => context.go('/'),
                      leadingIcon: Icons.arrow_back_rounded,
                      dark: true,
                      backgroundGradient: const LinearGradient(
                        colors: [Color(0xFFEA7A11), Color(0xFFF59E0B), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      titleColor: Colors.white,
                      subtitleColor: const Color(0xFFFFE7C2),
                      leadingBackground: Colors.white.withOpacity(0.16),
                      leadingIconColor: Colors.white,
                      trailingIcon: Icons.qr_code_scanner_rounded,
                      trailingOnTap: () {},
                      trailingBackground: Colors.white.withOpacity(0.16),
                      trailingIconColor: Colors.white,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      titleSize: 28,
                      subtitleSize: 15,
                      bottomRadius: 30,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unable to load reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final today = data.today;
            final week = data.week;
            final averageRevenue = week.revenuePerDay / 7;
            final peakBars = today.peakHours
                .map(
                  (point) => ChartBarData(
                    label: _hourLabel(point['hour']),
                    value: (point['total'] is num ? (point['total'] as num).toDouble() : 0),
                    subLabel: '${point['total'] ?? 0} cars',
                  ),
                )
                .toList()
              ..sort((a, b) => a.label.compareTo(b.label));

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 122),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParkingScreenHeader(
                    title: 'Reports',
                    subtitle: 'Revenue and traffic overview',
                    user: user,
                    onLeadingTap: () => context.go('/'),
                    leadingIcon: Icons.arrow_back_rounded,
                    dark: true,
                    backgroundGradient: const LinearGradient(
                      colors: [Color(0xFFEA7A11), Color(0xFFF59E0B), Color(0xFFEF4444)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    titleColor: Colors.white,
                    subtitleColor: const Color(0xFFFFE7C2),
                    leadingBackground: Colors.white.withOpacity(0.16),
                    leadingIconColor: Colors.white,
                    trailingIcon: Icons.qr_code_scanner_rounded,
                    trailingOnTap: () {},
                    trailingBackground: Colors.white.withOpacity(0.16),
                    trailingIconColor: Colors.white,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    titleSize: 28,
                    subtitleSize: 15,
                    bottomRadius: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SurfaceCard(
                              radius: 28,
                              padding: const EdgeInsets.all(18),
                              color: const Color(0xFF0F1B3A),
                              borderColor: const Color(0xFF1E2B4D),
                              shadow: const [
                                BoxShadow(color: Color(0x40050A15), blurRadius: 24, offset: Offset(0, 12)),
                              ],
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
                                            'Cars over time',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                  color: Colors.white,
                                                ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Today\'s traffic by hour, displayed in a compact and readable chart.',
                                              style: TextStyle(color: Color(0xFF9EABC9), height: 1.35),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(label: '${today.carsPerDay} today', color: const Color(0xFF4A35E8)),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  MiniBarChart(points: peakBars),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 1100
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
                                    childAspectRatio: columns == 1 ? 2.6 : 1.8,
                                  children: [
                                    MetricCard(
                                      title: 'Total Revenue',
                                      value: money(week.revenuePerDay),
                                      subtitle: 'Last 7 days',
                                      icon: Icons.payments_rounded,
                                      gradient: const LinearGradient(colors: [Color(0xFF0E7C66), Color(0xFF10B981)]),
                                    ),
                                    MetricCard(
                                      title: 'Total Cars',
                                      value: week.carsPerDay.toString(),
                                      subtitle: 'Last 7 days',
                                      icon: Icons.directions_car_rounded,
                                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F7DFB)]),
                                    ),
                                    MetricCard(
                                      title: 'Average Cars / Day',
                                      value: week.averageCarsPerDay.toStringAsFixed(1),
                                      subtitle: '7-day average',
                                      icon: Icons.insights_rounded,
                                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                                    ),
                                    MetricCard(
                                      title: 'Average Revenue / Day',
                                      value: money(averageRevenue),
                                      subtitle: '7-day average',
                                      icon: Icons.bar_chart_rounded,
                                      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                                    ),
                                  ],
                                );
                              },
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

class _ReportsBundle {
  _ReportsBundle({
    required this.today,
    required this.week,
  });

  final DashboardMetrics today;
  final DashboardMetrics week;
}

String _hourLabel(dynamic hour) {
  final value = hour is num ? hour.toInt() : int.tryParse(hour?.toString() ?? '') ?? 0;
  return '${value.toString().padLeft(2, '0')}h';
}
