// lib/features/map/pets_map_controller.dart

import 'dart:async';

import 'package:chowtrack/features/map/models/map_pet_model.dart';
import 'package:chowtrack/features/map/services/map_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;


class PetsMapController extends ChangeNotifier {
  // ── flutter_map camera controller (solo MapView lo usa) ───────────────────
  final MapController mapController = MapController();

  // ── Estado ────────────────────────────────────────────────────────────────
  Position? _userPosition;
  List<MapPetModel> _allPets = [];
  String _activeFilter = 'todos';
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _locationEnabled = false;
  bool _locationDenied = false;

  // Generación de la última llamada a loadPetsNearby.
  // Descarta respuestas de llamadas anteriores (evita race condition).
  int _loadGen = 0;

  // Guard: evita que HomeView y MapView disparen la inicialización en paralelo
  Future<void>? _initFuture;

  // Escucha cambios del servicio de ubicación EN VIVO (GPS on/off del sistema)
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  PetsMapController() {
    _listenToServiceStatus();
  }

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

  List<MapPetModel> get filteredPets {
    final visible = _allPets.where((p) => p.shouldShowOnMap()).toList();
    return switch (_activeFilter) {
      'perdidos'  => visible.where((p) => p.isLost).toList(),
      'avistados' => visible.where((p) => p.isHome).toList(),
      _           => visible,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DETECCIÓN EN VIVO DEL GPS
  // ═══════════════════════════════════════════════════════════════════════════

  void _listenToServiceStatus() {
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
      (status) {
        if (status == ServiceStatus.disabled) {
          _locationEnabled = false;
          notifyListeners();
        } else {
          refreshLocation();
        }
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _serviceStatusSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    await _fetchLocation();
    await loadPetsNearby();
    _isInitialized = true;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UBICACIÓN GPS
  // Intenta primero última posición conocida (instantáneo) antes de pedir
  // una posición nueva (puede tardar varios segundos).
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationEnabled = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationEnabled = false;
        _locationDenied = permission == LocationPermission.deniedForever;
        notifyListeners();
        return;
      }

      // 1. Última posición conocida — devuelve resultado inmediato
      Position? pos = await Geolocator.getLastKnownPosition();

      // 2. Si no hay posición cacheada, adquirir posición actual
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _userPosition = pos;
      _locationEnabled = true;
      _locationDenied = false;
      notifyListeners();
    } catch (_) {
      _locationEnabled = false;
      notifyListeners();
    }
  }

  /// Re-verifica GPS y recarga mascotas al volver a la app o al encender GPS.
  /// El delay de 600ms evita el falso negativo del SO justo al resume.
  Future<void> refreshLocation() async {
    await Future.delayed(const Duration(milliseconds: 600));
    await _fetchLocation();
    if (_locationEnabled) {
      await loadPetsNearby();
      centerOnUser();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARGA DE MASCOTAS CERCANAS
  //
  // Race condition fix: _loadGen se incrementa en cada llamada.
  // Solo la última llamada aplica su resultado — las anteriores son descartadas.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> loadPetsNearby() async {
    _loadGen++;
    final gen = _loadGen;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pets = await MapService.getPetsNearby(
        userLatLng.latitude,
        userLatLng.longitude,
      );

      if (gen != _loadGen) return; // respuesta vieja — descartar
      _allPets = pets;
    } on MapServiceException catch (e) {
      if (gen != _loadGen) return;
      _error = e.message;
    } catch (_) {
      if (gen != _loadGen) return;
      _error = 'No se pudieron cargar las mascotas cercanas.';
    } finally {
      // Solo el último request apaga el spinner y notifica
      if (gen == _loadGen) {
        _isLoading = false;
        notifyListeners();
      }
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
  // CENTRADO
  // ═══════════════════════════════════════════════════════════════════════════

  void centerOnUser() {
    try {
      mapController.move(userLatLng, 14);
    } catch (_) {
      // El mapa puede no estar listo aún
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIMPIAR (logout)
  // ═══════════════════════════════════════════════════════════════════════════

  void clear() {
    _loadGen++;        // invalida cualquier request en vuelo
    _userPosition = null;
    _allPets = [];
    _activeFilter = 'todos';
    _isLoading = false;
    _isInitialized = false;
    _initFuture = null;
    _locationEnabled = false;
    _locationDenied = false;
    _error = null;
    notifyListeners();
  }
}
