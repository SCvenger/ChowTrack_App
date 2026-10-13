// lib/features/health/models/health_models.dart
//
// Modelos del módulo Salud (contratos en backend/Actualizaciones/
// 2026-10-13_modulo_salud_veterinario.md, sección 4).
//
// Los registros de historial (vacunas, consultas, citas…) se manejan con
// [HealthRecord]: getters tipados sobre el JSON crudo. Así el formulario
// genérico puede editarlos campo por campo y cada lista lee lo que necesita
// sin 7 clases casi idénticas.

List<String> _strings(dynamic v) =>
    (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

double? _double(dynamic v) => (v as num?)?.toDouble();

// ═════════════════════════════════════════════════════════════════════════════
// REGISTRO GENÉRICO
// ═════════════════════════════════════════════════════════════════════════════

class HealthRecord {
  final Map<String, dynamic> raw;

  const HealthRecord(this.raw);

  String get id => raw['id'] as String;
  String? str(String key) {
    final v = raw[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  double? dbl(String key) => _double(raw[key]);
  bool flag(String key) => raw[key] as bool? ?? false;

  // Vacunas / desparasitaciones
  String get dueStatus => (raw['due_status'] as String?) ?? 'no_due_date';
  int? get daysUntilDue => raw['days_until_due'] as int?;
  bool get isSuperseded => dueStatus == 'superseded';

  // Citas
  String get appointmentStatus => (raw['status'] as String?) ?? 'scheduled';

  // Medicamentos
  bool get isActive => flag('is_active');

  // Documentos
  bool get isPdf => (raw['mime_type'] as String?) == 'application/pdf';
}

// ═════════════════════════════════════════════════════════════════════════════
// FICHA DE SALUD
// ═════════════════════════════════════════════════════════════════════════════

class HealthProfileModel {
  final Map<String, dynamic> raw;
  final String sex;
  final String? birthDate;
  final int? ageMonths;
  final String? color;
  final bool isSterilized;
  final String? microchipId;
  final String? bloodType;
  final List<String> allergies;
  final List<String> chronicConditions;
  final String? dietNotes;
  final String? vetName;
  final String? vetClinic;
  final String? vetPhone;
  final bool isRegistered;

  const HealthProfileModel({
    required this.raw,
    this.sex = 'unknown',
    this.birthDate,
    this.ageMonths,
    this.color,
    this.isSterilized = false,
    this.microchipId,
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.dietNotes,
    this.vetName,
    this.vetClinic,
    this.vetPhone,
    this.isRegistered = false,
  });

  factory HealthProfileModel.fromJson(Map<String, dynamic> json) =>
      HealthProfileModel(
        raw: json,
        sex: (json['sex'] as String?) ?? 'unknown',
        birthDate: json['birth_date'] as String?,
        ageMonths: json['age_months'] as int?,
        color: json['color'] as String?,
        isSterilized: (json['is_sterilized'] as bool?) ?? false,
        microchipId: json['microchip_id'] as String?,
        bloodType: json['blood_type'] as String?,
        allergies: _strings(json['allergies']),
        chronicConditions: _strings(json['chronic_conditions']),
        dietNotes: json['diet_notes'] as String?,
        vetName: json['vet_name'] as String?,
        vetClinic: json['vet_clinic'] as String?,
        vetPhone: json['vet_phone'] as String?,
        isRegistered: (json['is_registered'] as bool?) ?? false,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// RESUMEN (pantalla principal de Salud)
// ═════════════════════════════════════════════════════════════════════════════

class HealthCounts {
  final int vaccinations;
  final int dewormings;
  final int visits;
  final int medicationsActive;
  final int documents;

  const HealthCounts({
    this.vaccinations = 0,
    this.dewormings = 0,
    this.visits = 0,
    this.medicationsActive = 0,
    this.documents = 0,
  });

  factory HealthCounts.fromJson(Map<String, dynamic>? json) => HealthCounts(
    vaccinations: (json?['vaccinations'] as int?) ?? 0,
    dewormings: (json?['dewormings'] as int?) ?? 0,
    visits: (json?['visits'] as int?) ?? 0,
    medicationsActive: (json?['medications_active'] as int?) ?? 0,
    documents: (json?['documents'] as int?) ?? 0,
  );
}

class HealthSummaryModel {
  final String petId;
  final String petName;
  final String? photoUrl;
  final HealthProfileModel profile;
  final String vaccinationStatus;
  final String dewormingStatus;
  final HealthRecord? latestWeight;
  final HealthRecord? nextAppointment;
  final List<HealthRecord> activeMedications;
  final List<HealthReminderModel> reminders;
  final HealthCounts counts;

  const HealthSummaryModel({
    required this.petId,
    required this.petName,
    this.photoUrl,
    required this.profile,
    this.vaccinationStatus = 'no_records',
    this.dewormingStatus = 'no_records',
    this.latestWeight,
    this.nextAppointment,
    this.activeMedications = const [],
    this.reminders = const [],
    this.counts = const HealthCounts(),
  });

  factory HealthSummaryModel.fromJson(Map<String, dynamic> json) {
    HealthRecord? rec(dynamic v) =>
        v == null ? null : HealthRecord(v as Map<String, dynamic>);
    return HealthSummaryModel(
      petId: json['pet_id'] as String,
      petName: json['pet_name'] as String,
      photoUrl: json['photo_url'] as String?,
      profile: HealthProfileModel.fromJson(
        (json['profile'] as Map<String, dynamic>?) ?? {},
      ),
      vaccinationStatus:
          (json['vaccination_status'] as String?) ?? 'no_records',
      dewormingStatus: (json['deworming_status'] as String?) ?? 'no_records',
      latestWeight: rec(json['latest_weight']),
      nextAppointment: rec(json['next_appointment']),
      activeMedications: (json['active_medications'] as List<dynamic>? ?? [])
          .map((e) => HealthRecord(e as Map<String, dynamic>))
          .toList(),
      reminders: (json['reminders'] as List<dynamic>? ?? [])
          .map((e) => HealthReminderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: HealthCounts.fromJson(json['counts'] as Map<String, dynamic>?),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RECORDATORIOS
// ═════════════════════════════════════════════════════════════════════════════

class HealthReminderModel {
  final String petId;
  final String petName;
  final String kind; // vaccination | deworming | appointment
  final String recordId;
  final String title;
  final String dueDate;
  final int daysLeft;
  final bool isOverdue;

  const HealthReminderModel({
    required this.petId,
    required this.petName,
    required this.kind,
    required this.recordId,
    required this.title,
    required this.dueDate,
    required this.daysLeft,
    required this.isOverdue,
  });

  factory HealthReminderModel.fromJson(Map<String, dynamic> json) =>
      HealthReminderModel(
        petId: json['pet_id'] as String,
        petName: json['pet_name'] as String,
        kind: json['kind'] as String,
        recordId: json['record_id'] as String,
        title: json['title'] as String,
        dueDate: json['due_date'] as String,
        daysLeft: json['days_left'] as int,
        isOverdue: json['is_overdue'] as bool,
      );

  bool get isAppointment => kind == 'appointment';
}

// ═════════════════════════════════════════════════════════════════════════════
// COMPARTIR CON EL VETERINARIO
// ═════════════════════════════════════════════════════════════════════════════

class HealthShareModel {
  final String id;
  final String shareUrl;
  final String carnetUrl;
  final String expiresAt;
  final String? revokedAt;
  final String? lastAccessedAt;
  final bool isActive;
  final String? createdAt;

  const HealthShareModel({
    required this.id,
    required this.shareUrl,
    required this.carnetUrl,
    required this.expiresAt,
    this.revokedAt,
    this.lastAccessedAt,
    required this.isActive,
    this.createdAt,
  });

  factory HealthShareModel.fromJson(Map<String, dynamic> json) =>
      HealthShareModel(
        id: json['id'] as String,
        shareUrl: json['share_url'] as String,
        carnetUrl: json['carnet_url'] as String,
        expiresAt: json['expires_at'] as String,
        revokedAt: json['revoked_at'] as String?,
        lastAccessedAt: json['last_accessed_at'] as String?,
        isActive: (json['is_active'] as bool?) ?? false,
        createdAt: json['created_at'] as String?,
      );
}
