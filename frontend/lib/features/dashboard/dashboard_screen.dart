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

  // Reserved for deep-link handoff from entry or camera flows.
  // ignore: unused_field
  final String initialPlate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardMetrics> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardMetrics> _load() async {
    final api = context.read<SmartParkingApi>();
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    return api.dashboard(start: todayKey, end: todayKey);
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
        child: FutureBuilder<DashboardMetrics>(
          future: _future,
          builder: (context, snapshot) {
            final header = ParkingScreenHeader(
              title: 'Dashboard',
              subtitle: 'Cashier terminal',
              user: user,
              onLeadingTap: () {},
              leadingIcon: Icons.menu_rounded,
              trailingIcon: Icons.notifications_none_rounded,
              trailingOnTap: () {},
              trailingBadgeColor: const Color(0xFFEF4444),
              dark: true,
              backgroundGradient: const LinearGradient(
                colors: [Color(0xFF081532), Color(0xFF0B1C48), Color(0xFF122B63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              titleColor: Colors.white,
              subtitleColor: const Color(0xFFB0BBDD),
              leadingBackground: const Color(0xFF1B2D5F),
              leadingIconColor: Colors.white,
              trailingBackground: const Color(0xFF1B2D5F),
              trailingIconColor: Colors.white,
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
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: SurfaceCard(
                            radius: 24,
                            padding: const EdgeInsets.all(14),
                            color: const Color(0xFF0F1B3A),
                            borderColor: const Color(0xFF1E2B4D),
                            shadow: const [
                              BoxShadow(color: Color(0x40050A15), blurRadius: 18, offset: Offset(0, 10)),
                            ],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Unable to load dashboard',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  apiErrorMessage(snapshot.error, fallback: 'Please try again in a moment.'),
                                  style: const TextStyle(color: Color(0xFF9EABC9), height: 1.4),
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
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final metricCards = [
              MetricCard(
                title: 'Today Cars',
                value: data.carsPerDay.toString(),
                icon: Icons.directions_car_rounded,
                gradient: ParkingColors.blueCardGradient,
                iconColor: Colors.white,
              ),
              MetricCard(
                title: 'Revenue',
                value: money(data.revenuePerDay),
                icon: Icons.account_balance_wallet_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E7C66), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                iconColor: Colors.white,
              ),
              MetricCard(
                title: 'Active Cars',
                value: data.activeSessions.toString(),
                icon: Icons.local_parking_rounded,
                gradient: ParkingColors.purpleCardGradient,
                iconColor: Colors.white,
              ),
              MetricCard(
                title: 'Pending Payments',
                value: data.pendingPayments.toString(),
                icon: Icons.payments_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                iconColor: Colors.white,
              ),
            ];

            final quickActions = [
              QuickActionCard(
                title: 'New Entry',
                subtitle: '',
                icon: Icons.directions_car_rounded,
                accentColor: ParkingColors.primary,
                onTap: () => context.go('/entry'),
              ),
              QuickActionCard(
                title: 'Exit',
                subtitle: '',
                icon: Icons.exit_to_app_rounded,
                accentColor: const Color(0xFF7C3AED),
                onTap: () => context.go('/exit'),
              ),
              QuickActionCard(
                title: 'Receipts',
                subtitle: '',
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFF10B981),
                onTap: () => context.go('/receipts'),
              ),
              QuickActionCard(
                title: 'Reports',
                subtitle: '',
                icon: Icons.bar_chart_rounded,
                accentColor: const Color(0xFFF59E0B),
                onTap: () => context.go('/reports'),
              ),
            ];

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
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.06,
                              children: metricCards,
                            ),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                'Quick Actions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.18,
                              children: quickActions,
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
