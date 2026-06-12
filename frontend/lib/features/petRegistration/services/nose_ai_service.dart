
// ═════════════════════════════════════════════════════════════════════════════
// lib/features/petRegistration/services/nose_ai_service.dart
// ═════════════════════════════════════════════════════════════════════════════
 
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../../../core/services/token_storage.dart';
import '../models/nose_result_model.dart';
 
class NoseAiException implements Exception {
  final String message;
  const NoseAiException(this.message);
 
  @override
  String toString() => 'NoseAiException: $message';
}
 
class NoseAiService {
  // ── POST /nose/register ────────────────────────────────────────────────────
  static Future<NoseRegisterResult> registerNose({
    required String petId,
    required File imageFile,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw const NoseAiException('No hay sesión activa');
 
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
 
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/nose/register'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pet_id': petId,
        'image_base64': base64Image,
      }),
    ).timeout(const Duration(seconds: 30)); // IA puede tardar
 
    if (response.statusCode == 200) {
      return NoseRegisterResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
 
    // Errores de validación con mensaje del backend
    final body = _safeDecode(response.body);
    final msg = body?['message'] as String? ?? 'Error al registrar la huella';
    throw NoseAiException(msg);
  }
 
  // ── POST /nose/identify ────────────────────────────────────────────────────
  static Future<NoseMatchResult> identifyNose({
    required File imageFile,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw const NoseAiException('No hay sesión activa');
 
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
 
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/nose/identify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'image_base64': base64Image}),
    ).timeout(const Duration(seconds: 30));
 
    if (response.statusCode == 200) {
      return NoseMatchResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
 
    final body = _safeDecode(response.body);
    final msg = body?['message'] as String? ?? 'Error al identificar';
    throw NoseAiException(msg);
  }
 
  static Map<String, dynamic>? _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}