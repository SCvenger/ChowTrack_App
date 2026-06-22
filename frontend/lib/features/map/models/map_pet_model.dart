// lib/features/map/models/map_pet_model.dart

import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/app_theme.dart';
import 'package:flutter/material.dart';

class MapPetModel {
  final String id;
  final String name;
  final String status;   // lost | home (found nunca llega al cliente)
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

  // Perdida = rojo; recuperada (home reciente) = verde
  Color get markerColor =>
      isLost ? AppColors.panicRed : AppColors.esmeraldGreen;

  /// Regla de visibilidad en el mapa (SDD §2.2):
  /// - lost  → siempre visible
  /// - home  → visible 1h tras la recuperación
  /// - found → nunca visible
  ///
  /// Si lastSeenAt es null el backend ya filtró por tiempo → confiar en él.
  bool shouldShowOnMap() {
    if (isLost) return true;
    if (isHome) {
      if (lastSeenAt == null) return true; // backend ya filtró, confiamos
      final dt = DateTime.tryParse(lastSeenAt!);
      if (dt == null) return true;
      return DateTime.now().difference(dt.toLocal()).inHours < 1;
    }
    return false;
  }

  String get statusLabel => switch (status) {
        'lost'  => 'Perdido',
        'home'  => 'En casa',
        _       => 'Avistado',
      };

  @override
  String toString() => 'MapPetModel(id: $id, name: $name, status: $status)';
}