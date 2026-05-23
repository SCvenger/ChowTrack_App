import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_config.dart';
import '../../../core/services/token_storage.dart';
import '../../features/petRegistration/models/pet_model.dart';
import '../../features/petRegistration/models/pet_registration_data.dart';

class PetService {
  // Instancia singleton de Supabase (inicializada lazy)
  static Supabase? _supabaseInstance;

  // Getter lazy — inicializa solo cuando se accede por primera vez
  static Future<Supabase> _getSupabase() async {
    if (_supabaseInstance != null) {
      return _supabaseInstance!;
    }

    // Inicializar Supabase UNA SOLA VEZ
    try {
      _supabaseInstance = await Supabase.initialize(
        url: const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://uqxazpzvgwifgcrgrtyg.supabase.co', 
        ),
        anonKey: const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeGF6cHp2Z3dpZmdjcmdydHlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3OTA1NTUsImV4cCI6MjA5NDM2NjU1NX0.EB4Vd5yhUtpibT9WLaQVERC0h24A7Fn9tjD02rsoJyY',
        ),
        storageOptions: const StorageClientOptions(
          retryAttempts: 3,
        ),
      );
      return _supabaseInstance!;
    } catch (e) {
      throw PetServiceException(
        'No se pudo inicializar Supabase',
        detail: e.toString(),
      );
    }
  }

  static const String _errorUploadFailed = 'No se pudo subir la foto. Verifica tu conexión.';
  static const String _errorCreateFailed = 'No se pudo registrar la mascota.';
  static const String _errorUnauthorized = 'Sesión expirada. Por favor, vuelve a iniciar sesión.';
  static const String _errorServer = 'Error en el servidor. Intenta de nuevo.';


  // Subir foto al Storage de Supabase


  static Future<String> uploadPetPhoto(File photo, String userId) async {
    try {
      final supabase = await _getSupabase();
      final extension = photo.path.split('.').last.toLowerCase();
      final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$userId/$fileName';

      await supabase.client.storage.from('pets').upload(
        path,
        photo,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );

      return supabase.client.storage.from('pets').getPublicUrl(path);
    } on StorageException catch (e) {
      throw PetServiceException(_errorUploadFailed, detail: e.message);
    } catch (e) {
      throw PetServiceException(_errorUploadFailed, detail: e.toString());
    }
  }

  //  crea mascota en FastAPI

  static Future<PetModel> createPet(
    PetRegistrationData data,
    String userId,
  ) async {
    // Subir foto primero
    final photoUrl = await uploadPetPhoto(data.photo, userId);

    // Obtener JWT
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw PetServiceException(_errorUnauthorized, detail: 'no_token_in_storage');
    }

    // Construir body
    final body = jsonEncode({
      'name': data.name,
      'breed': data.breed,
      'age_years': data.age,
      'photo_url': photoUrl,
      'phone': data.phone,
    });
 
    // Llamar FastAPI
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/pets/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw PetServiceException(
          'La solicitud tardó demasiado. Verifica tu conexión.',
          detail: 'request_timeout',
        ),
      );
 
      return _parseCreateResponse(response);
    } on PetServiceException {
      rethrow;
    } catch (e) {
      throw PetServiceException(_errorCreateFailed, detail: e.toString());
    }
  }
 
  // lista mascotas del usuario
 
  static Future<List<PetModel>> getMyPets() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw PetServiceException(_errorUnauthorized, detail: 'no_token_in_storage');
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/pets/'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
        return raw
            .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 401) {
        throw PetServiceException(_errorUnauthorized, detail: 'token_expired');
      }

      throw PetServiceException(_errorServer, detail: 'status_${response.statusCode}');
    } on PetServiceException {
      rethrow;
    } catch (e) {
      throw PetServiceException(_errorServer, detail: e.toString());
    }
  }

  static PetModel _parseCreateResponse(http.Response response) {
    switch (response.statusCode) {
      case 201:
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PetModel.fromJson(json);

      case 401:
        throw PetServiceException(_errorUnauthorized, detail: 'token_rejected');

      case 422:
        final body = jsonDecode(response.body);
        throw PetServiceException(
          'Datos inválidos. Revisa el formulario.',
          detail: body.toString(),
        );

      default:
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final message = body['error'] as String? ?? _errorCreateFailed;
          throw PetServiceException(message, detail: body['detail']?.toString());
        } catch (e) {
          if (e is PetServiceException) rethrow;
          throw PetServiceException(_errorServer, detail: 'status_${response.statusCode}');
        }
    }
  }
}

class PetServiceException implements Exception {
  final String message;
  final String? detail;

  const PetServiceException(this.message, {this.detail});

  @override
  String toString() => 'PetServiceException: $message (detail: $detail)';
}