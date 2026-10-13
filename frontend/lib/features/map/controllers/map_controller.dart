// lib/features/map/pets_map_controller.dart

import 'dart:async';
import 'dart:math';

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
  bool _locationDenied = false;     // permiso denegado permanentemente
  bool _permissionDenied = false;   // permiso denegado (cualquier tipo)
  bool _serviceEnabled = true;      // GPS del sistema encendido

  // Generación de la última llamada a loadPetsNearby.
  // Descarta respuestas de llamadas anteriores (evita race condition).
  int _loadGen = 0;

  // Guard: evita que HomeView y MapView disparen la inicialización en paralelo
  Future<void>? _initFuture;

  // Refresco periódico para propagar cambios de estado de otros usuarios
  Timer? _refreshTimer;

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
  bool      get permissionDenied => _permissionDenied;
  bool      get serviceEnabled  => _serviceEnabled;

  /// Cantidad de mascotas visibles por filtro (para los chips del mapa).
  int countFor(String filter) {
    final visible = _allPets.where((p) => p.shouldShowOnMap());
    return switch (filter) {
      'perdidos'  => visible.where((p) => p.isLost).length,
      'avistados' => visible.where((p) => p.isHome).length,
      _           => visible.length,
    };
  }

  LatLng get userLatLng => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : const LatLng(-17.3895, -66.1568); // Fallback: Cochabamba

  /// Todas las mascotas visibles en el mapa, sin aplicar el chip de filtro.
  List<MapPetModel> get visiblePets =>
      _allPets.where((p) => p.shouldShowOnMap()).toList();

  List<MapPetModel> get filteredPets {
    final visible = visiblePets;
    return switch (_activeFilter) {
      'perdidos'  => visible.where((p) => p.isLost).toList(),
      'avistados' => visible.where((p) => p.isHome).toList(),
      _           => visible,
    };
  }

  /// [filteredPets] con posiciones ajustadas para que los marcadores que
  /// caen en el mismo punto no se solapen. Usa espiral de ángulo dorado:
  /// distribución uniforme sin alineaciones visibles.
  ///
  /// Radio base ≈ 24 m por paso, escala con √n para que grupos grandes
  /// no se dispersen demasiado.
  List<(MapPetModel, LatLng)> get petsWithPositions {
    final pets = filteredPets;
    if (pets.length <= 1) {
      return pets.map((p) => (p, p.latLng)).toList();
    }

    // Bin de ~11 m (4 decimales) — misma casilla = pines visualmente solapados
    final groups = <String, List<int>>{};
    for (var i = 0; i < pets.length; i++) {
      final k = '${(pets[i].lat * 10000).round()},${(pets[i].lng * 10000).round()}';
      groups.putIfAbsent(k, () => []).add(i);
    }

    final out = List<(MapPetModel, LatLng)?>.filled(pets.length, null);

    for (final indices in groups.values) {
      for (var j = 0; j < indices.length; j++) {
        final pet = pets[indices[j]];
        if (j == 0) {
          out[indices[j]] = (pet, pet.latLng);
        } else {
          // Ángulo dorado 137.508° en radianes → distribución uniforme en espiral
          final angle  = j * 2.399963;
          final r      = 0.00022 * sqrt(j.toDouble()); // ≈ 24 m por paso
          final cosLat = cos(pet.lat * pi / 180);
          out[indices[j]] = (
            pet,
            LatLng(
              pet.lat + r * cos(angle),
              pet.lng + r * sin(angle) / cosLat,
            ),
          );
        }
      }
    }

    return out.whereType<(MapPetModel, LatLng)>().toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DETECCIÓN EN VIVO DEL GPS
  // ═══════════════════════════════════════════════════════════════════════════

  void _listenToServiceStatus() {
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
      (status) {
        if (status == ServiceStatus.disabled) {
          _locationEnabled = false;
          _serviceEnabled = false;
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
    _refreshTimer?.cancel();
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
    // Refresco automático cada 30 s para propagar cambios de otros usuarios
    // silent: no muestra el badge "Cargando…" cada 30 s en el mapa
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => loadPetsNearby(silent: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UBICACIÓN GPS
  // Intenta primero última posición conocida (instantáneo) antes de pedir
  // una posición nueva (puede tardar varios segundos).
  // ═══════════════════════════════════════════════════════════════════════════

  /// [askPermission]: solo se pide el permiso en la inicialización o por
  /// acción explícita del usuario. Pedirlo al volver a la app causaba un
  /// bucle en Android (el diálogo pausa/reanuda la app → se vuelve a pedir)
  /// que terminaba en "denegado para siempre" tras dos rechazos.
  Future<void> _fetchLocation({bool askPermission = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _serviceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        _locationEnabled = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationEnabled = false;
        _permissionDenied = true;
        _locationDenied = permission == LocationPermission.deniedForever;
        notifyListeners();
        return;
      }
      _permissionDenied = false;

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
    await _fetchLocation(askPermission: false);
    if (_locationEnabled) {
      await loadPetsNearby();
      centerOnUser();
    }
  }

  /// Acción del botón "Activar" (banner de Home / badge del mapa).
  /// Resuelve la causa real en vez de abrir siempre los ajustes de ubicación:
  /// - GPS apagado            → ajustes de ubicación del sistema
  /// - permiso denegado       → vuelve a pedir el permiso
  /// - denegado para siempre  → ajustes de la app (único lugar donde se cambia)
  /// Al volver de los ajustes, el lifecycle observer refresca el estado.
  Future<void> requestLocationAccess() async {
    if (!_serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (_locationDenied) {
      await Geolocator.openAppSettings();
      return;
    }
    await _fetchLocation(askPermission: true);
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

  /// [silent]: refresco en segundo plano (timer). No enciende el indicador
  /// de carga y, si falla, conserva los pines anteriores sin mostrar error.
  Future<void> loadPetsNearby({bool silent = false}) async {
    _loadGen++;
    final gen = _loadGen;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final pets = await MapService.getPetsNearby(
        userLatLng.latitude,
        userLatLng.longitude,
      );

      if (gen != _loadGen) return; // respuesta vieja — descartar
      _allPets = pets;
      _error = null;
    } on MapServiceException catch (e) {
      if (gen != _loadGen) return;
      if (!silent || _allPets.isEmpty) _error = e.message;
    } catch (_) {
      if (gen != _loadGen) return;
      if (!silent || _allPets.isEmpty) {
        _error = 'No se pudieron cargar las mascotas cercanas.';
      }
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
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _initFuture = null;
    _userPosition = null;
    _allPets = [];
    _activeFilter = 'todos';
    _isLoading = false;
    _isInitialized = false;
    _locationEnabled = false;
    _locationDenied = false;
    _permissionDenied = false;
    _serviceEnabled = true;
    _error = null;
    notifyListeners();
  }
}
