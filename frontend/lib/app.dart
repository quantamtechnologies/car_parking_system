import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/controllers/auth_controller.dart';
import 'core/theme.dart';
import 'features/camera/camera_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/entry/entry_screen.dart';
import 'features/exit/exit_screen.dart';
import 'features/home/app_shell.dart';
import 'features/payment/payment_screen.dart';
import 'features/reports/reports_screen.dart';

GoRouter buildRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authController,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final initialized = authController.initialized;
      if (!initialized) return null;
      if (!authController.isAuthenticated && !loggingIn) {
        return '/login';
      }
      if (authController.isAuthenticated && loggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/camera-entry',
        builder: (context, state) {
          final extra = Map<String, dynamic>.from(state.extra as Map? ?? const {});
          return CameraScreen(
            source: extra['source']?.toString() ?? 'ENTRY',
            initialPlate: extra['plate']?.toString() ?? '',
          );
        },
      ),
      GoRoute(
        path: '/camera-exit',
        builder: (context, state) {
          final extra = Map<String, dynamic>.from(state.extra as Map? ?? const {});
          return CameraScreen(
            source: extra['source']?.toString() ?? 'EXIT',
            initialPlate: extra['plate']?.toString() ?? '',
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/entry', builder: (context, state) => const EntryScreen()),
          GoRoute(path: '/exit', builder: (context, state) => const ExitScreen()),
          GoRoute(
            path: '/payment',
            builder: (context, state) => PaymentScreen(
              initialSession: state.extra == null ? null : Map<String, dynamic>.from(state.extra as Map),
            ),
          ),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
        ],
      ),
    ],
  );
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(authController);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Smart Parking POS',
      theme: parkingTheme(),
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.08)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
