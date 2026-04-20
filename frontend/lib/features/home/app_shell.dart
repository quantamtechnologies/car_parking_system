import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/models.dart';
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
    final auth = context.watch<AuthController>();
    final role = auth.user?.role ?? '';
    final items = <_NavItem>[
      const _NavItem('/', Icons.dashboard_rounded, 'Dashboard'),
      const _NavItem('/entry', Icons.directions_car_rounded, 'Entry'),
      const _NavItem('/exit', Icons.exit_to_app_rounded, 'Exit'),
      const _NavItem('/payment', Icons.payments_rounded, 'Payment'),
      const _NavItem('/alerts', Icons.warning_amber_rounded, 'Alerts'),
      const _NavItem('/reports', Icons.bar_chart_rounded, 'Reports'),
      if (role == 'ADMIN') const _NavItem('/admin', Icons.admin_panel_settings_rounded, 'Admin'),
    ];
    final selectedIndex = items.indexWhere((item) => item.path == currentPath);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F8FF), Color(0xFFECF4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              return Row(
                children: [
                  if (wide) _Sidebar(items: items, selectedIndex: selectedIndex, user: auth.user, onNavigate: (path) => context.go(path)),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          user: auth.user,
                          onLogout: () => context.read<AuthController>().logout(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                color: Colors.white.withOpacity(0.64),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 960
          ? NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) => context.go(items[index].path),
              destinations: [
                for (final item in items)
                  NavigationDestination(icon: Icon(item.icon), label: item.label),
              ],
            )
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.user,
    required this.onNavigate,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final UserProfile? user;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F44),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Color(0x1F0A1F44), blurRadius: 30, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF0F4CFF), Color(0xFF4DD4FF)]),
            ),
            child: const Icon(Icons.local_parking_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 14),
          const Text('Smart Parking', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(user?.displayName ?? 'POS Interface', style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onNavigate(item.path),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withOpacity(0.16) : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(item.icon, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
            child: GradientActionButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              onPressed: () => context.read<AuthController>().logout(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.user, required this.onLogout});

  final UserProfile? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
              Text(user?.displayName ?? 'Operator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, size: 18, color: Color(0xFF0F4CFF)),
                const SizedBox(width: 8),
                Text(user?.role ?? 'STAFF', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                InkWell(
                  onTap: onLogout,
                  child: const Icon(Icons.logout_rounded, color: Color(0xFF0F4CFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}

