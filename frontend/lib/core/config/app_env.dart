class AppEnv {
  static const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const _defaultApiBaseUrl = 'http://127.0.0.1:8001/api';

  static String get apiBaseUrl => _rawApiBaseUrl.isNotEmpty ? _rawApiBaseUrl : _defaultApiBaseUrl;
  static bool get hasExplicitApiBaseUrl => _rawApiBaseUrl.isNotEmpty;

  static const appName = 'Smart Parking POS';
  static const requestTimeoutSeconds = 20;
}
