// lib/features/home/home_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_theme.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.marginMobile,
            AppTheme.stackMd,
            AppTheme.marginMobile,
            104,
          ),
          children: [
            //  Card de SISTEMA 
            const _SystemStatusCard(
              statusLabel: 'Protegido',
              statusColor: AppColors.esmeraldGreen,
              locationName: 'Queru, Cochabamba',
            ),

            AppTheme.spacerLg,

            //  Botón: PERDÍ A MI MASCOTA 
            _ActionButton(
              label: 'PERDÍ A MI MASCOTA',
              icon: Icons.campaign_outlined,
              color: AppColors.panicRed,
              onTap: _onLostPetTapped,   // ← Conectado exitosamente
            ),

            AppTheme.spacerMd,

            //  Botón: ENCONTRÉ UN PERRO 
            _ActionButton(
              label: 'ENCONTRÉ UN PERRO',
              icon: Icons.pets,
              color: AppColors.trustBlue,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente disponible')),
                );
              },
            ),

            AppTheme.spacerLg,

            //  Mapa preview 
            _MapPreview(
              onTap: () =>
                  context.read<NavigationController>().setIndex(1),
            ),
          ],
        ),
      ),
    );
  }

  // ── LÓGICA DE NEGOCIO INTEGRADA ──

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
        const SnackBar(content: Text('Todas tus mascotas ya están marcadas como perdidas.')),
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
   
    // ── Capturar GPS antes de marcar como perdida ──
    double? lat;
    double? lng;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      // Sin GPS: las coordenadas quedan nulas pero el flujo continúa
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

  // Diálogo de confirmación para cuando solo hay 1 mascota
  Future<bool?> _confirmMarkAsLost(PetModel pet) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Confirmar Reporte?'),
        content: Text('¿Estás seguro de que deseas reportar a ${pet.name} como perdida?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: AppColors.panicRed)),
          ),
        ],
      ),
    );
  }

  // Selector (BottomSheet) para cuando hay múltiples mascotas disponibles
  Future<PetModel?> _showPetSelector(List<PetModel> candidates) {
    return showModalBottomSheet<PetModel>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecciona la mascota perdida',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ...candidates.map((pet) => ListTile(
                    leading: const Icon(Icons.pets, color: AppColors.outline),
                    title: Text(pet.name),
                    onTap: () => Navigator.pop(context, pet),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WIDGETS PRIVADOS DE LA UI ──
// (Se mantienen abajo intactos tal como los tenías)

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

class _MapPreview extends StatelessWidget {
  final VoidCallback onTap;

  const _MapPreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFE8EAEE),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/map_placeholder.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFE8EAEE),
                    child: const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(top: 60, left: 80, child: _MapPin()),
              const Positioned(top: 90, left: 140, child: _MapPin()),
              const Positioned(top: 110, left: 100, child: _MapPin()),
              const Positioned(top: 120, left: 180, child: _MapPin()),
              const Positioned(top: 130, left: 220, child: _MapPin()),
              const Positioned(top: 80, left: 200, child: _MapPin()),
              const Positioned(top: 150, left: 60, child: _MapPin()),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
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
                    size: 18,
                    color: AppColors.trustBlue,
                  ),
                ),
              ),
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
                        style: AppTheme.labelSm.copyWith(color: Colors.white),
                      ),
                    ],
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

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_pin,
      size: 24,
      color: AppColors.outline.withValues(alpha: 0.7),
    );
  }
}