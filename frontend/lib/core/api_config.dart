class ApiConfig {
  
  static const String baseUrl = 'https://chowtrack.onrender.com';
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