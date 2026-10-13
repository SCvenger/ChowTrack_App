// lib/features/pets/pet_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../health/controllers/health_reminders_controller.dart';
import '../health/health_view.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import 'controllers/pets_controller.dart';
import 'pet_status_actions.dart';

class PetDetailView extends StatefulWidget {
  final PetModel pet;

  const PetDetailView({super.key, required this.pet});

  @override
  State<PetDetailView> createState() => _PetDetailViewState();
}

class _PetDetailViewState extends State<PetDetailView> {
  // La mascota "viva" sale del PetsController: si su estado cambia desde
  // otra pantalla (p. ej. el botón de Home con este detalle abierto en el
  // tab Mascotas), el header se actualiza solo. Fallback: el snapshot que
  // recibió la pantalla (si la lista aún no está cargada).
  late PetModel pet = widget.pet;
  bool _isUpdating = false;

  // Se llama al inicio de build(): `watch` suscribe la pantalla a cambios.
  void _syncFromController() {
    final pets = context.watch<PetsController>().pets;
    for (final p in pets) {
      if (p.id == widget.pet.id) {
        pet = p;
        return;
      }
    }
  }

  // ── Color dinámico según estado ──────────────────────────────────────────
  Color get _headerColor => switch (pet.status) {
    'lost' => AppColors.panicRed,
    'found' => AppColors.trustBlue,
    // Verde legible: texto blanco sobre #50C878 quedaba en ~2.2:1
    _ => AppColors.readable(AppColors.esmeraldGreen),
  };

  String get _statusLabel => switch (pet.status) {
    'lost' => 'Perdido',
    'found' => 'En proceso',
    _ => 'En casa',
  };

  IconData get _statusIcon => switch (pet.status) {
    'lost' => Icons.warning_amber_outlined,
    'found' => Icons.manage_search,
    _ => Icons.home_outlined,
  };

  String get _actionLabel => switch (pet.status) {
    'lost' => 'Ya está en casa',
    'found' => 'Marcar como en casa',
    _ => 'Reportar como perdida',
  };

  // Verde legible para texto/borde del botón (el token puro no llega a 3:1)
  Color get _actionColor => pet.isHome
      ? AppColors.panicRed
      : AppColors.readable(AppColors.esmeraldGreen);

