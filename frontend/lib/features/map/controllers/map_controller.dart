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
  bool _isInitialized = false;
  String? _error;

  // GPS
  bool _locationEnabled = false;
  bool _locationDenied = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  Position? get userPosition    => _userPosition;
  bool      get isLoading       => _isLoading;
  bool      get isInitialized   => _isInitialized;
  String?   get error           => _error;
  String    get activeFilter    => _activeFilter;
  bool      get locationEnabled => _locationEnabled;
  bool      get locationDenied  => _locationDenied;

  LatLng get userLatLng => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : const LatLng(-17.3895, -66.1568); // Fallback: Cochabamba

  List<MapPetModel> get filteredPets => switch (_activeFilter) {
        'perdidos'  => _allPets.where((p) => p.isLost).toList(),
        'avistados' => _allPets.where((p) => p.isFound).toList(),
        _           => _allPets,
      };

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN — se llama una sola vez al montar MapView o HomeView
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return; // evita doble inicialización
    await _fetchLocation();
    await loadPetsNearby();
    _isInitialized = true;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UBICACIÓN GPS — solicita permiso si hace falta
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchLocation() async {
    try {
      // 1. ¿El servicio de ubicación está activo?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationEnabled = false;
        notifyListeners();
        return;
      }

      // 2. Revisar permiso
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. Solicitar si no se ha concedido (pero no si está permanentemente denegado)
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Si sigue denegado o es permanente, marcar y salir
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationEnabled = false;
        _locationDenied = permission == LocationPermission.deniedForever;
        notifyListeners();
        return;
      }

      // 5. Obtener posición
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _locationEnabled = true;
      _locationDenied = false;
      notifyListeners();
    } catch (_) {
      _locationEnabled = false;
      notifyListeners();
    }
  }

  /// Llamado desde HomeView cuando el usuario activa el GPS y vuelve a la app.
  Future<void> refreshLocation() async {
    await _fetchLocation();
    if (_locationEnabled) {
      await loadPetsNearby();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARGA DE MASCOTAS CERCANAS
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTRO
  // ═══════════════════════════════════════════════════════════════════════════

  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CENTRADO — llamado internamente tras obtener GPS
  // La animación de la UI la maneja MapView con TickerProviderStateMixin
  // ═══════════════════════════════════════════════════════════════════════════

  void centerOnUser() {
    try {
      mapController.move(userLatLng, 14);
    } catch (_) {
      // El mapa puede no estar listo aún en la primera carga
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIMPIAR (logout)
  // ═══════════════════════════════════════════════════════════════════════════

  void clear() {
    _userPosition = null;
    _allPets = [];
    _activeFilter = 'todos';
    _isLoading = false;
    _isInitialized = false;
    _locationEnabled = false;
    _locationDenied = false;
    _error = null;
    notifyListeners();
  }
}