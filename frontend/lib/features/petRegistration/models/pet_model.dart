// lib/features/petRegistration/models/pet_model.dart
// CAMBIO: añadido campo hasNoseScan + copyWith

class PetModel {
  final String id;
  final String ownerId;
  final String name;
  final String? breed;
  final int? ageYears;
  final String? photoUrl;
  final String status;  // home | lost | found
  final String? notes;
  final DateTime? createdAt;
  final bool hasNoseScan;

  const PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.breed,
    this.ageYears,
    this.photoUrl,
    this.status = 'home',
    this.notes,
    this.createdAt,
    this.hasNoseScan = false,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
        id:          json['id']        as String,
        ownerId:     json['owner_id']  as String,
        name:        json['name']      as String,
        breed:       json['breed']     as String?,
        ageYears:    json['age_years'] as int?,
        photoUrl:    json['photo_url'] as String?,
        status:      (json['status']   as String?) ?? 'home',
        notes:       json['notes']     as String?,
        createdAt:   json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        hasNoseScan: (json['has_nose_scan'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'owner_id':      ownerId,
        'name':          name,
        'breed':         breed,
        'age_years':     ageYears,
        'photo_url':     photoUrl,
        'status':        status,
        'notes':         notes,
        'created_at':    createdAt?.toIso8601String(),
        'has_nose_scan': hasNoseScan,
      };

  bool get isHome  => status == 'home';
  bool get isLost  => status == 'lost';
  bool get isFound => status == 'found';

  PetModel copyWith({
    String? status,
    bool? hasNoseScan,
  }) =>
      PetModel(
        id: id,
        ownerId: ownerId,
        name: name,
        breed: breed,
        ageYears: ageYears,
        photoUrl: photoUrl,
        status: status ?? this.status,
        notes: notes,
        createdAt: createdAt,
        hasNoseScan: hasNoseScan ?? this.hasNoseScan,
      );

  @override
  String toString() =>
      'PetModel(id: $id, name: $name, status: $status, hasNoseScan: $hasNoseScan)';
}