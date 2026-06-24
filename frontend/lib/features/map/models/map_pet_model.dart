// lib/features/map/models/map_pet_model.dart

import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/app_theme.dart';
import 'package:flutter/material.dart';

class MapPetModel {
  final String id;
  final String name;
  final String status;   // lost | found (match azul) | home
  final String? photoUrl;
  final String? breed;
  final double lat;
  final double lng;
  final bool isOwn;
  final String? lastSeenAt; // ISO timestamp; para la regla de 1h en home

  const MapPetModel({
    required this.id,
    required this.name,
    required this.status,
    required this.lat,
    required this.lng,
    this.photoUrl,
    this.breed,
    this.isOwn = false,
    this.lastSeenAt,
  });

  factory MapPetModel.fromJson(Map<String, dynamic> json) => MapPetModel(
        id:          json['id']           as String,
        name:        json['name']         as String,
        status:      json['status']       as String,
        lat:         (json['lat']         as num).toDouble(),
        lng:         (json['lng']         as num).toDouble(),
        photoUrl:    json['photo_url']    as String?,
        breed:       json['breed']        as String?,
        isOwn:       (json['is_own']      as bool?) ?? false,
        lastSeenAt:  json['last_seen_at'] as String?,
      );

  bool get isLost  => status == 'lost';
  bool get isFound => status == 'found';
  bool get isHome  => status == 'home';

  LatLng get latLng => LatLng(lat, lng);

  // Perdida = rojo; match detectado (found) = azul; recuperada (home) = verde
  Color get markerColor {
    if (isLost)  return AppColors.panicRed;
    if (isFound) return AppColors.trustBlue;
    return AppColors.esmeraldGreen;
  }

  /// Regla de visibilidad en el mapa:
  /// - lost  → siempre visible
  /// - found → siempre visible (hasta que el dueño marque como home)
  /// - home  → visible 1h tras la recuperación
  ///
  /// Si lastSeenAt es null el backend ya filtró por tiempo → confiar en él.
  bool shouldShowOnMap() {
    if (isLost || isFound) return true;
    if (isHome) {
      if (lastSeenAt == null) return true;
      final dt = DateTime.tryParse(lastSeenAt!);
      if (dt == null) return true;
      return DateTime.now().difference(dt.toLocal()).inHours < 1;
    }
    return false;
  }

  String get statusLabel => switch (status) {
        'lost'  => 'Perdido',
        'home'  => 'En casa',
        'found' => 'En proceso',
        _       => 'Avistado',
      };

  @override
  String toString() => 'MapPetModel(id: $id, name: $name, status: $status)';
}