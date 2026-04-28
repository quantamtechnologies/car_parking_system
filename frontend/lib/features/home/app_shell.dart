import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      const ParkingBottomNavItem(
          path: '/', icon: Icons.home_rounded, label: 'Home'),
      const ParkingBottomNavItem(
          path: '/entry', icon: Icons.directions_car_rounded, label: 'Entry'),
      const ParkingBottomNavItem(
          path: '/exit', icon: Icons.exit_to_app_rounded, label: 'Exit'),
      const ParkingBottomNavItem(
          path: '/payment', icon: Icons.payments_rounded, label: 'Payments'),
      const ParkingBottomNavItem(
          path: '/reports', icon: Icons.bar_chart_rounded, label: 'Reports'),
    ];
    final normalizedPath = _normalizePath(currentPath);
    final selectedIndex = _selectedIndexForPath(normalizedPath);

    return Scaffold(
      backgroundColor: Colors.white,
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

String _normalizePath(String path) {
  if (path == '/dashboard') return '/';
  return path;
}
