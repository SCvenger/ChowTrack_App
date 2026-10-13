// lib/features/map/map_view.dart

import 'dart:convert';

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import 'models/map_pet_model.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

// TickerProviderStateMixin necesario para la animación de centrado
class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  AnimationController? _moveController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = context.read<PetsMapController>();
      await ctrl.initialize();
      if (mounted) ctrl.centerOnUser();
    });
  }

  @override
  void dispose() {
    _moveController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMACIÓN DE CENTRADO — desliza suavemente hacia la posición del usuario
  // ═══════════════════════════════════════════════════════════════════════════

  void _animatedMove(LatLng destination, double zoom) {
    final mapCtrl = context.read<PetsMapController>().mapController;

    // Cancelar animación previa si el usuario toca rápido
    _moveController?.stop();
    _moveController?.dispose();

    final latTween = Tween<double>(
      begin: mapCtrl.camera.center.latitude,
      end: destination.latitude,
    );
    final lngTween = Tween<double>(
      begin: mapCtrl.camera.center.longitude,
      end: destination.longitude,
    );
    final zoomTween = Tween<double>(begin: mapCtrl.camera.zoom, end: zoom);

    _moveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.easeInOut,
    );

    _moveController!.addListener(() {
      mapCtrl.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _moveController!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _moveController?.dispose();
        _moveController = null;
      }
    });

    _moveController!.forward();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PetsMapController>();
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: ctrl.mapController,
            options: MapOptions(
              initialCenter: ctrl.userLatLng,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Tiles Stadia Maps con CancellableNetworkTileProvider
              // (resuelve problemas de carga por WiFi en Android)
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/alidade_smooth'
                    '/{z}/{x}/{y}@2x.png?api_key=${ApiConfig.stadiaApiKey}',
                userAgentPackageName: 'com.example.chowtrack',
                tileProvider: CancellableNetworkTileProvider(),
              ),

              // Radio de búsqueda 5 km
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: ctrl.userLatLng,
                    radius: 5000,
                    useRadiusInMeter: true,
                    color: AppColors.trustBlue.withValues(alpha: 0.06),
                    borderColor: AppColors.trustBlue.withValues(alpha: 0.25),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // Marcador de usuario
              MarkerLayer(
                markers: [
                  Marker(
                    point: ctrl.userLatLng,
                    width: 52,
                    height: 52,
                    child: const _UserLocationMarker(),
                  ),
                ],
              ),

              // Marcadores de mascotas (con jitter para evitar solapamiento)
              MarkerLayer(
                markers: ctrl.petsWithPositions.map((entry) {
                  final (pet, point) = entry;
                  return Marker(
                    point: point,
                    width: 52,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      button: true,
                      label: '${pet.name}, ${pet.statusLabel}',
                      hint: 'Ver detalles',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showPetDetails(pet),
                        child: _PetMarker(pet: pet),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Overlay superior: chips + badges apilados en columna ───────
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chips de filtro — siempre visibles arriba
                Center(
                  child: _FilterChips(
                    active: ctrl.activeFilter,
                    countFor: ctrl.countFor,
                    onChanged: ctrl.setFilter,
                  ),
                ),

                // Badge de carga — debajo de los chips
                if (ctrl.isLoading) ...[
                  const SizedBox(height: 8),
                  const Center(child: _LoadingBadge()),
                ],

                // Badge de error — debajo de los chips
                if (ctrl.error != null && !ctrl.isLoading) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _ErrorBadge(
                      message: ctrl.error!,
                      onRetry: ctrl.loadPetsNearby,
                    ),
                  ),
                ],

                // Estado vacío: sin esto, un filtro sin resultados se veía
                // igual que un mapa que todavía no cargó.
                if (ctrl.isInitialized &&
                    !ctrl.isLoading &&
                    ctrl.error == null &&
                    ctrl.filteredPets.isEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _Badge(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.outline,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            switch (ctrl.activeFilter) {
                              'perdidos' => 'Sin mascotas perdidas en 5 km',
                              'avistados' =>
                                'Sin mascotas encontradas en la última hora',
                              _ => 'Sin reportes en 5 km a la redonda',
                            },
                            style: AppTheme.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Badge de GPS desactivado — tocable: resuelve la causa
                // (GPS apagado / permiso) igual que el banner de Home.
                if (!ctrl.locationEnabled && !ctrl.isLoading) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _GpsOffBadge(
                      onTap: ctrl.requestLocationAccess,
                      actionLabel: !ctrl.serviceEnabled
                          ? 'Activar'
                          : (ctrl.locationDenied ? 'Ajustes' : 'Permitir'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Botón recentrar con animación (derecha) ───────────────────
          Positioned(
            right: 16,
            bottom: 88 + 16 + bottomPadding,
            child: _MapFab(
              icon: Icons.my_location,
              tooltip: 'Centrar en mi ubicación',
              onTap: () => _animatedMove(ctrl.userLatLng, 14),
            ),
          ),

          // ── Botón reportar avistamiento (izquierda) ───────────────────
          Positioned(
            left: 16,
            bottom: 88 + 16 + bottomPadding,
            child: _MapFab(
              icon: Icons.add_location_alt_outlined,
              color: AppColors.esmeraldGreen,
              tooltip: 'Reportar avistamiento (próximamente)',
              comingSoon: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente disponible')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPetDetails(MapPetModel pet) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // sube sobre la nav bar flotante
      isScrollControlled: true, // altura dinámica según contenido
      backgroundColor: Colors.transparent,
      builder: (_) => _PetBottomSheet(pet: pet),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MARCADOR: Ubicación del usuario (pulso azul)
// ═════════════════════════════════════════════════════════════════════════════

class _UserLocationMarker extends StatefulWidget {
  const _UserLocationMarker();

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "Quitar animaciones" del sistema: el radar queda estático.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _pulseController.value = 0.5;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Anillo de radar: se expande y se desvanece en loop
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final t = _pulseController.value;
            return Opacity(
              opacity: (1 - t) * 0.45,
              child: Transform.scale(scale: 0.5 + t * 1.1, child: child),
            );
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.trustBlue.withValues(alpha: 0.35),
            ),
          ),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.trustBlue.withValues(alpha: 0.25),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.trustBlue,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.trustBlue.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MARCADOR: Mascota con pin
// ═════════════════════════════════════════════════════════════════════════════

class _PetMarker extends StatelessWidget {
  final MapPetModel pet;

  const _PetMarker({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: pet.markerColor,
              width: pet.isOwn ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: pet.markerColor.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: pet.photoUrl != null
                ? Image.network(
                    pet.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.pets, color: pet.markerColor, size: 22),
                  )
                : Icon(Icons.pets, color: pet.markerColor, size: 22),
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: pet.markerColor),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// FILTROS — chips flotantes en la parte superior
// ═════════════════════════════════════════════════════════════════════════════

class _FilterChips extends StatelessWidget {
  final String active;
  final int Function(String filter) countFor;
  final ValueChanged<String> onChanged;

  const _FilterChips({
    required this.active,
    required this.countFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // scaleDown: en pantallas angostas (≤ 340 dp) o con texto grande del
    // sistema, la barra se achica en vez de desbordarse por los costados.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              label: 'Todos',
              id: 'todos',
              count: countFor('todos'),
              active: active,
              onTap: onChanged,
            ),
            _Chip(
              label: 'Perdidos',
              id: 'perdidos',
              count: countFor('perdidos'),
              active: active,
              onTap: onChanged,
              activeColor: AppColors.panicRed,
            ),
            _Chip(
              label: 'Encontrados',
              id: 'avistados',
              count: countFor('avistados'),
              active: active,
              onTap: onChanged,
              // Verde legible: blanco sobre #50C878 no llega a 3:1
              activeColor: AppColors.readable(AppColors.esmeraldGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String id;
  final int count;
  final String active;
  final ValueChanged<String> onTap;
  final Color activeColor;

  const _Chip({
    required this.label,
    required this.id,
    required this.count,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.trustBlue,
  });

  bool get isActive => active == id;

  @override
  Widget build(BuildContext context) {
    // Área táctil de 48 dp (DESIGN.md: tap-target-min); el pill visible
    // mide 40 dp y queda centrado con 4 dp de margen dentro de la barra.
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label, $count',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isActive) HapticFeedback.selectionClick();
          onTap(id);
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$label · $count',
              style: AppTheme.labelSm.copyWith(
                color: isActive ? Colors.white : AppColors.outline,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FAB del mapa
// ═════════════════════════════════════════════════════════════════════════════

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final bool comingSoon;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.trustBlue,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: comingSoon ? color.withValues(alpha: 0.5) : color,
                    size: 22,
                  ),
                ),
                if (comingSoon)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.alertAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BADGES de estado
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge();

  @override
  Widget build(BuildContext context) {
    return _Badge(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.trustBlue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Cargando mascotas cercanas...',
            style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _ErrorBadge extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBadge({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: _Badge(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.panicRed, size: 16),
            const SizedBox(width: 8),
            Text(
              'Sin conexión · Tocar para reintentar',
              style: AppTheme.labelSm.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsOffBadge extends StatelessWidget {
  final VoidCallback onTap;
  final String actionLabel;

  const _GpsOffBadge({required this.onTap, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ubicación desactivada. $actionLabel',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: _Badge(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                color: AppColors.tintAmber,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Ubicación desactivada · ',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
              Text(
                actionLabel,
                style: AppTheme.labelSm.copyWith(
                  color: AppColors.trustBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;

  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — ficha de mascota estilizada como PetDetailView
// ═════════════════════════════════════════════════════════════════════════════

class _PetBottomSheet extends StatefulWidget {
  final MapPetModel pet;
  const _PetBottomSheet({required this.pet});

  @override
  State<_PetBottomSheet> createState() => _PetBottomSheetState();
}

class _PetBottomSheetState extends State<_PetBottomSheet> {
  // Caché estático: persiste durante la sesión y evita llamadas repetidas
  // a Nominatim para la misma ubicación (la API tiene límite de uso).
  // Clave: lat/lng redondeados a 4 decimales (≈11 m de precisión).
  static final Map<String, String> _geocodeCache = {};

  String? _address;
  bool _loadingAddress = true;

  // Header/botón con texto blanco o de color: el verde puro no llega a
  // contraste AA → variante legible. El pin del mapa conserva el token.
  Color get _headerColor => widget.pet.isHome
      ? AppColors.readable(AppColors.esmeraldGreen)
      : widget.pet.markerColor;

  String get _cacheKey =>
      '${widget.pet.lat.toStringAsFixed(4)},${widget.pet.lng.toStringAsFixed(4)}';

  @override
  void initState() {
    super.initState();
    _reverseGeocode();
  }

  // Convierte lat/lng a nombre de lugar usando Nominatim (OSM, gratuito).
  // Si la ubicación ya fue resuelta en esta sesión, devuelve el resultado
  // del caché sin hacer ninguna petición HTTP.
  Future<void> _reverseGeocode() async {
    final key = _cacheKey;

    // Hit de caché: mostrar resultado inmediatamente, sin red
    if (_geocodeCache.containsKey(key)) {
      setState(() {
        _address = _geocodeCache[key];
        _loadingAddress = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${widget.pet.lat}&lon=${widget.pet.lng}'
        '&format=json&accept-language=es',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'ChowTrack/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        final result = _buildAddress(addr, data['display_name'] as String?);
        _geocodeCache[key] = result; // guardar en caché
        if (mounted) {
          setState(() {
            _address = result;
            _loadingAddress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _address = null;
            _loadingAddress = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = null;
          _loadingAddress = false;
        });
      }
    }
  }

  String _buildAddress(Map<String, dynamic>? addr, String? displayName) {
    if (addr == null) {
      // fallback: primeras dos partes del display_name
      return displayName?.split(',').take(2).join(',').trim() ?? '';
    }
    final road = addr['road'] as String?;
    final suburb =
        addr['suburb'] as String? ?? addr['neighbourhood'] as String?;
    final city =
        addr['city'] as String? ??
        addr['town'] as String? ??
        addr['village'] as String?;

    if (road != null && suburb != null) return '$road, $suburb';
    if (road != null && city != null) return '$road, $city';
    if (road != null) return road;
    if (suburb != null) return suburb;
    if (city != null) return city;
    return displayName?.split(',').take(2).join(',').trim() ?? '';
  }

  String get _lastSeenText {
    if (widget.pet.lastSeenAt == null) return '';
    final dt = DateTime.tryParse(widget.pet.lastSeenAt!)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    final prefix = widget.pet.isHome ? 'Encontrada' : 'Vista por última vez';
    if (diff.inMinutes < 1) return '$prefix hace un momento';
    if (diff.inMinutes < 60) return '$prefix hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return '$prefix hace ${diff.inHours} h';
    final d = diff.inDays;
    return '$prefix hace $d ${d == 1 ? 'día' : 'días'}';
  }

  // Foto expandida en pantalla completa al tocarla
  void _expandPhoto(BuildContext context) {
    if (widget.pet.photoUrl == null) return;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(
              widget.pet.photoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // clipBehavior recorta los hijos al borderRadius sin necesitar color propio
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HEADER coloreado: rojo=perdido, azul=en proceso, verde=en casa ──
          Container(
            width: double.infinity,
            color: _headerColor,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                // Handle sobre fondo de color
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Foto tappeable
                GestureDetector(
                  onTap: () => _expandPhoto(context),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: pet.photoUrl != null
                              ? Image.network(
                                  pet.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.pets,
                                    size: 40,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                )
                              : Icon(
                                  Icons.pets,
                                  size: 40,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                        ),
                      ),
                      // Indicador de "toca para expandir"
                      if (pet.photoUrl != null)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Nombre
                Text(
                  pet.name,
                  style: AppTheme.headlineMd.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),

                // Solo estado + raza debajo del nombre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SheetBadge(label: pet.statusLabel),
                    if (pet.breed != null) ...[
                      const SizedBox(width: 8),
                      _SheetBadge(label: pet.breed!),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── CUERPO blanco con información ─────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(AppTheme.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastSeenText.isNotEmpty)
                  _InfoRow(icon: Icons.schedule, text: _lastSeenText),

                // Dirección geocodificada
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: _loadingAddress
                      ? 'Obteniendo ubicación…'
                      : (_address?.isNotEmpty == true
                            ? _address!
                            : 'Ubicación desconocida'),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _headerColor,
                      side: BorderSide(
                        color: _headerColor.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
                SizedBox(height: bottomPad),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetBadge extends StatelessWidget {
  final String label;
  const _SheetBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: AppTheme.labelSm.copyWith(color: Colors.white)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              // Dato clave para quien busca la mascota: tamaño de cuerpo
              // (DESIGN.md: el texto de cuerpo nunca baja de 16px).
              style: AppTheme.bodyMd.copyWith(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
