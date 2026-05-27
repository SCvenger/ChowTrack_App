// lib/features/pets/pets_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/services/pet_service.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import '../petRegistration/wizard.dart';

class PetsView extends StatefulWidget {
  const PetsView({super.key});

  @override
  State<PetsView> createState() => _PetsViewState();
}

class _PetsViewState extends State<PetsView> {
  List<PetModel> _pets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pets = await PetService.getMyPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _isLoading = false;
      });
    } on PetServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus mascotas.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddPet() async {
    final navController = context.read<NavigationController>();
    navController.hideNavBar();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PetRegistrationWizard(
          isFirstRegistration: false,
        ),
      ),
    );

    if (!mounted) return;
    navController.showNavBar();
    _loadPets(); // Refresca la lista al volver del wizard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,

      // ── Header ─────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppTheme.marginMobile,
        title: Column( 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis mascotas', style: AppTheme.headlineMd, ),
          ],
        ),
        toolbarHeight: 72,
        centerTitle: true
      ),

      body: _buildBody(),

      //  Añadir mascota 
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

  Widget _buildBody() {
    if (_isLoading) return const _LoadingState();
    if (_error != null) return _ErrorState(message: _error!, onRetry: _loadPets);
    if (_pets.isEmpty) return _EmptyState(onAddPet: _openAddPet);

    return RefreshIndicator(
      color: AppColors.trustBlue,
      onRefresh: _loadPets,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          104, // espacio para FAB + nav bar flotante
        ),
        itemCount: _pets.length,
        separatorBuilder: (_, _) => AppTheme.spacer,
        itemBuilder: (_, index) => _PetCard(pet: _pets[index]),
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
        color: Colors.white70,
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:.16),
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
          onTap: () {
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gutter),
            child: Row(
              children: [
                // ── Foto ────────────────────────────────────────────
                _PetPhoto(photoUrl: pet.photoUrl, name: pet.name),

                const SizedBox(width: AppTheme.gutter),

                // ── Datos ───────────────────────────────────────────
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

                      const SizedBox(height: 4),

                      if (pet.breed != null)
                        Text(
                          pet.breed!,
                          style: AppTheme.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),

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

              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PET PHOTO — Foto o placeholder con inicial del nombre
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
// STATUS BADGE — chip de estado de la mascota
// ═════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'lost'  => ('Perdido', AppColors.panicRed),
      'found' => ('Encontrado', AppColors.trustBlue),
      _       => ('Casa', AppColors.esmeraldGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ESTADOS DE LA PANTALLA
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      itemCount: 3,
      separatorBuilder: (_, _) => AppTheme.spacer,
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
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
                color: AppColors.trustBlue.withValues(alpha: .08),
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
              color: AppColors.outline.withValues(alpha: .5),
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