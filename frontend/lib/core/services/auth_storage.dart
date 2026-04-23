import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class AuthStorage {
  AuthStorage({SharedPreferences? preferences})
      : _prefsFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;
  static const _accessTokenKey = 'smart_parking_access_token';
  static const _refreshTokenKey = 'smart_parking_refresh_token';
  static const _userKey = 'smart_parking_user';
  static const _sessionIdKey = 'smart_parking_session_id';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserProfile user,
    required int sessionId,
  }) async {
    await saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    final prefs = await _prefsFuture;
    await prefs.setString(
        _userKey,
        jsonEncode({
          'id': user.id,
          'username': user.username,
          'role': user.role,
          'is_superuser': user.isSuperuser,
          'first_name': user.firstName,
          'last_name': user.lastName,
          'email': user.email,
          'phone_number': user.phoneNumber,
          'employee_code': user.employeeCode,
        }));
    await prefs.setString(_sessionIdKey, sessionId.toString());
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await _prefsFuture;
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> readAccessToken() async =>
      (await _prefsFuture).getString(_accessTokenKey);

  Future<String?> readRefreshToken() async =>
      (await _prefsFuture).getString(_refreshTokenKey);

  Future<int?> readSessionId() async {
    final value = (await _prefsFuture).getString(_sessionIdKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<UserProfile?> readUser() async {
    final value = (await _prefsFuture).getString(_userKey);
    if (value == null || value.isEmpty) return null;
    return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map));
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_sessionIdKey);
  }
}
