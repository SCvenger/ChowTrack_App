// lib/features/home/home_view.dart
// Versión solo UI/UX — sin lógica, sin servicios, sin controllers.
// Los valores están hardcodeados para visualización.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../navigation/navigation_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente disponible')),
                );
              },
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
}

// WIDGET: Card de estado del SISTEMA

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
          // Fila superior: label + badge
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
          // Fila inferior: pin + ubicación
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

// WIDGET: Botón 

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


// WIDGET: Map Preview 


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
              // Imagen del mapa (placeholder estático)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/map_placeholder.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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

              // Pins simulados sobre el mapa
              const Positioned(top: 60, left: 80, child: _MapPin()),
              const Positioned(top: 90, left: 140, child: _MapPin()),
              const Positioned(top: 110, left: 100, child: _MapPin()),
              const Positioned(top: 120, left: 180, child: _MapPin()),
              const Positioned(top: 130, left: 220, child: _MapPin()),
              const Positioned(top: 80, left: 200, child: _MapPin()),
              const Positioned(top: 150, left: 60, child: _MapPin()),

              // Botón recentrar
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