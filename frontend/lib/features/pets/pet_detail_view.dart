// lib/features/pets/pet_detail_view.dart

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../petRegistration/models/pet_model.dart';

class PetDetailView extends StatelessWidget {
  final PetModel pet;

  const PetDetailView({super.key, required this.pet});

  // ── Color dinámico según estado ──────────────────────────────────────────
  Color get _headerColor => switch (pet.status) {
        'lost'  => AppColors.panicRed,
        'found' => AppColors.esmeraldGreen,
        _       => AppColors.trustBlue,
      };

  String get _statusLabel => switch (pet.status) {
        'lost'  => 'Perdido',
        'found' => 'Encontrado',
        _       => 'En casa',
      };

  IconData get _statusIcon => switch (pet.status) {
        'lost'  => Icons.warning_amber_outlined,
        'found' => Icons.search,
        _       => Icons.home_outlined,
      };

  String get _actionLabel => switch (pet.status) {
        'lost'  => 'Marcar como encontrado',
        'found' => 'Ya está en casa',
        _       => 'Marcar como perdido',
      };

  Color get _actionColor => switch (pet.status) {
        'lost'  => AppColors.esmeraldGreen,
        'found' => AppColors.trustBlue,
        _       => AppColors.panicRed,
      };

  String get _daysLabel {
    if (pet.createdAt == null) return '—';
    final days = DateTime.now().difference(pet.createdAt!).inDays;
    if (pet.isLost) return '$days días perdido';
    return '$days días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _headerColor,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context),
          // ── Cuerpo blanco con curva superior ──────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile,
              AppTheme.stackMd,
              AppTheme.marginMobile,
              AppTheme.marginMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStats(),
                const SizedBox(height: 24),
                _buildProtection(),
                const SizedBox(height: 24),
                _buildNotes(),
                const SizedBox(height: 28),
                _buildActionButton(context),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER — avatar + nombre + badges sobre fondo de color
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
        child: Column(
          children: [
            // Barra superior: atrás + compartir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.ios_share_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: compartir ficha
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: pet.photoUrl != null
                    ? Image.network(
                        pet.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarIcon(),
                      )
                    : _avatarIcon(),
              ),
            ),

            const SizedBox(height: 12),

            // Nombre
            Text(
              pet.name,
              style: AppTheme.headlineMd.copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),

            const SizedBox(height: 8),

            // Badges: raza + estado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pet.breed != null) ...[
                  _HeaderBadge(label: pet.breed!),
                  const SizedBox(width: 8),
                ],
                _HeaderBadge(
                  label: _statusLabel,
                  icon: _statusIcon,
                  isStatus: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarIcon() {
    return Icon(
      Icons.pets,
      size: 48,
      color: Colors.white.withValues(alpha: 0.8),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATS — grid 2×2
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Datos'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _StatCard(
              value: pet.ageYears != null ? '${pet.ageYears} años' : '—',
              label: 'Edad',
            ),
            _StatCard(
              value: pet.breed ?? '—',
              label: 'Raza',
            ),
            _StatCard(
              value: _daysLabel,
              label: pet.isLost ? 'Tiempo perdido' : 'Con ChowTrack',
              valueColor: pet.isLost ? AppColors.panicRed : null,
            ),
            _StatCard(
              value: pet.hasNoseScan ? 'Activa' : 'Pendiente',
              label: 'Biometría',
              valueColor: pet.hasNoseScan
                  ? AppColors.esmeraldGreen
                  : AppColors.alertAmber,
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROTECCIÓN
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildProtection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Protección'),
        _ProtectionRow(
          label: 'Nariz registrada',
          sublabel: pet.hasNoseScan
              ? 'Biometría activa'
              : 'Escanea la nariz para activarla',
          isOk: pet.hasNoseScan,
        ),
        const SizedBox(height: 8),
        _ProtectionRow(
          label: 'Foto de perfil',
          sublabel: pet.photoUrl != null
              ? 'Foto cargada correctamente'
              : 'Añade una foto para mejorar la búsqueda',
          isOk: pet.photoUrl != null,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTAS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Notas'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            pet.notes?.isNotEmpty == true
                ? pet.notes!
                : 'Sin notas añadidas.',
            style: AppTheme.bodyMd.copyWith(
              color: pet.notes?.isNotEmpty == true
                  ? null
                  : AppColors.outline,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOTÓN DE ACCIÓN
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildActionButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        // TODO: lógica de cambio de estado
      },
      icon: Icon(_actionIcon, color: _actionColor),
      label: Text(_actionLabel),
      style: OutlinedButton.styleFrom(
        foregroundColor: _actionColor,
        side: BorderSide(color: _actionColor.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 0),
      ),
    );
  }

  IconData get _actionIcon => switch (pet.status) {
        'lost'  => Icons.pets,
        'found' => Icons.home_outlined,
        _       => Icons.warning_amber_outlined,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVADOS
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isStatus;

  const _HeaderBadge({
    required this.label,
    this.icon,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isStatus
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTheme.labelSm.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.labelSm.copyWith(
          color: AppColors.outline,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _ProtectionRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isOk;

  const _ProtectionRow({
    required this.label,
    required this.sublabel,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOk ? AppColors.esmeraldGreen : AppColors.alertAmber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.bodyMd),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}