// lib/features/map/map_view.dart

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
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
    final zoomTween = Tween<double>(
      begin: mapCtrl.camera.zoom,
      end: zoom,
    );

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
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
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

              // Marcadores de mascotas
              MarkerLayer(
                markers: ctrl.filteredPets.map((pet) {
                  return Marker(
                    point: pet.latLng,
                    width: 52,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showPetDetails(pet),
                      child: _PetMarker(pet: pet),
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

                // Badge de GPS desactivado
                if (!ctrl.locationEnabled && !ctrl.isLoading) ...[
                  const SizedBox(height: 8),
                  const Center(child: _GpsOffBadge()),
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
      backgroundColor: Colors.transparent,
      builder: (_) => _PetBottomSheet(pet: pet),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MARCADOR: Ubicación del usuario (pulso azul)
// ═════════════════════════════════════════════════════════════════════════════

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.trustBlue.withValues(alpha: 0.15),
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
  final ValueChanged<String> onChanged;

  const _FilterChips({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
          _Chip(label: 'Todos', id: 'todos', active: active, onTap: onChanged),
          _Chip(
            label: 'Perdidos',
            id: 'perdidos',
            active: active,
            onTap: onChanged,
            activeColor: AppColors.panicRed,
          ),
          _Chip(
            label: 'Avistados',
            id: 'avistados',
            active: active,
            onTap: onChanged,
            activeColor: AppColors.esmeraldGreen,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String id;
  final String active;
  final ValueChanged<String> onTap;
  final Color activeColor;

  const _Chip({
    required this.label,
    required this.id,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.trustBlue,
  });

  bool get isActive => active == id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTheme.labelSm.copyWith(
            color: isActive ? Colors.white : AppColors.outline,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
  final VoidCallback onTap;
  final Color color;

  const _MapFab({
    required this.icon,
    required this.onTap,
    this.color = AppColors.trustBlue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
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
              'Sin datos · Tocar para reintentar',
              style: AppTheme.labelSm.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsOffBadge extends StatelessWidget {
  const _GpsOffBadge();

  @override
  Widget build(BuildContext context) {
    return _Badge(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off, color: AppColors.alertAmber, size: 16),
          const SizedBox(width: 8),
          Text(
            'Ubicación desactivada',
            style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — ficha real de mascota
// ═════════════════════════════════════════════════════════════════════════════

class _PetBottomSheet extends StatelessWidget {
  final MapPetModel pet;

  const _PetBottomSheet({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.marginMobile),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.inputFill,
                    border: Border.all(color: pet.markerColor, width: 2),
                  ),
                  child: ClipOval(
                    child: pet.photoUrl != null
                        ? Image.network(pet.photoUrl!, fit: BoxFit.cover)
                        : Icon(Icons.pets, color: pet.markerColor, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(pet.name, style: AppTheme.headlineMd),
                          ),
                          if (pet.isOwn)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.trustBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Tuya',
                                style: AppTheme.labelSm.copyWith(
                                  color: AppColors.trustBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pet.markerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pet.statusLabel,
                          style: AppTheme.labelSm.copyWith(
                            color: pet.markerColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (pet.breed != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          pet.breed!,
                          style: AppTheme.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Ver más'),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}