// lib/features/pets/pet_status_actions.dart
//
// Flujo ÚNICO para que el usuario cambie el estado de su mascota
// (home → lost, lost/found → home). Lo usan HomeView y PetDetailView para
// que ambos botones se comporten igual: confirmación, captura GPS, PATCH,
// refresco inmediato del mapa y snackbar con acción "Ver mapa".
//
// `found` NO se asigna desde aquí: solo lo asigna el backend (match biométrico).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../map/controllers/map_controller.dart';
import '../navigation/navigation_controller.dart';
import '../petRegistration/models/pet_model.dart';
import 'controllers/pets_controller.dart';

class PetStatusActions {
  PetStatusActions._();

  /// Diálogo de confirmación. Explica la consecuencia visible en el mapa
  /// para que el usuario sepa qué verán los demás.
  static Future<bool> confirm(
    BuildContext context,
    PetModel pet, {
    required bool markingLost,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          markingLost
              ? '¿Reportar a ${pet.name} como perdida?'
              : '¿${pet.name} ya está en casa?',
        ),
        content: Text(
          markingLost
              ? 'Publicaremos tu ubicación actual en el mapa para que '
                    'las personas cercanas puedan ayudarte a buscarla.'
              : 'Aparecerá en verde en el mapa durante 1 hora para avisar '
                    'a quienes la estaban buscando.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppTheme.tapTarget),
              backgroundColor: markingLost
                  ? AppColors.panicRed
                  : AppColors.readable(AppColors.esmeraldGreen),
            ),
            child: Text(markingLost ? 'Sí, reportar' : 'Sí, está en casa'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Cambia el estado y da feedback. Devuelve `true` si se guardó.
  static Future<bool> changeStatus(
    BuildContext context,
    PetModel pet, {
    required bool markingLost,
    bool askConfirmation = true,
  }) async {
    if (askConfirmation &&
        !await confirm(context, pet, markingLost: markingLost)) {
      return false;
    }
    if (!context.mounted) return false;

    // Capturar dependencias antes de los await (el context puede desmontarse)
    final petsCtrl = context.read<PetsController>();
    final mapCtrl = context.read<PetsMapController>();
    final nav = context.read<NavigationController>();
    final messenger = ScaffoldMessenger.of(context);

    double? lat;
    double? lng;
    if (markingLost) {
      (lat, lng) = await _currentCoords(mapCtrl);
    }

    try {
      await petsCtrl.updatePetStatus(
        pet.id,
        markingLost ? 'lost' : 'home',
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo actualizar a ${pet.name}. '
              'Revisa tu conexión e inténtalo de nuevo.',
            ),
            backgroundColor: AppColors.panicRed,
          ),
        );
      return false;
    }

    HapticFeedback.mediumImpact();

    // El pin aparece/cambia de color de inmediato (preview de Home + MapView)
    mapCtrl.loadPetsNearby();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            markingLost
                ? '${pet.name} marcada como perdida'
                : '${pet.name} está de vuelta en casa',
          ),
          backgroundColor: markingLost
              ? AppColors.panicRed
              : AppColors.readable(AppColors.esmeraldGreen),
          // Con acción, el SnackBar es persistente por defecto: se fuerza
          // auto-cierre para que no quede tapando la pantalla.
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ver mapa',
            textColor: Colors.white,
            onPressed: () => nav.setIndex(1),
          ),
        ),
      );
    return true;
  }

  /// Prioridad GPS: 1) posición cacheada del controller, 2) última conocida
  /// (instantánea), 3) adquirir nueva (hasta 10 s). Fallback final: la
  /// posición del mapa (GPS real o Cochabamba) — sin coordenadas el backend
  /// filtra la mascota y el pin no aparece en el mapa de otros usuarios.
  static Future<(double, double)> _currentCoords(
    PetsMapController mapCtrl,
  ) async {
    double? lat = mapCtrl.userPosition?.latitude;
    double? lng = mapCtrl.userPosition?.longitude;

    if (lat == null || lng == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          lat = last.latitude;
          lng = last.longitude;
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}
    }

    return (
      lat ?? mapCtrl.userLatLng.latitude,
      lng ?? mapCtrl.userLatLng.longitude,
    );
  }
}
