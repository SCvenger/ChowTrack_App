// lib/features/home/home_view.dart

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';

import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';


class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Poblar PetsController compartido si aún no tiene datos
      final petsCtrl = context.read<PetsController>();
      if (petsCtrl.pets.isEmpty && !petsCtrl.isLoading) {
        petsCtrl.loadPets(silent: true);
      }

      // Inicializar GPS + mascotas del mapa (usado también por MapView)
      final mapCtrl = context.read<PetsMapController>();
      if (!mapCtrl.isInitialized) {
        mapCtrl.initialize();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIÓN: Marcar mascota como perdida con GPS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLostPetTapped() async {
    final petsController = context.read<PetsController>();
    final pets = petsController.pets;

    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no tienes mascotas registradas.'),
          backgroundColor: AppColors.alertAmber,
        ),
      );
      return;
    }

    final candidates = pets.where((p) => !p.isLost).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas tus mascotas ya están marcadas como perdidas.'),
        ),
      );
      return;
    }

    PetModel? selected;

    if (candidates.length == 1) {
      final confirmed = await _confirmMarkAsLost(candidates.first);
      if (confirmed == true) selected = candidates.first;
    } else {
      selected = await _showPetSelector(candidates);
    }

    if (selected == null || !mounted) return;

    // Capturar GPS antes de marcar — es opcional, el flujo no se bloquea
    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Sin GPS: la mascota se marca como perdida sin coordenadas
    }

    try {
      await petsController.updatePetStatus(
        selected.id,
        'lost',
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.name} marcada como perdida'),
          backgroundColor: AppColors.panicRed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar. Inténtalo de nuevo.'),
          backgroundColor: AppColors.panicRed,
        ),
      );
    }
  }

  Future<bool?> _confirmMarkAsLost(PetModel pet) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Confirmar reporte?'),
        content: Text(
          '¿Estás seguro de que deseas reportar a ${pet.name} como perdida?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.panicRed,
            ),
            child: const Text('Sí, reportar'),
          ),
        ],
      ),
    );
  }

  Future<PetModel?> _showPetSelector(List<PetModel> candidates) {
    return showModalBottomSheet<PetModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.marginMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Cuál de tus mascotas?', style: AppTheme.headlineMd),
                  AppTheme.spacerSm,
                  ...candidates.map(
                    (pet) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.inputFill,
                        backgroundImage: pet.photoUrl != null
                            ? NetworkImage(pet.photoUrl!)
                            : null,
                        child: pet.photoUrl == null
                            ? const Icon(Icons.pets,
                                color: AppColors.trustBlue)
                            : null,
                      ),
                      title: Text(pet.name, style: AppTheme.bodyMd),
                      subtitle: pet.breed != null
                          ? Text(
                              pet.breed!,
                              style: AppTheme.labelSm.copyWith(
                                color: AppColors.outline,
                              ),
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, pet),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final mapCtrl = context.watch<PetsMapController>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.trustBlue,
          onRefresh: () async {
            await context.read<PetsController>().loadPets();
            await mapCtrl.loadPetsNearby();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile,
              AppTheme.stackMd,
              AppTheme.marginMobile,
              104,
            ),
            children: [
              // Banner GPS desactivado
              if (!mapCtrl.locationEnabled && mapCtrl.isInitialized) ...[
                _GpsBanner(
                  onActivate: () async {
                    await Geolocator.openLocationSettings();
                    await mapCtrl.refreshLocation();
                  },
                ),
                AppTheme.spacerMd,
              ],

              // Card SISTEMA
              _SystemStatusCard(
                statusLabel: mapCtrl.locationEnabled ? 'Protegido' : 'Alerta',
                statusColor: mapCtrl.locationEnabled
                    ? AppColors.esmeraldGreen
                    : AppColors.alertAmber,
                locationName: mapCtrl.locationEnabled
                    ? 'GPS activo'
                    : 'Ubicación desactivada',
              ),

              AppTheme.spacerLg,

              // Botón PERDÍ A MI MASCOTA
              _ActionButton(
                label: 'PERDÍ A MI MASCOTA',
                icon: Icons.campaign_outlined,
                color: AppColors.panicRed,
                onTap: _onLostPetTapped,
              ),

              AppTheme.spacerMd,

              // Botón ENCONTRÉ UN PERRO
              _ActionButton(
                label: 'ENCONTRÉ UN PERRO',
                icon: Icons.pets,
                color: AppColors.trustBlue,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Próximamente disponible'),
                    ),
                  );
                },
              ),

              AppTheme.spacerLg,

              // Mapa real (preview)
              _MapPreview(
                mapCtrl: mapCtrl,
                onTap: () =>
                    context.read<NavigationController>().setIndex(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GPS BANNER
// ═════════════════════════════════════════════════════════════════════════════

class _GpsBanner extends StatelessWidget {
  final VoidCallback onActivate;

  const _GpsBanner({required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.alertAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.alertAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off,
              color: AppColors.alertAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Activa tu ubicación para protección completa',
              style: AppTheme.labelSm.copyWith(
                color: AppColors.alertAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onActivate,
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SYSTEM STATUS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _SystemStatusCard extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final String locationName;

  const _SystemStatusCard({
    required this.statusLabel,
    required this.statusColor,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SISTEMA',
                  style: AppTheme.labelSm.copyWith(
                    color: AppColors.outline,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(locationName, style: AppTheme.bodyMd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: AppTheme.headlineMd.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAP PREVIEW — mapa real no interactivo
// ═════════════════════════════════════════════════════════════════════════════

class _MapPreview extends StatelessWidget {
  final PetsMapController mapCtrl;
  final VoidCallback onTap;

  const _MapPreview({required this.mapCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              // Mapa real no interactivo
              FlutterMap(
                options: MapOptions(
                  initialCenter: mapCtrl.userLatLng,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tiles.stadiamaps.com/tiles/alidade_smooth'
                        '/{z}/{x}/{y}@2x.png?api_key=${ApiConfig.stadiaApiKey}',
                    userAgentPackageName: 'com.example.chowtrack',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  // Radio de búsqueda
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: mapCtrl.userLatLng,
                        radius: 5000,
                        useRadiusInMeter: true,
                        color: AppColors.trustBlue.withValues(alpha: 0.05),
                        borderColor:
                            AppColors.trustBlue.withValues(alpha: 0.2),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                  // Marcador del usuario
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: mapCtrl.userLatLng,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.trustBlue,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.trustBlue
                                    .withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Pins de mascotas cercanas
                  MarkerLayer(
                    markers: mapCtrl.filteredPets.map((pet) {
                      return Marker(
                        point: pet.latLng,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pet.markerColor,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.pets,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Overlay tapeable transparente (intercepta gestos del mapa)
              Positioned.fill(child: Container(color: Colors.transparent)),

              // Badge "Live Grid Active"
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.esmeraldGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Grid Active',
                        style:
                            AppTheme.labelSm.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // Botón de recentrar
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    size: 17,
                    color: AppColors.trustBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}