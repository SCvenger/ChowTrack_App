// lib/features/map/services/map_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../../../core/services/token_storage.dart';
import '../models/map_pet_model.dart';

class MapServiceException implements Exception {
  final String message;
  const MapServiceException(this.message);

  @override
  String toString() => 'MapServiceException: $message';
}

class MapService {
  // ── GET /map/pets ──────────────────────────────────────────────────────────
  static Future<List<MapPetModel>> getPetsNearby(
    double lat,
    double lng, {
    int radiusMeters = 5000,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw const MapServiceException('No hay sesión activa');

    final uri = Uri.parse('${ApiConfig.baseUrl}/map/pets').replace(
      queryParameters: {
        'lat':    lat.toString(),
        'lng':    lng.toString(),
        'radius': radiusMeters.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => MapPetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401) {
      throw const MapServiceException('Sesión expirada');
    }

    throw MapServiceException(
      'Error al cargar el mapa (${response.statusCode})',
    );
  }
}