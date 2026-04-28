import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../models.dart';
import 'auth_storage.dart';

class SmartParkingApi {
  SmartParkingApi({required AuthStorage storage})
      : _storage = storage,
        _dio = Dio(
          BaseOptions(
            baseUrl: AppEnv.apiBaseUrl,
            connectTimeout:
                const Duration(seconds: AppEnv.requestTimeoutSeconds),
            receiveTimeout:
                const Duration(seconds: AppEnv.requestTimeoutSeconds),
            contentType: Headers.jsonContentType,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }
          final token = await _storage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AuthStorage _storage;
  final Dio _dio;
  Future<bool>? _refreshFuture;
  Future<void> Function()? _sessionExpiredHandler;

  void setSessionExpiredHandler(Future<void> Function()? handler) {
    _sessionExpiredHandler = handler;
  }

  Options _skipAuthOptions() => Options(extra: const {'skipAuth': true});

  Map<String, dynamic> _asMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  String _normalizePlate(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() action, {
    bool allowRefresh = true,
  }) async {
    try {
      return await action();
    } on DioException catch (error) {
      final unauthorized = error.response?.statusCode == 401;
      if (allowRefresh && unauthorized) {
        final refreshed = await refreshSession();
        if (refreshed) {
          return await action();
        }
        await _expireSession();
      }
      rethrow;
    }
  }

  Future<void> _expireSession() async {
    if (_sessionExpiredHandler != null) {
      await _sessionExpiredHandler!.call();
    }
  }

  Future<bool> _refreshAccessTokenInternal() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh/',
        data: {'refresh': refreshToken},
        options: _skipAuthOptions(),
      );
      final data = _asMap(response.data);
      final accessToken = data['access']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      final nextRefreshToken = data['refresh']?.toString() ?? refreshToken;
      await _storage.saveTokens(
          accessToken: accessToken, refreshToken: nextRefreshToken);
      return true;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> refreshSession() {
    final existing = _refreshFuture;
    if (existing != null) {
      return existing;
    }

    late Future<bool> future;
    future = _refreshAccessTokenInternal();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
    return future;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post(
      '/auth/login/',
      data: {'username': username, 'password': password},
      options: _skipAuthOptions(),
    );
    return _asMap(response.data);
  }

  Future<void> logout({String? refresh, int? sessionId}) async {
    await _send(() => _dio.post('/auth/logout/', data: {
          if (refresh != null) 'refresh': refresh,
          if (sessionId != null) 'session_id': sessionId,
        }));
  }

  Future<UserProfile> me() async {
    final response = await _send(() => _dio.get('/auth/me/'));
    return UserProfile.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> createEntry(Map<String, dynamic> payload) async {
    final response =
        await _send(() => _dio.post('/parking/sessions/entry/', data: payload));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> prepareExit(Map<String, dynamic> payload) async {
    final response =
        await _send(() => _dio.post('/parking/sessions/exit/', data: payload));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> quickRegister(
      Map<String, dynamic> payload) async {
    final response = await _send(
        () => _dio.post('/parking/vehicles/quick-register/', data: payload));
    return _asMap(response.data);
  }

  Future<PaymentRecord> confirmCashPayment(Map<String, dynamic> payload) async {
    final response =
        await _send(() => _dio.post('/billing/payments/cash/', data: payload));
    return PaymentRecord.fromJson(_asMap(response.data));
  }

  Future<List<PaymentRecord>> payments({
    String ordering = '-confirmed_at',
    int pageSize = 10,
  }) async {
    final response = await _send(
      () => _dio.get(
        '/billing/payments/',
        queryParameters: {
          'ordering': ordering,
          'page_size': pageSize,
        },
      ),
    );
    final data = response.data;
    final results = data is Map<String, dynamic> && data['results'] is List
        ? data['results'] as List
        : data as List;
    return results
        .map((item) =>
            PaymentRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<DashboardMetrics> dashboard({String? start, String? end}) async {
    final response =
        await _send(() => _dio.get('/analytics/dashboard/', queryParameters: {
              if (start != null) 'start': start,
              if (end != null) 'end': end,
            }));
    return DashboardMetrics.fromJson(_asMap(response.data));
  }

  Future<List<AlertItem>> alerts() async {
    final response = await _send(() => _dio.get('/analytics/alerts/'));
    final data = _asMap(response.data);
    final results = (data['results'] as List? ?? const []);
    return results
        .map((item) =>
            AlertItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> chatbot(String query) async {
    final response = await _send(
        () => _dio.post('/analytics/chat/', data: {'query': query}));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> overview() async {
    final response = await _send(() => _dio.get('/parking/sessions/overview/'));
    return _asMap(response.data);
  }

  Future<List<VehicleRecord>> vehicles({
    String ordering = '-created_at',
    String? search,
  }) async {
    final response = await _send(
      () => _dio.get(
        '/parking/vehicles/',
        queryParameters: {
          'ordering': ordering,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      ),
    );
    final data = response.data;
    final results = data is Map<String, dynamic> && data['results'] is List
        ? data['results'] as List
        : data as List;
    return results
        .map((item) =>
            VehicleRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<VehicleRecord?> vehicleByPlate(String plate) async {
    final normalized = _normalizePlate(plate);
    if (normalized.isEmpty) return null;

    final matches = await vehicles(search: normalized);
    for (final vehicle in matches) {
      if (_normalizePlate(vehicle.plateNumber) == normalized) {
        return vehicle;
      }
    }
    return null;
  }

  Future<List<ParkingSessionSummary>> activeSessions() async {
    final response = await _send(() => _dio.get('/parking/sessions/active/'));
    final data = response.data as List;
    return data
        .map((item) => ParkingSessionSummary.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<ParkingSessionSummary>> sessions({
    String ordering = '-created_at',
    int pageSize = 5,
  }) async {
    final response = await _send(
      () => _dio.get(
        '/parking/sessions/',
        queryParameters: {
          'ordering': ordering,
          'page_size': pageSize,
        },
      ),
    );
    final data = response.data;
    final results = data is Map<String, dynamic> && data['results'] is List
        ? data['results'] as List
        : data as List;
    return results
        .map((item) => ParkingSessionSummary.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<PricingPolicyDto> currentPricing() async {
    final response = await _send(() => _dio.get('/billing/pricing/current/'));
    return PricingPolicyDto.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> updatePricing(
      Map<String, dynamic> payload) async {
    final response =
        await _send(() => _dio.post('/billing/pricing/', data: payload));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> settings() async {
    final response = await _send(() => _dio.get('/config/settings/'));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> saveSetting(Map<String, dynamic> payload) async {
    final response =
        await _send(() => _dio.post('/config/settings/', data: payload));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> queueJson(
      String kind, Map<String, dynamic> payload) async {
    return {
      'kind': kind,
      'payload': payload,
    };
  }
}
