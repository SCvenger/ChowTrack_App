// lib/features/pets/pets_controller.dart

import 'package:chowtrack/core/services/pet_service.dart';
import 'package:chowtrack/features/petRegistration/models/pet_model.dart';
import 'package:flutter/material.dart';

class PetsController extends ChangeNotifier {
  List<PetModel> _pets = [];
  bool _isLoading = false;
  String? _error;

  List<PetModel> get pets => List.unmodifiable(_pets);
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get isEmpty => _pets.isEmpty;

  // ════════════════════════════════════════════════════════════════════════
  // CARGA DE MASCOTAS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> loadPets({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _pets = await PetService.getMyPets();
      _error = null;
    } on PetServiceException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudieron cargar tus mascotas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // ACTUALIZAR ESTADO DE UNA MASCOTA
  // (PATCH /pets/{id}/status — endpoint backend)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> updatePetStatus(
    String petId,
    String newStatus, {
    double? lat,
    double? lng,
  }) async {
    final index = _pets.indexWhere((p) => p.id == petId);
    if (index == -1) return;

    final previous = _pets[index];
    _pets[index] = previous.copyWith(status: newStatus);
    notifyListeners();

    try {
      await PetService.updatePetStatus(petId, newStatus, lat: lat, lng: lng);
    } catch (e) {
      _pets[index] = previous;
      _error = 'No se pudo actualizar el estado.';
      notifyListeners();
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // LIMPIAR ESTADO (logout)
  // ════════════════════════════════════════════════════════════════════════

  void clear() {
    _pets = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}