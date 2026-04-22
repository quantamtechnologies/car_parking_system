import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/offline_queue.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required SmartParkingApi apiClient,
    required AuthStorage storage,
    required OfflineQueueService offlineQueue,
  })  : _apiClient = apiClient,
        _storage = storage,
        _offlineQueue = offlineQueue;

  final SmartParkingApi _apiClient;
  final AuthStorage _storage;
  final OfflineQueueService _offlineQueue;

  bool initialized = false;
  bool loading = false;
  UserProfile? user;
  String? accessToken;
  String? refreshToken;
  int? sessionId;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  bool get isAdmin => user?.role == 'ADMIN';

  Future<void> bootstrap() async {
    user = await _storage.readUser();
    accessToken = await _storage.readAccessToken();
    refreshToken = await _storage.readRefreshToken();
    sessionId = await _storage.readSessionId();
    if ((accessToken == null || accessToken!.isEmpty) && (refreshToken?.isNotEmpty ?? false)) {
      try {
        final refreshed = await _apiClient.refreshSession();
        if (refreshed) {
          accessToken = await _storage.readAccessToken();
          refreshToken = await _storage.readRefreshToken();
        } else {
          await _storage.clear();
          user = null;
          accessToken = null;
          refreshToken = null;
          sessionId = null;
        }
      } catch (_) {
        // If recovery fails, the existing session state is still safe to clear below.
      }
    }
    initialized = true;
    notifyListeners();
    if (isAuthenticated && user == null) {
      try {
        user = await _apiClient.me();
      } catch (_) {
        await logout(localOnly: true);
      }
    }
    if (isAuthenticated) {
      try {
        await _offlineQueue.flush(_apiClient);
      } catch (_) {
        // Offline sync is best-effort.
      }
    }
  }

  Future<void> login(String username, String password) async {
    loading = true;
    notifyListeners();
    try {
      final data = await _apiClient.login(username, password);
      accessToken = data['access']?.toString();
      refreshToken = data['refresh']?.toString();
      sessionId = data['session_id'] is int ? data['session_id'] as int : int.tryParse(data['session_id']?.toString() ?? '');
      user = UserProfile.fromJson(Map<String, dynamic>.from(data['user'] as Map));
      if (accessToken != null && refreshToken != null && user != null && sessionId != null) {
        await _storage.saveSession(
          accessToken: accessToken!,
          refreshToken: refreshToken!,
          user: user!,
          sessionId: sessionId!,
        );
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool localOnly = false}) async {
    loading = true;
    notifyListeners();
    try {
      if (!localOnly) {
        final latestRefreshToken = await _storage.readRefreshToken();
        final tokenToUse = latestRefreshToken ?? refreshToken;
        if (tokenToUse != null) {
          await _apiClient.logout(refresh: tokenToUse, sessionId: sessionId);
        }
      }
    } finally {
      accessToken = null;
      refreshToken = null;
      user = null;
      sessionId = null;
      await _storage.clear();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> queueIfOffline(String kind, Map<String, dynamic> payload) async {
    await _offlineQueue.enqueue(kind, payload);
  }
}
