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
  });
 
  // ── Serialización — único lugar donde Map<String, dynamic> está permitido ──
 
  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id:        json['id']        as String,
    ownerId:   json['owner_id']  as String,
    name:      json['name']      as String,
    breed:     json['breed']     as String?,
    ageYears:  json['age_years'] as int?,
    photoUrl:  json['photo_url'] as String?,
    status:    (json['status']   as String?) ?? 'home',
    notes:     json['notes']     as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );
 
  Map<String, dynamic> toJson() => {
    'id':         id,
    'owner_id':   ownerId,
    'name':       name,
    'breed':      breed,
    'age_years':  ageYears,
    'photo_url':  photoUrl,
    'status':     status,
    'notes':      notes,
    'created_at': createdAt?.toIso8601String(),
  };
 
  // ── Estado de la mascota ──────────────────────────────────────────
 
  bool get isHome  => status == 'home';
  bool get isLost  => status == 'lost';
  bool get isFound => status == 'found';
 
  @override
  String toString() =>
      'PetModel(id: $id, name: $name, breed: $breed, status: $status)';
}