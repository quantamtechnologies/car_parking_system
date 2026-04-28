import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/controllers/auth_controller.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/entry/entry_screen.dart';
import 'features/entry/registration_screen.dart';
import 'features/exit/exit_screen.dart';
import 'features/home/app_shell.dart';
import 'features/receipts/receipts_screen.dart';
import 'features/payment/payment_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/transactions/transaction_details_screen.dart';

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
        return authController.isAdmin ? '/admin' : '/';
      }
      if (authController.isAuthenticated &&
          state.matchedLocation == '/admin' &&
          !authController.isAdmin) {
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
        path: '/receipts',
        builder: (context, state) => const ReceiptsScreen(),
      ),
      GoRoute(
        path: '/receipts/view',
        builder: (context, state) => TransactionDetailsScreen(
          transaction: state.extra as TransactionRecord,
          receiptMode: true,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/entry/register',
            builder: (context, state) {
              final extra =
                  Map<String, dynamic>.from(state.extra as Map? ?? const {});
              final plate = extra['plate']?.toString() ??
                  state.uri.queryParameters['plate'] ??
                  '';
              final vehicleType = extra['vehicle_type']?.toString() ??
                  state.uri.queryParameters['vehicle_type'] ??
                  'CAR';
              return VehicleRegistrationScreen(
                plateNumber: plate,
                initialVehicleType: vehicleType,
              );
            },
          ),
          GoRoute(
            path: '/',
            builder: (context, state) {
              final extra =
                  Map<String, dynamic>.from(state.extra as Map? ?? const {});
              return DashboardScreen(
                initialPlate: extra['plate']?.toString() ?? '',
              );
            },
          ),
          GoRoute(
              path: '/dashboard',
              builder: (context, state) {
                final extra =
                    Map<String, dynamic>.from(state.extra as Map? ?? const {});
                return DashboardScreen(
                  initialPlate: extra['plate']?.toString() ?? '',
                );
              }),
          GoRoute(
            path: '/entry',
            builder: (context, state) {
              final extra =
                  Map<String, dynamic>.from(state.extra as Map? ?? const {});
              return EntryScreen(
                initialPlate: extra['plate']?.toString() ?? '',
                initialVehicleType: extra['vehicle_type']?.toString() ?? 'CAR',
              );
            },
          ),
          GoRoute(
              path: '/exit', builder: (context, state) => const ExitScreen()),
          GoRoute(
            path: '/payment',
            builder: (context, state) => PaymentScreen(
              initialPayload: state.extra == null
                  ? null
                  : Map<String, dynamic>.from(state.extra as Map),
            ),
          ),
          GoRoute(
            path: '/transactions/details',
            builder: (context, state) => TransactionDetailsScreen(
              transaction: state.extra as TransactionRecord,
            ),
          ),
          GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen()),
          GoRoute(
              path: '/admin', builder: (context, state) => const AdminScreen()),
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
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context)
                .textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.08),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