  // ═══════════════════════════════════════════════════════════════════════
  // CAMBIO DE ESTADO — mismo flujo que el botón de Home
  // lost/found → home (recuperada: verde 1h en el mapa, luego desaparece)
  // home       → lost (captura GPS para el pin en el mapa)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _handleStatusChange() async {
    final markingLost = pet.isHome;
    final confirmed = await PetStatusActions.confirm(
      context,
      pet,
      markingLost: markingLost,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isUpdating = true);
    final ok = await PetStatusActions.changeStatus(
      context,
      pet,
      markingLost: markingLost,
      askConfirmation: false,
    );
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      // Si la lista compartida no contenía la mascota, reflejar el cambio
      // localmente igual (el controller no la habría actualizado).
      if (ok && pet.isHome == markingLost) {
        pet = pet.copyWith(
          status: markingLost ? 'lost' : 'home',
          lastSeenAt: DateTime.now().toUtc().toIso8601String(),
        );
      }
    });
  }

  String get _daysLabel {
    if (pet.isLost) {
      // Días desde que se marcó como perdido (lastSeenAt), no desde createdAt
      if (pet.lastSeenAt != null) {
        final lostDate = DateTime.tryParse(pet.lastSeenAt!)?.toLocal();
        if (lostDate != null) {
          final days = DateTime.now().difference(lostDate).inDays;
          if (days == 0) return 'Hoy perdido';
          return '$days ${days == 1 ? "día" : "días"} perdido';
        }
      }
      return 'Recién perdido';
    }
    // Días con ChowTrack: siempre desde createdAt
    if (pet.createdAt == null) return '—';
    final days = DateTime.now().difference(pet.createdAt!).inDays;
    if (days == 0) return 'Desde hoy';
    return '$days ${days == 1 ? 'día' : 'días'}';
  }

  @override
  Widget build(BuildContext context) {
    _syncFromController();

    return Scaffold(
      backgroundColor: _headerColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          // ── Cuerpo blanco con curva superior ──────────────────────
          // FillRemaining: en pantallas altas el blanco llega hasta abajo
          // (antes quedaba una franja del color del header bajo el botón).
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
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
                  _buildHealthEntry(),
                  const SizedBox(height: 24),
                  _buildProtection(),
                  const SizedBox(height: 24),
                  _buildNotes(),
                  const SizedBox(height: 28),
                  _buildActionButton(context),
                  // Espacio para la nav bar flotante + safe area inferior
                  SizedBox(height: 88 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
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
            // Barra superior: atrás. (El botón "compartir" se quitó: no
            // hacía nada al tocarlo. Volver a agregarlo cuando exista.)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            const SizedBox(height: 8),

            // Avatar
            Hero(
              tag: 'pet-photo-${pet.id}',
              child: Container(
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
            ),

            const SizedBox(height: 12),

            // Nombre
            Semantics(
              header: true,
              child: Text(
                pet.name,
                textAlign: TextAlign.center,
                style: AppTheme.headlineMd.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Badges: raza + estado (Wrap: razas largas no desbordan)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pet.breed != null) _HeaderBadge(label: pet.breed!),
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
        // Filas fijas en vez de GridView: el cuerpo vive en un
        // SliverFillRemaining, que mide la altura intrínseca de su contenido,
        // y un GridView (viewport) no puede medirse así → el layout fallaba
        // y la pantalla quedaba solo con el fondo de color.
        _statsGrid([
          _StatCard(
            value: switch (pet.ageYears) {
              null => '—',
              1 => '1 año',
              final a => '$a años',
            },
            label: 'Edad',
          ),
          _StatCard(value: pet.breed ?? '—', label: 'Raza'),
          _StatCard(
            value: _daysLabel,
            label: pet.isLost ? 'Tiempo perdido' : 'Con ChowTrack',
            valueColor: pet.isLost
                ? AppColors.readable(AppColors.panicRed)
                : null,
          ),
          _StatCard(
            value: pet.hasNoseScan ? 'Activa' : 'Pendiente',
            label: 'Biometría',
            valueColor: AppColors.readable(
              pet.hasNoseScan ? AppColors.esmeraldGreen : AppColors.alertAmber,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _statsGrid(List<Widget> cards) {
    // IntrinsicHeight: ambas tarjetas de la fila con la misma altura, que
    // crece con el texto (letra grande del sistema) en vez de desbordarse.
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );
    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: 10),
        row(cards[2], cards[3]),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SALUD — acceso al módulo veterinario
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _openHealth() async {
    // Pantallas con formularios: la nav bar flotante taparía los botones
    final nav = context.read<NavigationController>();
    final reminders = context.read<HealthRemindersController>();
    nav.hideNavBar();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthView(petId: pet.id, petName: pet.name),
      ),
    );
    nav.showNavBar();
    reminders.load(); // los pendientes de Home pueden haber cambiado
  }

  Widget _buildHealthEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Salud'),
        Semantics(
          button: true,
          label:
              'Salud y carnet veterinario. Vacunas, citas, documentos '
              'y código QR para el veterinario',
          excludeSemantics: true,
          child: Material(
            color: AppColors.tintBlueBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _openHealth,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        color: AppColors.trustBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salud y carnet veterinario',
                            style: AppTheme.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vacunas, citas, documentos y QR para el vet',
                            style: AppTheme.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.trustBlue),
                  ],
                ),
              ),
            ),
          ),
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
            pet.notes?.isNotEmpty == true ? pet.notes! : 'Sin notas añadidas.',
            style: AppTheme.bodyMd.copyWith(
              color: pet.notes?.isNotEmpty == true ? null : AppColors.outline,
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
      onPressed: _isUpdating ? null : _handleStatusChange,
      icon: _isUpdating
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _actionColor,
              ),
            )
          : Icon(_actionIcon, color: _actionColor),
      label: Text(_isUpdating ? 'Actualizando…' : _actionLabel),
      style: OutlinedButton.styleFrom(
        foregroundColor: _actionColor,
        side: BorderSide(color: _actionColor.withValues(alpha: 0.4)),
        minimumSize: const Size(double.infinity, 56),
      ),
    );
  }

  IconData get _actionIcon => switch (pet.status) {
    'lost' => Icons.pets,
    'found' => Icons.home_outlined,
    _ => Icons.warning_amber_outlined,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVADOS
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isStatus;

  const _HeaderBadge({required this.label, this.icon, this.isStatus = false});

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
          Text(label, style: AppTheme.labelSm.copyWith(color: Colors.white)),
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

  const _StatCard({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
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
    // Ícono con información (ok/pendiente): necesita ≥3:1 → variante legible
    final color = AppColors.readable(
      isOk ? AppColors.esmeraldGreen : AppColors.alertAmber,
    );

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
