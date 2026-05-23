import 'dart:io';

class PetRegistrationData {
  final String name;
  final String breed;
  final int age;
  final File photo;      
  final File? nosePhoto;  
  final String? phone;    

  const PetRegistrationData({
    required this.name,
    required this.breed,
    required this.age,
    required this.photo,
    this.nosePhoto,
    this.phone,
  });

  /// Crea una copia con los campos que se actualicen en pasos posteriores.
  /// Permite ir construyendo el modelo paso a paso sin mutabilidad.
  PetRegistrationData copyWith({
    String? name,
    String? breed,
    int? age,
    File? photo,
    File? nosePhoto,
    String? phone,
  }) {
    return PetRegistrationData(
      name:      name      ?? this.name,
      breed:     breed     ?? this.breed,
      age:       age       ?? this.age,
      photo:     photo     ?? this.photo,
      nosePhoto: nosePhoto ?? this.nosePhoto,
      phone:     phone     ?? this.phone,
    );
  }

  @override
  String toString() =>
      'PetRegistrationData(name: $name, breed: $breed, age: $age, '
      'hasPhoto: ${photo.path.isNotEmpty}, '
      'hasNosePhoto: ${nosePhoto != null}, '
      'hasPhone: ${phone != null})';
}