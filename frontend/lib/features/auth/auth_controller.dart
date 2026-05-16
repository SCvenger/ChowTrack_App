import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  bool isLoginMode = true;
  bool isLoading = false;
  String? errorMessage;

  void toggleMode() {
    isLoginMode = !isLoginMode;
    errorMessage = null; // Limpiamos errores previos al cambiar de pantalla
    notifyListeners();
  }

  // Lógica para autenticación por Email
  Future<bool> authenticateWithEmail({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (isLoginMode) {
        await Future.delayed(
          const Duration(seconds: 5),
        ); // Simulación de tiempo de respuesta
      } else {
        await Future.delayed(const Duration(seconds: 5));
      }

      isLoading = false;
      notifyListeners();
      return true; // Autenticación exitosa
    } catch (e) {
      isLoading = false;
      errorMessage = e
          .toString(); // Captura el error real (ej: "Contraseña incorrecta")
      notifyListeners();
      return false; // Falló el intento
    }
  }

  // Lógica para Google Auth
  Future<bool> signInWithGoogle() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 5));
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = "Error de Google: $e";
      notifyListeners();
      return false;
    }
  }

  // Apple se quedara en blanco por ahora
  void signInWithApple() {
    // Implementación futura
  }
}
