class ApiConfig {
  // URLs base según el entorno
  static const String _devBaseUrl = 'http://127.0.0.1:8000'; // Android Emulator
  static const String _prodBaseUrl = 'https://api.chowtrack.com'; // Producción

  static const bool _isProduction = false;

  static String get baseUrl => _isProduction ? _prodBaseUrl : _devBaseUrl;
  static String get authEndpoint => '$baseUrl/auth';

  // Configuración de timeout para requests HTTP
  static const Duration requestTimeout = Duration(seconds: 30);

  // Endpoints específicos
  static String get loginUrl => '$authEndpoint/login';
  static String get registerUrl => '$authEndpoint/register';
  static String get googleLoginUrl => '$authEndpoint/google-login';
  static String get checkVerificationUrl => '$authEndpoint/check-verification';

  static String customDevUrl(String ipAddress, {int port = 8000}) {
    return 'http://$ipAddress:$port';
  }
}