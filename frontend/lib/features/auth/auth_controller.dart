import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AuthController extends ChangeNotifier {
  // Configuración del endpoint de tu backend de FastAPI
  final String _baseUrl = "http://127.0.0.1:8000/auth";

  bool isLoginMode = true;
  bool isLoading = false;
  String? errorMessage;

  void toggleMode() {
    isLoginMode = !isLoginMode;
    errorMessage = null;
    notifyListeners();
  }

  // Lógica REAL para autenticación por Email / Username
  Future<bool> authenticateWithEmail({
    required String
    identity, // Cambiado de 'email' a 'identity' para admitir username
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (isLoginMode) {
        // 1. Petición de LOGIN a FastAPI
        final response = await http.post(
          Uri.parse('$_baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'identity': identity.trim(), 'password': password}),
        );

        if (response.statusCode == 200) {
          // Aquí puedes guardar el token recibido en el almacenamiento seguro más adelante
          final data = jsonDecode(response.body);
          debugPrint("Token recibido: ${data['access_token']}");

          isLoading = false;
          notifyListeners();
          return true;
        } else {
          final errorData = jsonDecode(response.body);
          throw errorData['detail'] ?? 'Error al iniciar sesión';
        }
      } else {
        // 2. Petición de REGISTRO a FastAPI
        final response = await http.post(
          Uri.parse('$_baseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': identity
                .trim(), // En registro, asumimos que 'identity' es estrictamente un email
            'password': password,
          }),
        );

        if (response.statusCode == 201) {
          isLoading = false;
          notifyListeners();
          return true; // Registro exitoso
        } else {
          final errorData = jsonDecode(response.body);
          throw errorData['detail'] ?? 'Error en el registro';
        }
      }
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkEmailVerification(String email) async {
    // No encendemos el isLoading global para no bloquear toda la pantalla,
    // ya que la vista maneja su propio estado interno (_isChecking)

    try {
      // 1. Apuntamos al endpoint de tu FastAPI usando la configuración de IP centralizada
      final url = Uri.parse(
        '$_baseUrl/auth/check-verification?email=${Uri.encodeComponent(email)}',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Asumiendo que tu FastAPI devuelve un JSON como: {"verified": true}
        return data['verified'] ?? false;
      }

      return false;
    } catch (e) {
      // Si hay un error de red (ej. timeout), lo propagamos para que la burbuja lo capture
      rethrow;
    }
  }

  // Lógica REAL para Google Auth conectado directamente a Supabase
  Future<bool> signInWithGoogle() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Le pedimos la URL de Google a tu FastAPI usando la IP dinámica
      final response = await http.get(Uri.parse('$_baseUrl/google-login'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String authUrl = data['url'];

        // 2. Abrimos el navegador web del teléfono para mostrar el menú de cuentas de Google
        final Uri uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          isLoading = false;
          notifyListeners();
          return true;
        } else {
          throw "No se pudo abrir el navegador de autenticación.";
        }
      } else {
        throw "Error al conectar con el servidor de autenticación.";
      }
    } catch (e) {
      isLoading = false;
      errorMessage = "Error de Google: $e";
      notifyListeners();
      return false;
    }
  }

  void signInWithApple() {
    // Implementación futura
  }
}
