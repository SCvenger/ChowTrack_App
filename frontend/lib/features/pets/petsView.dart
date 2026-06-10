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
    // Refresca desde el controller compartido
    context.read<PetsController>().loadPets();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis mascotas', style: AppTheme.headlineMd),
            if (!ctrl.isLoading && !ctrl.hasError)
              Text(
                ctrl.pets.isEmpty
                    ? 'Aún no tienes ninguna'
                    : ctrl.pets.length == 1
                        ? '1 mascota registrada'
                        : '${ctrl.pets.length} mascotas registradas',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
          ],
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
    if (ctrl.isLoading) return const _LoadingState();
    if (ctrl.hasError) {
      return _ErrorState(
        message: ctrl.error!,
        onRetry: () => context.read<PetsController>().loadPets(),
      );
    }
    if (ctrl.pets.isEmpty) return _EmptyState(onAddPet: _openAddPet);

    return RefreshIndicator(
      color: AppColors.trustBlue,
      onRefresh: () => context.read<PetsController>().loadPets(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          104,
        ),
        itemCount: ctrl.pets.length,
        separatorBuilder: (_, __) => AppTheme.spacer,
        itemBuilder: (_, index) => _PetCard(pet: ctrl.pets[index]),
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
    return Container(
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
                _PetPhoto(photoUrl: pet.photoUrl, name: pet.name),
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
                          pet.ageYears == 1 ? '1 año' : '${pet.ageYears} años',
                          style: AppTheme.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.outline),
              ],
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

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'lost'  => ('Perdido', AppColors.panicRed),
      'found' => ('Encontrado', AppColors.trustBlue),
      _       => ('En casa', AppColors.esmeraldGreen),
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
          color: color,
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
      separatorBuilder: (_, __) => AppTheme.spacer,
      itemBuilder: (_, __) => Container(
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
              child: const Icon(Icons.pets,
                  size: 48, color: AppColors.trustBlue),
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
            Icon(Icons.cloud_off_outlined,
                size: 64,
                color: AppColors.outline.withValues(alpha: 0.5)),
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