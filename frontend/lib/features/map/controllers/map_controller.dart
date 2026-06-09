// lib/features/map/pets_map_controller.dart

import 'package:chowtrack/features/map/models/map_pet_model.dart';
import 'package:chowtrack/features/map/services/map_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;


class PetsMapController extends ChangeNotifier {
  // ── flutter_map camera controller ─────────────────────────────────────────
  final MapController mapController = MapController();

  // ── Estado ────────────────────────────────────────────────────────────────
  Position? _userPosition;
  List<MapPetModel> _allPets = [];
  String _activeFilter = 'todos';
  bool _isLoading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  Position?          get userPosition  => _userPosition;
  bool               get isLoading     => _isLoading;
  String?            get error         => _error;
  String             get activeFilter  => _activeFilter;

  LatLng get userLatLng => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : const LatLng(-17.3895, -66.1568); // Fallback: Cochabamba

  List<MapPetModel> get filteredPets => switch (_activeFilter) {
        'perdidos'  => _allPets.where((p) => p.isLost).toList(),
        'avistados' => _allPets.where((p) => p.isFound).toList(),
        _           => _allPets,
      };

  // ── Inicialización ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _fetchLocation();
    await loadPetsNearby();
    _centerOnUser();
  }

  // ── Ubicación GPS ─────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      notifyListeners();
    } catch (_) {
      // Sin GPS → usa coordenadas de Cochabamba como fallback
    }
  }

  // ── Carga de mascotas cercanas ─────────────────────────────────────────────

  Future<void> loadPetsNearby() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allPets = await MapService.getPetsNearby(
        userLatLng.latitude,
        userLatLng.longitude,
      );
    } on MapServiceException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudieron cargar las mascotas cercanas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Filtro ────────────────────────────────────────────────────────────────

  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    notifyListeners();
  }

  // ── Centrar en usuario ────────────────────────────────────────────────────

  void _centerOnUser() {
    try {
      mapController.move(userLatLng, 14);
    } catch (_) {
      // El mapa puede no estar listo aún — no es crítico
    }
  }

  void recenterMap() {
    mapController.move(userLatLng, 14);
  }

  // ── Limpiar (logout) ──────────────────────────────────────────────────────

  void clear() {
    _userPosition = null;
    _allPets = [];
    _activeFilter = 'todos';
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}