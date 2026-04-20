import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
import '../models.dart';
import 'auth_storage.dart';

class SmartParkingApi {
  SmartParkingApi({required AuthStorage storage})
      : _storage = storage,
        _dio = Dio(
          BaseOptions(
            baseUrl: AppEnv.apiBaseUrl,
            connectTimeout: const Duration(seconds: AppEnv.requestTimeoutSeconds),
            receiveTimeout: const Duration(seconds: AppEnv.requestTimeoutSeconds),
            contentType: Headers.jsonContentType,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
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

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/auth/login/', data: {'username': username, 'password': password});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout({String? refresh, int? sessionId}) async {
    await _dio.post('/auth/logout/', data: {
      if (refresh != null) 'refresh': refresh,
      if (sessionId != null) 'session_id': sessionId,
    });
  }

  Future<UserProfile> me() async {
    final response = await _dio.get('/auth/me/');
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<OcrResult> recognizePlate(XFile image, {String source = 'ENTRY'}) async {
    final bytes = await image.readAsBytes();
    final formData = FormData.fromMap({
      'source': source,
      'image': MultipartFile.fromBytes(bytes, filename: image.name),
    });
    final response = await _dio.post('/camera/anpr/recognize/', data: formData);
    return OcrResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> createEntry(Map<String, dynamic> payload) async {
    final response = await _dio.post('/parking/sessions/entry/', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> prepareExit(Map<String, dynamic> payload) async {
    final response = await _dio.post('/parking/sessions/exit/', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> quickRegister(Map<String, dynamic> payload) async {
    final response = await _dio.post('/parking/vehicles/quick-register/', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<PaymentReceipt> confirmCashPayment(Map<String, dynamic> payload) async {
    final response = await _dio.post('/billing/payments/cash/', data: payload);
    return PaymentReceipt.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<DashboardMetrics> dashboard({String? start, String? end}) async {
    final response = await _dio.get('/analytics/dashboard/', queryParameters: {
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
    return DashboardMetrics.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<AlertItem>> alerts() async {
    final response = await _dio.get('/analytics/alerts/');
    final data = Map<String, dynamic>.from(response.data as Map);
    final results = (data['results'] as List? ?? const []);
    return results.map((item) => AlertItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<Map<String, dynamic>> chatbot(String query) async {
    final response = await _dio.post('/analytics/chat/', data: {'query': query});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> overview() async {
    final response = await _dio.get('/parking/sessions/overview/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<ParkingSessionSummary>> activeSessions() async {
    final response = await _dio.get('/parking/sessions/active/');
    final data = response.data as List;
    return data.map((item) => ParkingSessionSummary.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<PricingPolicyDto> currentPricing() async {
    final response = await _dio.get('/billing/pricing/current/');
    return PricingPolicyDto.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> updatePricing(Map<String, dynamic> payload) async {
    final response = await _dio.post('/billing/pricing/', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> settings() async {
    final response = await _dio.get('/config/settings/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveSetting(Map<String, dynamic> payload) async {
    final response = await _dio.post('/config/settings/', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> queueJson(String kind, Map<String, dynamic> payload) async {
    return {
      'kind': kind,
      'payload': payload,
    };
  }
}

