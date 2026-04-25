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
      backgroundColor: const Color(0xFFF4F7FF),
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          color: ParkingColors.primary,
          onRefresh: _reload,
          child: FutureBuilder<DashboardMetrics>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _emptyMetrics();
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: _DashboardHeader(user: user),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _RevenueCard(
                        revenue: _mkMoney(data.revenuePerDay, decimals: 2, zeroPlaceholder: 'MK0,000.00'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = _dashboardCardWidth(constraints.maxWidth);
                          final cards = [
                            _MetricCard(
                              title: 'Today Cars',
                              value: data.carsPerDay.toString(),
                              footer: 'Average cars/day  ${_compactNumber(data.averageCarsPerDay)}',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1CD59A), Color(0xFF12B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              icon: Icons.directions_car_outlined,
                            ),
                            _MetricCard(
                              title: 'Active Cars',
                              value: data.activeSessions.toString(),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9D6DFF), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              icon: Icons.directions_car_filled_outlined,
                            ),
                            _MetricCard(
                              title: 'Pending\nPayments',
                              value: 'MK${NumberFormat('#,##0').format(data.pendingPayments)}',
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFC62A), Color(0xFFF97316)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              icon: Icons.receipt_long_outlined,
                            ),
                          ];

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final card in cards)
                                SizedBox(
                                  width: cardWidth,
                                  child: card,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: _SectionHeader(title: 'Quick Actions'),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = _actionCardWidth(constraints.maxWidth);
                          final actions = [
                            _ActionCard(
                              title: 'Entry',
                              icon: Icons.login_rounded,
                              tint: const Color(0xFF2C6CF6),
                              onTap: () => context.go('/entry'),
                            ),
                            _ActionCard(
                              title: 'Receipts',
                              icon: Icons.receipt_long_rounded,
                              tint: const Color(0xFF7C3AED),
                              onTap: () => context.go('/receipts'),
                            ),
                            _ActionCard(
                              title: 'Exit',
                              icon: Icons.logout_rounded,
                              tint: const Color(0xFFF43F5E),
                              onTap: () => context.go('/exit'),
                            ),
                          ];

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final action in actions)
                                SizedBox(
                                  width: cardWidth,
                                  child: action,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SurfaceCard(
                          radius: 24,
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          borderColor: const Color(0xFFE5EBF5),
                          shadow: const [
                            BoxShadow(color: Color(0x150B1630), blurRadius: 20, offset: Offset(0, 12)),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unable to load dashboard',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                apiErrorMessage(snapshot.error, fallback: 'Please try again in a moment.'),
                                style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _reload,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ParkingColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try again'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

DashboardMetrics _emptyMetrics() {
  return const DashboardMetrics(
    carsPerDay: 0,
    revenuePerDay: 0,
    averageCarsPerDay: 0,
    occupancyRate: 0,
    activeSessions: 0,
    pendingPayments: 0,
    openCashShifts: 0,
    alerts: <Map<String, dynamic>>[],
    peakHours: <Map<String, dynamic>>[],
    staffPerformance: <Map<String, dynamic>>[],
  );
}

double _dashboardCardWidth(double maxWidth) {
  if (maxWidth >= 900) {
    return (maxWidth - 32) / 3;
  }
  if (maxWidth >= 620) {
    return (maxWidth - 16) / 2;
  }
  return maxWidth;
}

double _actionCardWidth(double maxWidth) {
  if (maxWidth >= 900) {
    return (maxWidth - 32) / 3;
  }
  if (maxWidth >= 620) {
    return (maxWidth - 16) / 2;
  }
  return maxWidth;
}

String _compactNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _mkMoney(
  double value, {
  int decimals = 2,
  String? zeroPlaceholder,
}) {
  if (value == 0 && zeroPlaceholder != null) {
    return zeroPlaceholder;
  }

  final pattern = decimals <= 0 ? '#,##0' : '#,##0.${List.filled(decimals, '0').join()}';
  return 'MK${NumberFormat(pattern).format(value)}';
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? 'Joel Ndege';
    final role = (user?.displayRole ?? 'CASHIER').toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final brandSize = compact ? 72.0 : 96.0;
        final avatarSize = compact ? 60.0 : 84.0;
        final nameSize = compact ? 18.0 : 24.0;
        final roleSize = compact ? 13.5 : 19.0;
        final brandFontSize = compact ? 46.0 : 60.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF07124A), Color(0xFF0C1F78), Color(0xFF1233AF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x240B1630), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: brandSize,
                height: brandSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: brandFontSize,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              const Spacer(),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D73F6).withOpacity(0.95),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 46),
                    ),
                    SizedBox(width: compact ? 10 : 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? 150 : 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: nameSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: roleSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.revenue});

  final String revenue;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.8,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF1563FF), Color(0xFF1864F8), Color(0xFF1048E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x250B1630), blurRadius: 24, offset: Offset(0, 14)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -60,
              bottom: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.09),
                ),
              ),
            ),
            Positioned(
              right: -80,
              top: 30,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -24,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    child: const Icon(Icons.payments_outlined, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Revenue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      revenue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 62,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.gradient,
    required this.icon,
    this.footer,
  });

  final String title;
  final String value;
  final Gradient gradient;
  final IconData icon;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.88,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x220B1630), blurRadius: 20, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -26,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: -32,
              bottom: -22,
              child: Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      footer!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          height: 154,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: Color(0x140B1630), blurRadius: 18, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withOpacity(0.12),
                ),
                child: Icon(icon, color: tint, size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF25335B),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C6CF6).withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF9FC0FF),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1F2B5C),
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF9FC0FF),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C6CF6).withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}
