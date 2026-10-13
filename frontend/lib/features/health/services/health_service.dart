// lib/features/health/services/health_service.dart
//
// Cliente del módulo Salud. Mismo patrón que PetService: token desde
// TokenStorage, timeout, y el campo `error` de la respuesta como mensaje
// para el usuario (formato común de la API: {success, error, detail}).

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../../../core/services/token_storage.dart';
import '../models/health_models.dart';

/// Recursos de historial con CRUD idéntico: `/pets/{id}/health/{recurso}`
enum HealthResource {
  vaccinations,
  dewormings,
  visits,
  medications,
  weights,
  appointments,
  documents,
}

class HealthService {
  HealthService._();

  static const _errorUnauthorized =
      'Sesión expirada. Por favor, vuelve a iniciar sesión.';
  static const _errorNetwork =
      'No se pudo conectar con el servidor. Revisa tu conexión.';

  // Render (plan gratuito) puede tardar en "despertar": margen amplio.
  static const _timeout = Duration(seconds: 30);

  static String _pet(String petId) => '${ApiConfig.baseUrl}/pets/$petId/health';

  // ═══════════════════════════════════════════════════════════════════════
  // RESUMEN / FICHA / RECORDATORIOS
  // ═══════════════════════════════════════════════════════════════════════

  static Future<HealthSummaryModel> getSummary(String petId) async {
    final json = await _send('GET', _pet(petId));
    return HealthSummaryModel.fromJson(json as Map<String, dynamic>);
  }

  static Future<HealthProfileModel> getProfile(String petId) async {
    final json = await _send('GET', '${_pet(petId)}/profile');
    return HealthProfileModel.fromJson(json as Map<String, dynamic>);
  }

  /// PUT reemplaza la ficha completa.
  static Future<HealthProfileModel> saveProfile(
    String petId,
    Map<String, dynamic> body,
  ) async {
    final json = await _send('PUT', '${_pet(petId)}/profile', body: body);
    return HealthProfileModel.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<HealthReminderModel>> getReminders({int days = 30}) async {
    final json = await _send(
      'GET',
      '${ApiConfig.baseUrl}/health/reminders?days=$days',
    );
    return (json as List<dynamic>)
        .map((e) => HealthReminderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD DE HISTORIAL
  // ═══════════════════════════════════════════════════════════════════════

  static Future<List<HealthRecord>> list(
    String petId,
    HealthResource resource, {
    Map<String, String>? query,
  }) async {
    var url = '${_pet(petId)}/${resource.name}';
    if (query != null && query.isNotEmpty) {
      url += '?${Uri(queryParameters: query).query}';
    }
    final json = await _send('GET', url);
    return (json as List<dynamic>)
        .map((e) => HealthRecord(e as Map<String, dynamic>))
        .toList();
  }

  static Future<HealthRecord> create(
    String petId,
    HealthResource resource,
    Map<String, dynamic> body,
  ) async {
    final json = await _send(
      'POST',
      '${_pet(petId)}/${resource.name}',
      body: body,
    );
    return HealthRecord(json as Map<String, dynamic>);
  }

  /// PATCH: solo los campos enviados (null borra un campo opcional).
  static Future<HealthRecord> update(
    String petId,
    HealthResource resource,
    String recordId,
    Map<String, dynamic> changes,
  ) async {
    final json = await _send(
      'PATCH',
      '${_pet(petId)}/${resource.name}/$recordId',
      body: changes,
    );
    return HealthRecord(json as Map<String, dynamic>);
  }

  static Future<void> delete(
    String petId,
    HealthResource resource,
    String recordId,
  ) => _send('DELETE', '${_pet(petId)}/${resource.name}/$recordId');

  // ═══════════════════════════════════════════════════════════════════════
  // COMPARTIR CON EL VETERINARIO
  // ═══════════════════════════════════════════════════════════════════════

  static Future<List<HealthShareModel>> listShares(String petId) async {
    final json = await _send('GET', '${_pet(petId)}/shares');
    return (json as List<dynamic>)
        .map((e) => HealthShareModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<HealthShareModel> createShare(String petId, int hours) async {
    final json = await _send(
      'POST',
      '${_pet(petId)}/shares',
      body: {'expires_in_hours': hours},
    );
    return HealthShareModel.fromJson(json as Map<String, dynamic>);
  }

  static Future<void> revokeShare(String petId, String shareId) =>
      _send('DELETE', '${_pet(petId)}/shares/$shareId');

  // ═══════════════════════════════════════════════════════════════════════
  // HTTP
  // ═══════════════════════════════════════════════════════════════════════

  static Future<dynamic> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw const HealthServiceException(
        _errorUnauthorized,
        detail: 'no_token',
      );
    }

    final request = http.Request(method, Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(_timeout),
      ).timeout(_timeout);
    } catch (e) {
      throw HealthServiceException(_errorNetwork, detail: e.toString());
    }

    final code = response.statusCode;
    if (code == 204 || (code >= 200 && code < 300 && response.body.isEmpty)) {
      return null;
    }
    if (code >= 200 && code < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (code == 401) {
      throw const HealthServiceException(
        _errorUnauthorized,
        detail: 'token_rejected',
      );
    }

    throw _errorFrom(response);
  }

  static HealthServiceException _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        // Formato propio de la API
        if (body['error'] is String) {
          return HealthServiceException(
            body['error'] as String,
            detail: body['detail']?.toString(),
            statusCode: response.statusCode,
          );
        }
        // Validación de FastAPI (422): {"detail": [ ... ]}
        if (response.statusCode == 422) {
          return HealthServiceException(
            'Hay datos inválidos. Revisa el formulario.',
            detail: body['detail']?.toString(),
            statusCode: 422,
          );
        }
      }
    } catch (_) {}
    return HealthServiceException(
      'Error en el servidor. Intenta de nuevo.',
      detail: 'status_${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}

class HealthServiceException implements Exception {
  final String message;
  final String? detail;
  final int? statusCode;

  const HealthServiceException(this.message, {this.detail, this.statusCode});

  @override
  String toString() => 'HealthServiceException: $message (detail: $detail)';
}
