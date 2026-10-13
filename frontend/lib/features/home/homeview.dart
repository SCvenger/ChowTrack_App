// lib/features/home/home_view.dart

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';

import '../health/controllers/health_reminders_controller.dart';
import '../health/health_view.dart';
import '../health/models/health_models.dart';
import '../health/services/health_service.dart';
import '../health/utils/health_format.dart';
import '../health/utils/health_labels.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import '../pets/pet_status_actions.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  // Evita doble envío mientras se obtiene el GPS / se llama al backend
  // (puede tardar hasta ~10 s sin posición cacheada).
  bool _isReporting = false;

  // Mascotas cuyo "Ya está en casa" está en curso (spinner por fila)
  final Set<String> _markingHome = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Poblar PetsController compartido si aún no tiene datos
      final petsCtrl = context.read<PetsController>();
      if (petsCtrl.pets.isEmpty && !petsCtrl.isLoading) {
        petsCtrl.loadPets(silent: true);
      }

      // Inicializar GPS + mascotas del mapa (usado también por MapView)
      // initialize() es idempotente: si MapView ya la disparó, reutiliza el Future
      context.read<PetsMapController>().initialize();

      // Pendientes de salud (vacunas/desparasitaciones/citas)
      context.read<HealthRemindersController>().load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver a la app (ej. desde los ajustes de ubicación del sistema),
  // re-verifica el estado del GPS para que el banner SISTEMA se actualice
  // sin necesidad de reiniciar la aplicación.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PetsMapController>().refreshLocation();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIÓN: Marcar mascota como perdida con GPS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLostPetTapped() async {
    if (_isReporting) return;
    final petsController = context.read<PetsController>();

    // Si la lista aún no llegó (o falló la carga), reintentar antes de
    // decirle al usuario que no tiene mascotas.
    if (petsController.pets.isEmpty) {
      await petsController.loadPets(silent: true);
      if (!mounted) return;
    }
    final pets = petsController.pets;

    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            petsController.hasError
                ? 'No pudimos cargar tus mascotas. Revisa tu conexión.'
                : 'Aún no tienes mascotas registradas.',
          ),
        ),
      );
      return;
    }

    // Solo mascotas en casa: `found` lo gestiona el sistema (match biométrico)
    final candidates = pets.where((p) => p.isHome).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas tus mascotas ya están reportadas.'),
        ),
      );
      return;
    }

    PetModel? selected;

    if (candidates.length == 1) {
      final confirmed = await PetStatusActions.confirm(
        context,
        candidates.first,
        markingLost: true,
      );
      if (confirmed) selected = candidates.first;
    } else {
      // Ocultar la nav bar flotante mientras el sheet está abierto.
      // Elegir la mascota en el sheet ya es la confirmación explícita.
      final navBar = context.read<NavigationController>();
      navBar.hideNavBar();
      selected = await _showPetSelector(candidates);
      navBar.showNavBar();
    }

    if (selected == null || !mounted) return;

    setState(() => _isReporting = true);
    await PetStatusActions.changeStatus(
      context,
      selected,
      markingLost: true,
      askConfirmation: false,
    );
    if (mounted) setState(() => _isReporting = false);
  }

  Future<void> _openReminder(HealthReminderModel r) async {
    final nav = context.read<NavigationController>();
    final remindersCtrl = context.read<HealthRemindersController>();
    nav.hideNavBar();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthView(
          petId: r.petId,
          petName: r.petName,
          openSection: switch (r.kind) {
            'vaccination' => HealthResource.vaccinations,
            'deworming' => HealthResource.dewormings,
            _ => HealthResource.appointments,
          },
          highlightId: r.recordId,
        ),
      ),
    );
    nav.showNavBar();
    remindersCtrl.load();
  }

  Future<void> _onMarkHome(PetModel pet) async {
    if (_markingHome.contains(pet.id)) return;
    final confirmed = await PetStatusActions.confirm(
      context,
      pet,
      markingLost: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _markingHome.add(pet.id));
    await PetStatusActions.changeStatus(
      context,
      pet,
      markingLost: false,
      askConfirmation: false,
    );
    if (mounted) setState(() => _markingHome.remove(pet.id));
  }

  Future<PetModel?> _showPetSelector(List<PetModel> candidates) {
    return showModalBottomSheet<PetModel>(
      context: context,
      useRootNavigator: true, // por encima de la nav bar flotante
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
                  Text(
                    '¿Cuál de tus mascotas se perdió?',
                    style: AppTheme.headlineMd,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Publicaremos tu ubicación actual en el mapa.',
                    style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                  ),
                  AppTheme.spacerSm,
                  ...candidates.map(
                    (pet) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 64,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.outline,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.inputFill,
                        backgroundImage: pet.photoUrl != null
                            ? NetworkImage(pet.photoUrl!)
                            : null,
                        child: pet.photoUrl == null
                            ? const Icon(Icons.pets, color: AppColors.trustBlue)
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
    final reminders = context.watch<HealthRemindersController>().items;
    final lostPets = context
        .watch<PetsController>()
        .pets
        .where((p) => p.isLost)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.trustBlue,
          onRefresh: () => Future.wait([
            context.read<PetsController>().loadPets(silent: true),
            mapCtrl.loadPetsNearby(),
            context.read<HealthRemindersController>().load(),
          ]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile,
              AppTheme.stackMd,
              AppTheme.marginMobile,
              104,
            ),
            children: [
              // Banner GPS desactivado — aparece/desaparece con transición de tamaño
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: (!mapCtrl.locationEnabled && mapCtrl.isInitialized)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GpsBanner(
                            message: !mapCtrl.serviceEnabled
                                ? 'Tu GPS está apagado. Actívalo para '
                                      'reportar con tu ubicación exacta.'
                                : 'ChowTrack necesita permiso de ubicación '
                                      'para protegerte por completo.',
                            actionLabel: !mapCtrl.serviceEnabled
                                ? 'Activar'
                                : (mapCtrl.locationDenied
                                      ? 'Ajustes'
                                      : 'Permitir'),
                            // Resuelve la causa real (GPS apagado / permiso).
                            // Al volver de los ajustes, el lifecycle observer
                            // + el stream del GPS actualizan el banner solos.
                            onActivate: mapCtrl.requestLocationAccess,
                          ),
                          AppTheme.spacerMd,
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),

              // Card SISTEMA — mientras el GPS se verifica muestra un estado
              // neutro (antes arrancaba en "Alerta" y saltaba a "Protegido").
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: !mapCtrl.isInitialized && !mapCtrl.locationEnabled
                    ? const _SystemStatusCard(
                        key: ValueKey('checking'),
                        statusLabel: 'Verificando',
                        statusColor: AppColors.outline,
                        locationName: 'Comprobando tu ubicación…',
                      )
                    : _SystemStatusCard(
                        key: ValueKey(mapCtrl.locationEnabled),
                        statusLabel: mapCtrl.locationEnabled
                            ? 'Protegido'
                            : 'Alerta',
                        statusColor: mapCtrl.locationEnabled
                            ? AppColors.esmeraldGreen
                            : AppColors.alertAmber,
                        locationName: mapCtrl.locationEnabled
                            ? 'GPS activo'
                            : 'Ubicación desactivada',
                      ),
              ),

              // Mascotas reportadas como perdidas: acceso directo a
              // "Ya está en casa" sin tener que ir a Mis mascotas → detalle.
              if (lostPets.isNotEmpty) ...[
                AppTheme.spacerMd,
                _LostPetsCard(
                  pets: lostPets,
                  busyIds: _markingHome,
                  onMarkHome: _onMarkHome,
                ),
              ],

              AppTheme.spacerLg,

              // Botón PERDÍ A MI MASCOTA
              _ActionButton(
                label: _isReporting ? 'REPORTANDO…' : 'PERDÍ A MI MASCOTA',
                icon: Icons.campaign_outlined,
                color: AppColors.panicRed,
                isLoading: _isReporting,
                semanticsHint: 'Reporta a una de tus mascotas como perdida',
                onTap: _onLostPetTapped,
              ),

              AppTheme.spacerMd,

              // Botón ENCONTRÉ UN PERRO — funcionalidad futura, se muestra
              // como acción secundaria atenuada con badge en vez de un CTA
              // sólido que aparenta estar completamente activo.
              _ActionButton(
                label: 'ENCONTRÉ UN PERRO',
                icon: Icons.pets,
                color: AppColors.trustBlue,
                badge: 'Próximamente',
                semanticsHint: 'Función disponible próximamente',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente disponible')),
                  );
                },
              ),

              AppTheme.spacerLg,

              // Mapa real (preview)
              _MapPreview(
                mapCtrl: mapCtrl,
                onTap: () => context.read<NavigationController>().setIndex(1),
              ),

              // Pendientes de salud: va al final — es información de
              // cuidado, no debe competir con el flujo de emergencia.
              if (reminders.isNotEmpty) ...[
                AppTheme.spacerLg,
                _HealthRemindersCard(
                  reminders: reminders,
                  onOpen: _openReminder,
                ),
              ],
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
  final String message;
  final String actionLabel;
  final VoidCallback onActivate;

  const _GpsBanner({
    required this.message,
    required this.actionLabel,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.alertAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Ámbar legible (tintAmber): #FFC107 como texto sobre su propio
          // tinte no llegaba a 2:1 de contraste.
          const Icon(Icons.location_off, color: AppColors.tintAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.labelSm.copyWith(
                color: AppColors.tintAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onActivate,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.tintAmber,
              minimumSize: const Size(AppTheme.tapTarget, AppTheme.tapTarget),
            ),
            child: Text(actionLabel),
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
    super.key,
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
        border: Border(left: BorderSide(color: statusColor, width: 4)),
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
              Icon(
                Icons.location_on,
                size: 18,
                color: AppColors.readable(statusColor),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(locationName, style: AppTheme.bodyMd)),
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
              color: AppColors.readable(color),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MASCOTAS PERDIDAS — atajo para marcarlas de vuelta en casa
// ═════════════════════════════════════════════════════════════════════════════

class _LostPetsCard extends StatelessWidget {
  final List<PetModel> pets;
  final Set<String> busyIds;
  final ValueChanged<PetModel> onMarkHome;

  const _LostPetsCard({
    required this.pets,
    required this.busyIds,
    required this.onMarkHome,
  });

  String _since(PetModel pet) {
    final dt = pet.lastSeenAt != null
        ? DateTime.tryParse(pet.lastSeenAt!)?.toLocal()
        : null;
    if (dt == null) return 'Reportada como perdida';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Reportada hace un momento';
    if (diff.inMinutes < 60) return 'Reportada hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Reportada hace ${diff.inHours} h';
    final d = diff.inDays;
    return 'Reportada hace $d ${d == 1 ? 'día' : 'días'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: const Border(
          left: BorderSide(color: AppColors.panicRed, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pets.length == 1 ? 'EN BÚSQUEDA' : 'EN BÚSQUEDA (${pets.length})',
            style: AppTheme.labelSm.copyWith(
              color: AppColors.outline,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final pet in pets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.inputFill,
                    backgroundImage: pet.photoUrl != null
                        ? NetworkImage(pet.photoUrl!)
                        : null,
                    child: pet.photoUrl == null
                        ? const Icon(
                            Icons.pets,
                            size: 18,
                            color: AppColors.panicRed,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: AppTheme.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _since(pet),
                          style: AppTheme.labelSm.copyWith(
                            color: AppColors.readable(AppColors.panicRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busyIds.contains(pet.id)
                        ? null
                        : () => onMarkHome(pet),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.readable(
                        AppColors.esmeraldGreen,
                      ),
                      minimumSize: const Size(
                        AppTheme.tapTarget,
                        AppTheme.tapTarget,
                      ),
                    ),
                    icon: busyIds.contains(pet.id)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.home_outlined, size: 20),
                    label: const Text('Ya está en casa'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SALUD — pendientes de todas las mascotas (mismo layout que "En búsqueda")
// ═════════════════════════════════════════════════════════════════════════════

class _HealthRemindersCard extends StatelessWidget {
  final List<HealthReminderModel> reminders;
  final ValueChanged<HealthReminderModel> onOpen;

  const _HealthRemindersCard({required this.reminders, required this.onOpen});

  static String _when(HealthReminderModel r) {
    if (r.isAppointment) {
      return r.isOverdue
          ? 'Cita pasada · ¿ya fue?'
          : 'Cita: ${HealthFormat.dateTime(r.dueDate)}';
    }
    return HealthFormat.daysLeft(r.daysLeft);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = reminders.where((r) => r.isOverdue).length;
    final shown = reminders.take(3).toList();

    // Borde ámbar: el rojo en Home queda reservado a mascotas perdidas
    // (DESIGN.md: "el rojo nunca aparece en la UI en estado tranquilo").
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: AppColors.alertAmber, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overdue > 0
                ? 'SALUD · $overdue VENCIDO${overdue == 1 ? '' : 'S'}'
                : 'SALUD · PRÓXIMOS',
            style: AppTheme.labelSm.copyWith(
              color: AppColors.outline,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final r in shown)
            _HealthReminderRow(
              reminder: r,
              when: _when(r),
              onTap: () => onOpen(r),
            ),
          if (reminders.length > shown.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '+${reminders.length - shown.length} más en la sección '
                'Salud de cada mascota',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthReminderRow extends StatelessWidget {
  final HealthReminderModel reminder;
  final String when;
  final VoidCallback onTap;

  const _HealthReminderRow({
    required this.reminder,
    required this.when,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final color = AppColors.readable(
      r.isOverdue ? AppColors.panicRed : AppColors.alertAmber,
    );
    return Semantics(
      button: true,
      label: '${r.title}, ${r.petName}. $when',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTheme.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(HealthLabels.reminderIcon(r.kind), size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.title} · ${r.petName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyMd,
                      ),
                      Text(
                        when,
                        style: AppTheme.labelSm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final bool isLoading;
  final String? semanticsHint;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.isLoading = false,
    this.semanticsHint,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMuted = widget.badge != null;
    final Color fillColor = isMuted ? AppColors.disabledFill : widget.color;
    final Color fgColor = isMuted ? AppColors.outline : Colors.white;
    final Color iconBg = isMuted
        ? AppColors.outline.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.18);

    return Semantics(
      button: true,
      enabled: !widget.isLoading,
      label: widget.badge != null
          ? '${widget.label}, ${widget.badge}'
          : widget.label,
      hint: widget.semanticsHint,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          elevation: isMuted ? 0 : 4,
          shadowColor: widget.color.withValues(alpha: 0.4),
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.isLoading
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: fgColor,
                                  ),
                                )
                              : Icon(
                                  widget.icon,
                                  key: const ValueKey('icon'),
                                  color: fgColor,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: AppTheme.headlineMd.copyWith(
                          color: fgColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.outline.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.badge!,
                        style: AppTheme.labelSm.copyWith(
                          color: AppColors.outline,
                          fontWeight: FontWeight.w600,
                        ),
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
// MAP PREVIEW — mapa real no interactivo
// ═════════════════════════════════════════════════════════════════════════════

class _MapPreview extends StatelessWidget {
  final PetsMapController mapCtrl;
  final VoidCallback onTap;

  const _MapPreview({required this.mapCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lostCount = mapCtrl.countFor('perdidos');
    return Semantics(
      button: true,
      label:
          'Vista previa del mapa. '
          '${lostCount == 1 ? '1 mascota perdida' : '$lostCount mascotas perdidas'} cerca',
      hint: 'Abre el mapa completo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: !mapCtrl.isInitialized
                  ? const _MapPreviewSkeleton(key: ValueKey('skeleton'))
                  : _MapContent(key: const ValueKey('map'), mapCtrl: mapCtrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPreviewSkeleton extends StatelessWidget {
  const _MapPreviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.inputFill,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.trustBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cargando mapa...',
            style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _MapContent extends StatelessWidget {
  final PetsMapController mapCtrl;

  const _MapContent({super.key, required this.mapCtrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapa real no interactivo. `initialCenter` solo se lee al
        // crear el mapa: la key lo recrea cuando la ubicación cambia
        // de verdad (~100 m), p. ej. al activar el GPS después de abrir
        // la app — antes el preview se quedaba centrado en Cochabamba.
        FlutterMap(
          key: ValueKey(
            '${mapCtrl.userLatLng.latitude.toStringAsFixed(3)},'
            '${mapCtrl.userLatLng.longitude.toStringAsFixed(3)}',
          ),
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
                  borderColor: AppColors.trustBlue.withValues(alpha: 0.2),
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
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.trustBlue.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Pins de mascotas cercanas — ignora el chip de filtro del
            // MapView: el preview siempre muestra todo lo visible.
            MarkerLayer(
              markers: mapCtrl.visiblePets.map((pet) {
                return Marker(
                  point: pet.latLng,
                  width: 28,
                  height: 28,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pet.markerColor,
                      border: Border.all(color: Colors.white, width: 2),
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

        // Indicador "Ver mapa": antes era un botón de recentrar que no
        // hacía nada (affordance falsa). Ahora comunica la acción real
        // de tocar la tarjeta.
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver mapa',
                  style: AppTheme.labelSm.copyWith(
                    color: AppColors.trustBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_full,
                  size: 14,
                  color: AppColors.trustBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
