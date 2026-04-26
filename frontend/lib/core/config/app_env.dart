class AppEnv {
  static const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const _defaultApiBaseUrl = 'https://savingsutl-production.up.railway.app/api';

  static String get apiBaseUrl => _rawApiBaseUrl.isNotEmpty ? _rawApiBaseUrl : _defaultApiBaseUrl;
  static bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;
  static bool get hasExplicitApiBaseUrl => _rawApiBaseUrl.isNotEmpty;

  static const appName = 'Smart Parking POS';
  static const requestTimeoutSeconds = 20;
}
