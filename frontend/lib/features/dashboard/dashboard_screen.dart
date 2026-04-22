import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_errors.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardBundle> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_DashboardBundle> _load() async {
    final api = context.read<SmartParkingApi>();
    final overview = await api.overview();
    final metrics = await api.dashboard();
    final active = await api.activeSessions();
    return _DashboardBundle(
      overview: overview,
      metrics: metrics,
      activeSessions: active,
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
            return ListView(
              children: [
                const SizedBox(height: 140),
                Center(child: Text('Unable to load dashboard: ${apiErrorMessage(snapshot.error, fallback: 'Please try again in a moment.')}')),
              ],
            );
          }

          final data = snapshot.data!;
          final metrics = data.metrics;
          final overview = data.overview;
          final active = data.activeSessions;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeader(
                title: 'Operations at a glance',
                subtitle: 'Live parking, revenue, and cashier health across the gate.',
                trailing: TextButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1200 ? 4 : constraints.maxWidth >= 700 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: columns == 1 ? 2.4 : 1.8,
                    children: [
                      MetricCard(
                        title: 'Cars today',
                        value: metrics.carsPerDay.toString(),
                        subtitle: 'Average ${metrics.averageCarsPerDay.toStringAsFixed(1)} per day',
                        icon: Icons.directions_car_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF0F4CFF), Color(0xFF49D2FF)]),
                      ),
                      MetricCard(
                        title: 'Revenue today',
                        value: money(metrics.revenuePerDay),
                        subtitle: 'Cash only',
                        icon: Icons.payments_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF0A1F44), Color(0xFF0F4CFF)]),
                      ),
                      MetricCard(
                        title: 'Occupancy',
                        value: '${metrics.occupancyRate.toStringAsFixed(1)}%',
                        subtitle: '${overview['occupied_slots'] ?? 0} occupied slots',
                        icon: Icons.local_parking_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)]),
                      ),
                      MetricCard(
                        title: 'Open shifts',
                        value: metrics.openCashShifts.toString(),
                        subtitle: '${metrics.pendingPayments} pending payments',
                        icon: Icons.badge_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF009688), Color(0xFF26C6DA)]),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _Panel(
                          title: 'Quick actions',
                          child: GridView.count(
                            crossAxisCount: constraints.maxWidth >= 700 ? 2 : 1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.65,
                            children: [
                              QuickActionCard(title: 'Entry', subtitle: 'Scan or type plate', icon: Icons.directions_car_rounded, onTap: () => context.go('/entry')),
                              QuickActionCard(title: 'Exit', subtitle: 'Prepare payment', icon: Icons.exit_to_app_rounded, onTap: () => context.go('/exit')),
                              QuickActionCard(title: 'Payment', subtitle: 'Confirm cash', icon: Icons.payments_rounded, onTap: () => context.go('/payment')),
                              QuickActionCard(title: 'Reports', subtitle: 'Daily and weekly', icon: Icons.bar_chart_rounded, onTap: () => context.go('/reports')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16, height: 16),
                      Expanded(
                        flex: 5,
                        child: _Panel(
                          title: 'Active sessions',
                          child: active.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(child: Text('No active sessions right now.')),
                                )
                              : Column(
                                  children: [
                                    for (final session in active.take(6))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _SessionTile(session: session),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _Panel(
                title: 'System signals',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatusBadge(label: 'Today entries: ${metrics.carsPerDay}', color: const Color(0xFF0F4CFF)),
                    StatusBadge(label: 'Pending payments: ${metrics.pendingPayments}', color: const Color(0xFFF2994A)),
                    StatusBadge(label: 'Open shifts: ${metrics.openCashShifts}', color: const Color(0xFF009688)),
                    StatusBadge(label: 'Occupancy: ${metrics.occupancyRate.toStringAsFixed(1)}%', color: const Color(0xFF5E35B1)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final ParkingSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final time = session.entryTime == null ? 'Now' : TimeOfDay.fromDateTime(session.entryTime!).format(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F4CFF), Color(0xFF4DD4FF)]),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: const Icon(Icons.local_parking_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.plateNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('${session.zoneName} | Slot ${session.slotCode}'),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(session.status, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(time, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardBundle {
  _DashboardBundle({
    required this.overview,
    required this.metrics,
    required this.activeSessions,
  });

  final Map<String, dynamic> overview;
  final DashboardMetrics metrics;
  final List<ParkingSessionSummary> activeSessions;
}
