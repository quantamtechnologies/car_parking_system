import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/controllers/auth_controller.dart';
import 'core/services/api_client.dart';
import 'core/services/auth_storage.dart';
import 'core/services/offline_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kReleaseMode && !AppEnv.hasExplicitApiBaseUrl) {
    runApp(const _MissingApiBaseUrlApp());
    return;
  }

  final storage = AuthStorage();
  final apiClient = SmartParkingApi(storage: storage);
  final offlineQueue = OfflineQueueService(storage: await OfflineQueueStorage.create());
  final authController = AuthController(
    apiClient: apiClient,
    storage: storage,
    offlineQueue: offlineQueue,
  );
  await authController.bootstrap();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storage),
        Provider.value(value: apiClient),
        Provider.value(value: offlineQueue),
        ChangeNotifierProvider.value(value: authController),
      ],
      child: SmartParkingApp(authController: authController),
    ),
  );
}

class _MissingApiBaseUrlApp extends StatelessWidget {
  const _MissingApiBaseUrlApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Parking POS',
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off_rounded, size: 56, color: Color(0xFF0F4CFF)),
                  SizedBox(height: 16),
                  Text(
                    'API_BASE_URL is missing',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Rebuild the web app with --dart-define=API_BASE_URL=https://your-api.example.com/api before deployment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
