// lib/features/map/models/map_pet_model.dart

import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/app_theme.dart';
import 'package:flutter/material.dart';

class MapPetModel {
  final String id;
  final String name;
  final String status;   // lost | found
  final String? photoUrl;
  final String? breed;
  final double lat;
  final double lng;
  final bool isOwn;

  const MapPetModel({
    required this.id,
    required this.name,
    required this.status,
    required this.lat,
    required this.lng,
    this.photoUrl,
    this.breed,
    this.isOwn = false,
  });

  factory MapPetModel.fromJson(Map<String, dynamic> json) => MapPetModel(
        id:       json['id']        as String,
        name:     json['name']      as String,
        status:   json['status']    as String,
        lat:      (json['lat']      as num).toDouble(),
        lng:      (json['lng']      as num).toDouble(),
        photoUrl: json['photo_url'] as String?,
        breed:    json['breed']     as String?,
        isOwn:    (json['is_own']   as bool?) ?? false,
      );

  bool get isLost  => status == 'lost';
  bool get isFound => status == 'found';

  LatLng get latLng => LatLng(lat, lng);

  Color get markerColor => isLost ? AppColors.panicRed : AppColors.esmeraldGreen;
  String get statusLabel => isLost ? 'Perdido' : 'Avistado';

  @override
  String toString() => 'MapPetModel(id: $id, name: $name, status: $status)';
}