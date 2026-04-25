import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final items = <ParkingBottomNavItem>[
      const ParkingBottomNavItem(path: '/', icon: Icons.home_rounded, label: 'Home'),
      const ParkingBottomNavItem(path: '/entry', icon: Icons.directions_car_rounded, label: 'Entry'),
      const ParkingBottomNavItem(path: '/exit', icon: Icons.exit_to_app_rounded, label: 'Exit'),
      const ParkingBottomNavItem(path: '/payment', icon: Icons.payments_rounded, label: 'Payments'),
      const ParkingBottomNavItem(path: '/reports', icon: Icons.bar_chart_rounded, label: 'Reports'),
    ];
    final normalizedPath = _normalizePath(currentPath);
    final selectedIndex = _selectedIndexForPath(normalizedPath);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: child,
      bottomNavigationBar: ParkingBottomNav(
        items: items,
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onTap: (index) {
          context.go(items[index].path);
        },
      ),
    );
  }
}

int _selectedIndexForPath(String path) {
  switch (path) {
    case '/entry':
    case '/entry/register':
      return 1;
    case '/exit':
      return 2;
    case '/payment':
      return 3;
    case '/reports':
      return 4;
    case '/':
    case '/dashboard':
    default:
      return 0;
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4A35E8).withOpacity(0.16),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: 140,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2EC7FF).withOpacity(0.14),
                    Colors.transparent
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.user,
    required this.onNavigate,
    required this.onLogout,
  });

  final List<ParkingBottomNavItem> items;
  final int selectedIndex;
  final UserProfile? user;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 286,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1028), Color(0xFF111840), Color(0xFF151C50)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: Color(0x280B1630), blurRadius: 34, offset: Offset(0, 20)),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 26),
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFF4A35E8), Color(0xFF2EC7FF)]),
            ),
            child: const Icon(Icons.local_parking_rounded,
                color: Colors.white, size: 38),
          ),
          const SizedBox(height: 14),
          const Text(
            'Smart Parking',
            style: TextStyle(
                color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Premium control panel',
            style:
                TextStyle(color: Colors.white.withOpacity(0.74), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onNavigate(item.path),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.16)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: selected
                                ? Colors.white.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.74),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SurfaceCard(
              radius: 24,
              padding: const EdgeInsets.all(14),
              color: Colors.white.withOpacity(0.08),
              borderColor: Colors.white.withOpacity(0.08),
              shadow: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Operator',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.displayRole ?? 'STAFF',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72), fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GradientActionButton(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      onPressed: onLogout,
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
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.title,
    required this.subtitle,
    required this.user,
    required this.onLogout,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final UserProfile? user;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 18, compact ? 12 : 16, compact ? 12 : 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF667085),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SurfaceCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            borderColor: const Color(0xFFE5ECF5),
            shadow: const [
              BoxShadow(
                  color: Color(0x0F0B1630),
                  blurRadius: 18,
                  offset: Offset(0, 8)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: Color(0xFF4A35E8), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.displayName ?? 'Operator',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    Text(
                      user?.displayRole ?? 'STAFF',
                      style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onLogout,
                  child: const Icon(Icons.logout_rounded,
                      color: Color(0xFF4A35E8), size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizePath(String path) {
  if (path == '/dashboard') return '/';
  return path;
}

String _pageTitle(String path) {
  switch (path) {
    case '/entry':
      return 'Entry';
    case '/exit':
      return 'Exit';
    case '/payment':
      return 'Payment';
    case '/reports':
      return 'Reports';
    case '/admin':
      return 'Admin';
    case '/':
    default:
      return 'Dashboard';
  }
}

String _pageSubtitle(String path) {
  switch (path) {
    case '/entry':
      return 'Capture plates, fill the form, and register the vehicle in a clean split layout.';
    case '/exit':
      return 'Select an active vehicle, review the receipt, and move straight to payment.';
    case '/payment':
      return 'Confirm the cash payment with a clear status and receipt summary.';
    case '/reports':
      return 'See traffic and revenue insights without the usual clutter.';
    case '/admin':
      return 'Manage pricing, operational controls, and admin-only tools from one place.';
    case '/':
    default:
      return 'A minimal control room for live gate operations and daily parking metrics.';
  }
}
