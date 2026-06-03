// lib/features/profile/services/profile_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../../../core/services/token_storage.dart';
import '../models/profile_model.dart';

class ProfileServiceException implements Exception {
  final String message;
  const ProfileServiceException(this.message);

  @override
  String toString() => 'ProfileServiceException: $message';
}

class ProfileService {
  static Future<ProfileModel> getMyProfile() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw const ProfileServiceException('No hay sesión activa');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProfileModel.fromJson(data);
    }

    if (response.statusCode == 401) {
      throw const ProfileServiceException('Sesión expirada');
    }

    throw const ProfileServiceException('Error al cargar el perfil');
  }
}