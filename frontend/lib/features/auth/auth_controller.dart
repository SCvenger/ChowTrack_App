
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_config.dart';
import '../../core/services/pet_service.dart';
import '../../core/services/token_storage.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthController extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  bool isLoginMode = true;
  String? errorMessage;
  String? userId;
  bool? _hasPets;
  bool? get hasPets => _hasPets;

  AuthState get state => _state;
  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _state == AuthState.authenticated;

  AuthController() {
    _checkExistingSession();
  }


  // Sesion existente

  Future<void> _checkExistingSession() async {
    final hasSession = await TokenStorage.hasValidSession();

    if (hasSession) {
      userId = await TokenStorage.getUserId();
      await _resolveDestination();         
      _setState(AuthState.authenticated);
    } else {
      _setState(AuthState.unauthenticated);
    }
  }

  // Destimo POST-AUTH

  Future<void> _resolveDestination() async {
    try {
      final pets = await PetService.getMyPets();
      _hasPets = pets.isNotEmpty;
    } catch (_) {
      _hasPets = false;
    }
  }

  void markHasPets() {
    _hasPets = true;
    notifyListeners();
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void toggleMode() {
    isLoginMode = !isLoginMode;
    errorMessage = null;
    notifyListeners();
  }


  // Autemticacion con email o username


  Future<bool> authenticateWithEmail({
    required String identity,
    required String password,
  }) async {
    _setState(AuthState.loading);
    errorMessage = null;

    try {
      if (isLoginMode) {
        return await _login(identity, password);
      } else {
        return await _register(identity, password);
      }
    } catch (e) {
      errorMessage = e.toString().replaceAll("Exception: ", "");
      _setState(AuthState.error);
      return false;
    }
  }

  Future<bool> _login(String identity, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identity': identity.trim(),
        'password': password,
      }),
    ).timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await TokenStorage.saveSession(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: data['user_id'],
      );

      userId = data['user_id'];
      await _resolveDestination();         
      _setState(AuthState.authenticated);
      return true;
    } else {
      final errorData = jsonDecode(response.body);
      throw errorData['detail'] ?? 'Error al iniciar sesión';
    }
  }

  Future<bool> _register(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.registerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    ).timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 201) {

      _setState(AuthState.unauthenticated);
      return true;
    } else {
      final errorData = jsonDecode(response.body);
      throw errorData['detail'] ?? 'Error en el registro';
    }
  }

  // Verificacion de email

  Future<bool> checkEmailVerification(String email) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.checkVerificationUrl}?email=${Uri.encodeComponent(email)}',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isVerified = data['verified'] ?? false;

        if (isVerified && data['access_token'] != null) {
          await TokenStorage.saveSession(
            accessToken: data['access_token'],
            refreshToken: data['refresh_token'],
            userId: data['user_id'],
          );
          userId = data['user_id'];
          _hasPets = false;
          _setState(AuthState.authenticated);
        }

        return isVerified;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }


  // Google OAuth
  Future<bool> initiateGoogleAuth() async {
    _setState(AuthState.loading);
    errorMessage = null;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.googleLoginUrl),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String authUrl = data['url'];

        final Uri uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _setState(AuthState.unauthenticated);
          return true;
        } else {
          throw "No se pudo abrir el navegador de autenticación.";
        }
      } else {
        throw "Error al conectar con el servidor de autenticación.";
      }
    } catch (e) {
      errorMessage = "Error de Google: $e";
      _setState(AuthState.error);
      return false;
    }
  }

  Future<void> handleOAuthCallback(String code) async {
    _setState(AuthState.loading);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/google-callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await TokenStorage.saveSession(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          userId: data['user_id'],
        );

        userId = data['user_id'];
        await _resolveDestination();
        _setState(AuthState.authenticated);
      } else {
        throw "Error al procesar el callback de Google";
      }
    } catch (e) {
      errorMessage = "Error en callback: $e";
      _setState(AuthState.error);
    }
  }

  // Logout

  Future<void> logout() async {
    await TokenStorage.clearAll();
    userId = null;
    _hasPets = null;
    _setState(AuthState.unauthenticated);
  }

  Future<void> signInWithApple() async {
    errorMessage = "Apple Sign In aún no implementado";
    notifyListeners();
  }
}