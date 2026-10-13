// lib/features/pets/pets_view.dart

import 'package:chowtrack/features/petRegistration/wizard.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import 'pet_detail_view.dart';

class PetsView extends StatefulWidget {
  const PetsView({super.key});

  @override
  State<PetsView> createState() => _PetsViewState();
}

class _PetsViewState extends State<PetsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<PetsController>();
      // Carga solo si el estado está vacío y no hay carga en curso
      if (ctrl.pets.isEmpty && !ctrl.isLoading) {
        ctrl.loadPets();
      }
    });
  }

  Future<void> _openAddPet() async {
    final navController = context.read<NavigationController>();
    navController.hideNavBar();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PetRegistrationWizard(isFirstRegistration: false),
      ),
    );

    if (!mounted) return;
    navController.showNavBar();
    // Refresca en silencio: la lista actual sigue visible mientras llega
    // la nueva (antes parpadeaba al skeleton al volver del wizard).
    context.read<PetsController>().loadPets(silent: true);
  }

  Future<void> _refresh() async {
    final ctrl = context.read<PetsController>();
    await ctrl.loadPets(silent: true);
    if (!mounted || !ctrl.hasError) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ctrl.error!)));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PetsController>();

    return Scaffold(
      backgroundColor: AppColors.surface,

      // ── Header ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppTheme.marginMobile,
        title: Semantics(
          header: true,
          child: Text('Mis mascotas', style: AppTheme.headlineMd),
        ),
        toolbarHeight: 72,
      ),

      // ── Contenido ────────────────────────────────────────────────────
      body: _buildBody(ctrl),

      // ── FAB ──────────────────────────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: FloatingActionButton(
          onPressed: _openAddPet,
          backgroundColor: AppColors.trustBlue,
          shape: const CircleBorder(),
          tooltip: 'Añadir mascota',
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildBody(PetsController ctrl) {
    // Skeleton/error a pantalla completa SOLO si no hay nada que mostrar.
    // Antes, cualquier recarga (incluido el pull-to-refresh) reemplazaba la
    // lista por el skeleton y desmontaba el propio RefreshIndicator.
    if (ctrl.pets.isEmpty) {
      if (ctrl.isLoading) return const _LoadingState();
      if (ctrl.hasError) {
        return _ErrorState(
          message: ctrl.error!,
          onRetry: () => context.read<PetsController>().loadPets(),
        );
      }
      return _EmptyState(onAddPet: _openAddPet);
    }

    return RefreshIndicator(
      color: AppColors.trustBlue,
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          104,
        ),
        itemCount: ctrl.pets.length,
        separatorBuilder: (_, _) => AppTheme.spacer,
        itemBuilder: (_, index) => _StaggeredEntrance(
          index: index,
          child: _PetCard(pet: ctrl.pets[index]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ENTRADA ESCALONADA — fade + slide-up con delay progresivo por índice
// ═════════════════════════════════════════════════════════════════════════════

class _StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({required this.index, required this.child});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final cappedIndex = widget.index > 10 ? 10 : widget.index;
    // Sin animación si el sistema pide reducir movimiento
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _visible = true;
      return;
    }
    Future.delayed(Duration(milliseconds: 35 * cappedIndex), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PET CARD
// ═════════════════════════════════════════════════════════════════════════════

class _PetCard extends StatelessWidget {
  final PetModel pet;

  const _PetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final age = pet.ageYears == null
        ? ''
        : ', ${pet.ageYears == 1 ? '1 año' : '${pet.ageYears} años'}';
    return Semantics(
      button: true,
      label:
          '${pet.name}, ${_StatusBadge.labelFor(pet.status)}'
          '${pet.breed != null ? ', ${pet.breed}' : ''}$age',
      hint: 'Ver ficha',
      excludeSemantics: true,
      child: Container(
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
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PetDetailView(pet: pet)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: Row(
                children: [
                  Hero(
                    tag: 'pet-photo-${pet.id}',
                    child: _PetPhoto(photoUrl: pet.photoUrl, name: pet.name),
                  ),
                  const SizedBox(width: AppTheme.gutter),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pet.name,
                                style: AppTheme.bodyMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusBadge(status: pet.status),
                          ],
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
                        if (pet.ageYears != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            pet.ageYears == 1
                                ? '1 año'
                                : '${pet.ageYears} años',
                            style: AppTheme.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PET PHOTO
// ═════════════════════════════════════════════════════════════════════════════

class _PetPhoto extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _PetPhoto({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.inputFill,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTheme.headlineMd.copyWith(color: AppColors.trustBlue),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  static String labelFor(String status) => switch (status) {
    'lost' => 'Perdido',
    'found' => 'En proceso',
    _ => 'En casa',
  };

  @override
  Widget build(BuildContext context) {
    final label = labelFor(status);
    final color = switch (status) {
      'lost' => AppColors.panicRed,
      'found' => AppColors.trustBlue,
      _ => AppColors.esmeraldGreen,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.labelSm.copyWith(
          color: AppColors.readable(color),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ESTADOS DE PANTALLA
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      itemCount: 3,
      separatorBuilder: (_, _) => AppTheme.spacer,
      itemBuilder: (_, _) => Container(
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPet;

  const _EmptyState({required this.onAddPet});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.trustBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets,
                size: 48,
                color: AppColors.trustBlue,
              ),
            ),
            AppTheme.spacerMd,
            Text('Aún no tienes mascotas', style: AppTheme.headlineMd),
            AppTheme.spacerSm,
            Text(
              'Registra a tu compañero para\nmantenerlo protegido con ChowTrack.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
            ),
            AppTheme.spacerLg,
            FilledButton.icon(
              onPressed: onAddPet,
              icon: const Icon(Icons.add),
              label: const Text('Registrar primera mascota'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
            AppTheme.spacerMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
            ),
            AppTheme.spacerMd,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
