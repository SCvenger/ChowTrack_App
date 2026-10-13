class ApiConfig {
  // Producción por defecto. Para probar contra el backend local:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  // (10.0.2.2 = la PC vista desde el emulador de Android Studio)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://chowtrack.onrender.com',
  );
  static const String stadiaApiKey = '654011a9-4d49-49e1-8296-350b3370da56';
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
