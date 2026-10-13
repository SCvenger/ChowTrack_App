// lib/features/health/health_sections.dart
//
// Configuración declarativa de cada sección de historial de Salud:
// campos del formulario (con las mismas reglas que el backend), cómo se
// resume cada registro en su tarjeta y acciones extra (p. ej. cerrar citas).
// La pantalla genérica HealthRecordsView consume esto.

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'health_form_view.dart';
import 'models/health_models.dart';
import 'services/health_service.dart';
import 'utils/health_format.dart';
import 'utils/health_labels.dart';
import 'widgets/health_widgets.dart';

/// Datos que se pintan en la tarjeta de un registro (mismo layout en todas
/// las secciones → coherencia visual).
class HealthTileData {
  final String title;
  final String? subtitle;
  final List<(IconData, String)> lines;
  final StatusPill? pill;
  final IconData icon;
  final Widget? leading; // reemplaza el ícono (miniatura de documento)
  final bool dimmed;

  const HealthTileData({
    required this.title,
    required this.icon,
    this.subtitle,
    this.lines = const [],
    this.pill,
    this.leading,
    this.dimmed = false,
  });
}

/// Acción rápida sobre un registro (menú de la tarjeta)
class HealthRecordAction {
  final String label;
  final IconData icon;
  final Map<String, dynamic> patch;
  final bool Function(HealthRecord) visible;
  final String doneMessage;

  const HealthRecordAction({
    required this.label,
    required this.icon,
    required this.patch,
    required this.visible,
    required this.doneMessage,
  });
}

class HealthSection {
  final HealthResource resource;
  final String title;
  final String singular; // "vacuna" → "Agregar vacuna", "Vacuna guardada"
  final bool feminine;
  final IconData icon;
  final Color tint;
  final Color tintBg;
  final String emptyTitle;
  final String emptyMessage;
  final List<HealthField> fields;
  final Map<String, dynamic> Function()? defaults;
  final HealthTileData Function(HealthRecord) tile;
  final List<HealthRecordAction> actions;

  const HealthSection({
    required this.resource,
    required this.title,
    required this.singular,
    this.feminine = true,
    required this.icon,
    required this.tint,
    required this.tintBg,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.fields,
    required this.tile,
    this.defaults,
    this.actions = const [],
  });

  String get savedMessage =>
      '${singular[0].toUpperCase()}${singular.substring(1)} '
      '${feminine ? 'guardada' : 'guardado'}';
  String get deletedMessage =>
      '${singular[0].toUpperCase()}${singular.substring(1)} '
      '${feminine ? 'eliminada' : 'eliminado'}';

  static HealthSection of(HealthResource r) => switch (r) {
    HealthResource.vaccinations => vaccinations,
    HealthResource.dewormings => dewormings,
    HealthResource.visits => visits,
    HealthResource.medications => medications,
    HealthResource.weights => weights,
    HealthResource.appointments => appointments,
    HealthResource.documents => documents,
  };

  // ═══════════════════════════════════════════════════════════════════════
  // CAMPOS COMUNES
  // ═══════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _today(String key) {
    final n = DateTime.now();
    return {key: DateTime(n.year, n.month, n.day)};
  }

  static const _vetName = HealthField(
    'vet_name',
    'Veterinario/a',
    maxLength: 80,
    icon: Icons.person_outline,
  );
  static const _clinic = HealthField(
    'clinic_name',
    'Clínica',
    maxLength: 100,
    icon: Icons.local_hospital_outlined,
  );
  static const _notes = HealthField(
    'notes',
    'Notas',
    kind: HealthFieldKind.multiline,
    maxLength: 500,
  );
  static const _weightKg = HealthField(
    'weight_kg',
    'Peso',
    kind: HealthFieldKind.decimal,
    suffix: 'kg',
    min: 0,
    max: 150,
    minExclusive: true,
  );

  static StatusPill _duePill(HealthRecord r) {
    final style = HealthLabels.dueStatus(r.dueStatus);
    final text = switch (r.dueStatus) {
      'due_soon' || 'overdue' => HealthFormat.daysLeft(r.daysUntilDue),
      _ => null,
    };
    return StatusPill(style: style, text: text);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VACUNAS
  // ═══════════════════════════════════════════════════════════════════════

  static final vaccinations = HealthSection(
    resource: HealthResource.vaccinations,
    title: 'Cartilla de vacunación',
    singular: 'vacuna',
    icon: Icons.vaccines_outlined,
    tint: AppColors.trustBlue,
    tintBg: AppColors.tintBlueBg,
    emptyTitle: 'Sin vacunas registradas',
    emptyMessage:
        'Registra cada vacuna con su fecha de refuerzo y te avisaremos '
        'antes de que venza.',
    defaults: () => _today('applied_at'),
    fields: const [
      HealthField(
        'vaccine_name',
        'Nombre de la vacuna',
        required: true,
        minLength: 2,
        maxLength: 80,
        hint: 'Ej. Antirrábica',
        icon: Icons.vaccines_outlined,
      ),
      HealthField(
        'vaccine_type',
        'Tipo',
        kind: HealthFieldKind.choice,
        options: HealthLabels.vaccineTypes,
        defaultValue: 'other',
        helper:
            'Agrupa las renovaciones: una antirrábica nueva reemplaza '
            'a la anterior en las alertas.',
      ),
      HealthField(
        'applied_at',
        'Fecha de aplicación',
        kind: HealthFieldKind.date,
        required: true,
        pastOnly: true,
      ),
      HealthField(
        'next_due_at',
        'Próximo refuerzo',
        kind: HealthFieldKind.date,
        afterKey: 'applied_at',
        helper: 'Te recordaremos antes de esta fecha.',
        quickDays: [('+21 días', 21), ('+6 meses', 182), ('+1 año', 365)],
      ),
      HealthField(
        'dose_number',
        'Número de dosis',
        kind: HealthFieldKind.integer,
        min: 1,
        max: 20,
        hint: 'Ej. 1',
      ),
      HealthField(
        'batch_number',
        'Lote',
        maxLength: 50,
        hint: 'Figura en el sticker de la vacuna',
      ),
      _vetName,
      _clinic,
      _notes,
    ],
    tile: (r) => HealthTileData(
      title: r.str('vaccine_name') ?? 'Vacuna',
      icon: Icons.vaccines_outlined,
      subtitle: [
        HealthLabels.vaccineTypes[r.str('vaccine_type')] ?? 'Otra',
        if (r.str('dose_number') != null) 'Dosis ${r.str('dose_number')}',
      ].join(' · '),
      lines: [
        (
          Icons.event_available_outlined,
          'Aplicada el ${HealthFormat.date(r.str('applied_at'))}',
        ),
        if (r.str('next_due_at') != null && !r.isSuperseded)
          (
            Icons.update,
            'Refuerzo: ${HealthFormat.date(r.str('next_due_at'))}',
          ),
        if (r.str('vet_name') != null || r.str('clinic_name') != null)
          (
            Icons.local_hospital_outlined,
            [r.str('vet_name'), r.str('clinic_name')].nonNulls.join(' · '),
          ),
      ],
      pill: _duePill(r),
      dimmed: r.isSuperseded,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // DESPARASITACIONES
  // ═══════════════════════════════════════════════════════════════════════

  static final dewormings = HealthSection(
    resource: HealthResource.dewormings,
    title: 'Desparasitaciones',
    singular: 'desparasitación',
    icon: Icons.bug_report_outlined,
    tint: AppColors.tintPurple,
    tintBg: AppColors.tintPurpleBg,
    emptyTitle: 'Sin desparasitaciones',
    emptyMessage:
        'Registra el producto y la próxima dosis para no olvidar la siguiente.',
    defaults: () => _today('applied_at'),
    fields: const [
      HealthField(
        'product_name',
        'Producto',
        required: true,
        minLength: 2,
        maxLength: 80,
        hint: 'Ej. Drontal Plus',
        icon: Icons.medication_outlined,
      ),
      HealthField(
        'deworming_type',
        'Tipo',
        kind: HealthFieldKind.choice,
        options: HealthLabels.dewormingTypes,
        defaultValue: 'internal',
      ),
      HealthField(
        'applied_at',
        'Fecha de aplicación',
        kind: HealthFieldKind.date,
        required: true,
        pastOnly: true,
      ),
      HealthField(
        'next_due_at',
        'Próxima dosis',
        kind: HealthFieldKind.date,
        afterKey: 'applied_at',
        quickDays: [('+1 mes', 30), ('+3 meses', 91), ('+6 meses', 182)],
      ),
      HealthField(
        'weight_kg',
        'Peso al aplicar',
        kind: HealthFieldKind.decimal,
        suffix: 'kg',
        min: 0,
        max: 150,
        minExclusive: true,
        helper: 'La dosis suele depender del peso.',
      ),
      _notes,
    ],
    tile: (r) => HealthTileData(
      title: r.str('product_name') ?? 'Desparasitación',
      icon: Icons.bug_report_outlined,
      subtitle: HealthLabels.dewormingTypes[r.str('deworming_type')],
      lines: [
        (
          Icons.event_available_outlined,
          'Aplicada el ${HealthFormat.date(r.str('applied_at'))}',
        ),
        if (r.str('next_due_at') != null && !r.isSuperseded)
          (Icons.update, 'Próxima: ${HealthFormat.date(r.str('next_due_at'))}'),
        if (r.dbl('weight_kg') != null)
          (
            Icons.monitor_weight_outlined,
            '${HealthFormat.number(r.dbl('weight_kg'))} kg',
          ),
      ],
      pill: _duePill(r),
      dimmed: r.isSuperseded,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // CONSULTAS
  // ═══════════════════════════════════════════════════════════════════════

  static final visits = HealthSection(
    resource: HealthResource.visits,
    title: 'Historial clínico',
    singular: 'consulta',
    icon: Icons.medical_services_outlined,
    tint: AppColors.trustBlue,
    tintBg: AppColors.tintBlueBg,
    emptyTitle: 'Sin consultas registradas',
    emptyMessage:
        'Guarda el motivo, diagnóstico y tratamiento de cada visita al '
        'veterinario.',
    defaults: () => _today('visit_date'),
    fields: const [
      HealthField(
        'visit_date',
        'Fecha de la consulta',
        kind: HealthFieldKind.date,
        required: true,
        pastOnly: true,
      ),
      HealthField(
        'reason',
        'Motivo',
        required: true,
        minLength: 2,
        maxLength: 200,
        hint: 'Ej. Vómitos, control anual',
      ),
      HealthField(
        'diagnosis',
        'Diagnóstico',
        kind: HealthFieldKind.multiline,
        maxLength: 1000,
      ),
      HealthField(
        'treatment',
        'Tratamiento indicado',
        kind: HealthFieldKind.multiline,
        maxLength: 1000,
      ),
      _vetName,
      _clinic,
      _weightKg,
      HealthField(
        'temperature_c',
        'Temperatura',
        kind: HealthFieldKind.decimal,
        suffix: '°C',
        min: 30,
        max: 45,
      ),
      HealthField(
        'cost_bob',
        'Costo',
        kind: HealthFieldKind.decimal,
        suffix: 'Bs',
        min: 0,
      ),
      _notes,
    ],
    tile: (r) => HealthTileData(
      title: r.str('reason') ?? 'Consulta',
      icon: Icons.medical_services_outlined,
      subtitle: HealthFormat.date(r.str('visit_date')),
      lines: [
        if (r.str('diagnosis') != null)
          (Icons.assignment_outlined, r.str('diagnosis')!),
        if (r.str('treatment') != null)
          (Icons.healing_outlined, r.str('treatment')!),
        if (r.str('vet_name') != null || r.str('clinic_name') != null)
          (
            Icons.local_hospital_outlined,
            [r.str('vet_name'), r.str('clinic_name')].nonNulls.join(' · '),
          ),
        if (r.dbl('cost_bob') != null)
          (
            Icons.payments_outlined,
            '${HealthFormat.number(r.dbl('cost_bob'), decimals: 2)} Bs',
          ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // MEDICAMENTOS
  // ═══════════════════════════════════════════════════════════════════════

  static final medications = HealthSection(
    resource: HealthResource.medications,
    title: 'Medicamentos',
    singular: 'medicamento',
    feminine: false,
    icon: Icons.medication_outlined,
    tint: AppColors.tintAmber,
    tintBg: AppColors.tintAmberBg,
    emptyTitle: 'Sin medicamentos',
    emptyMessage:
        'Registra los tratamientos con su dosis y frecuencia para '
        'seguirlos al día.',
    defaults: () => _today('start_date'),
    fields: const [
      HealthField(
        'name',
        'Medicamento',
        required: true,
        minLength: 2,
        maxLength: 80,
        hint: 'Ej. Omeprazol',
        icon: Icons.medication_outlined,
      ),
      HealthField('dosage', 'Dosis', maxLength: 80, hint: 'Ej. 10 mg'),
      HealthField(
        'frequency',
        'Frecuencia',
        maxLength: 80,
        hint: 'Ej. Cada 12 horas',
      ),
      HealthField(
        'start_date',
        'Inicio',
        kind: HealthFieldKind.date,
        required: true,
      ),
      HealthField(
        'end_date',
        'Fin del tratamiento',
        kind: HealthFieldKind.date,
        afterKey: 'start_date',
        helper: 'Déjalo vacío si es un tratamiento permanente.',
        quickDays: [
          ('+5 días', 5),
          ('+7 días', 7),
          ('+14 días', 14),
          ('+30 días', 30),
        ],
      ),
      HealthField(
        'prescribed_by',
        'Recetado por',
        maxLength: 80,
        icon: Icons.person_outline,
      ),
      _notes,
    ],
    tile: (r) {
      final end = r.str('end_date');
      return HealthTileData(
        title: r.str('name') ?? 'Medicamento',
        icon: Icons.medication_outlined,
        subtitle: [r.str('dosage'), r.str('frequency')].nonNulls.join(' · '),
        lines: [
          (
            Icons.date_range_outlined,
            end == null
                ? 'Desde ${HealthFormat.date(r.str('start_date'))} · permanente'
                : 'Del ${HealthFormat.shortDate(r.str('start_date'))} '
                      'al ${HealthFormat.date(end)}',
          ),
          if (r.str('prescribed_by') != null)
            (Icons.person_outline, r.str('prescribed_by')!),
        ],
        pill: r.isActive
            ? const StatusPill(
                style: StatusStyle(
                  'En curso',
                  AppColors.esmeraldGreen,
                  Icons.play_circle_outline,
                ),
              )
            : const StatusPill(
                style: StatusStyle(
                  'Finalizado',
                  AppColors.outline,
                  Icons.check,
                ),
              ),
        dimmed: !r.isActive,
      );
    },
  );

  // ═══════════════════════════════════════════════════════════════════════
  // PESO
  // ═══════════════════════════════════════════════════════════════════════

  static final weights = HealthSection(
    resource: HealthResource.weights,
    title: 'Control de peso',
    singular: 'registro de peso',
    feminine: false,
    icon: Icons.monitor_weight_outlined,
    tint: AppColors.esmeraldGreen,
    tintBg: AppColors.tintGreenBg,
    emptyTitle: 'Sin registros de peso',
    emptyMessage:
        'Pésala cada cierto tiempo y verás cómo evoluciona en un gráfico.',
    defaults: () => _today('measured_at'),
    fields: const [
      HealthField(
        'weight_kg',
        'Peso',
        kind: HealthFieldKind.decimal,
        required: true,
        suffix: 'kg',
        min: 0,
        max: 150,
        minExclusive: true,
        icon: Icons.monitor_weight_outlined,
      ),
      HealthField(
        'measured_at',
        'Fecha',
        kind: HealthFieldKind.date,
        required: true,
        pastOnly: true,
      ),
      HealthField(
        'notes',
        'Notas',
        kind: HealthFieldKind.multiline,
        maxLength: 200,
      ),
    ],
    tile: (r) => HealthTileData(
      title: '${HealthFormat.number(r.dbl('weight_kg'))} kg',
      icon: Icons.monitor_weight_outlined,
      subtitle: HealthFormat.date(r.str('measured_at')),
      lines: [
        if (r.str('notes') != null) (Icons.notes_outlined, r.str('notes')!),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // CITAS
  // ═══════════════════════════════════════════════════════════════════════

  static bool _isPastScheduled(HealthRecord r) {
    if (r.appointmentStatus != 'scheduled') return false;
    final d = HealthFormat.parse(r.str('scheduled_at'));
    return d != null && d.isBefore(DateTime.now());
  }

  static final appointments = HealthSection(
    resource: HealthResource.appointments,
    title: 'Citas veterinarias',
    singular: 'cita',
    icon: Icons.event_outlined,
    tint: AppColors.trustBlue,
    tintBg: AppColors.tintBlueBg,
    emptyTitle: 'Sin citas agendadas',
    emptyMessage:
        'Agenda la próxima visita y la verás destacada en la ficha de salud.',
    fields: const [
      HealthField(
        'scheduled_at',
        'Fecha y hora',
        kind: HealthFieldKind.dateTime,
        required: true,
      ),
      HealthField(
        'reason',
        'Motivo',
        required: true,
        minLength: 2,
        maxLength: 200,
        hint: 'Ej. Refuerzo antirrábica',
      ),
      _vetName,
      _clinic,
      HealthField(
        'address',
        'Dirección',
        maxLength: 200,
        icon: Icons.place_outlined,
      ),
      _notes,
    ],
    tile: (r) {
      final pastPending = _isPastScheduled(r);
      return HealthTileData(
        title: r.str('reason') ?? 'Cita',
        icon: Icons.event_outlined,
        subtitle: HealthFormat.dateTime(r.str('scheduled_at')),
        lines: [
          if (r.str('vet_name') != null || r.str('clinic_name') != null)
            (
              Icons.local_hospital_outlined,
              [r.str('vet_name'), r.str('clinic_name')].nonNulls.join(' · '),
            ),
          if (r.str('address') != null)
            (Icons.place_outlined, r.str('address')!),
        ],
        // Cita pasada sin cerrar → el backend la marca vencida: pedir cierre
        pill: pastPending
            ? const StatusPill(
                style: StatusStyle(
                  '¿Ya fue?',
                  AppColors.alertAmber,
                  Icons.help_outline,
                ),
              )
            : StatusPill(style: HealthLabels.appointment(r.appointmentStatus)),
        dimmed: r.appointmentStatus == 'cancelled',
      );
    },
    actions: [
      HealthRecordAction(
        label: 'Marcar como realizada',
        icon: Icons.check_circle_outline,
        patch: const {'status': 'completed'},
        visible: (r) => r.appointmentStatus == 'scheduled',
        doneMessage: 'Cita marcada como realizada',
      ),
      HealthRecordAction(
        label: 'Cancelar cita',
        icon: Icons.event_busy_outlined,
        patch: const {'status': 'cancelled'},
        visible: (r) => r.appointmentStatus == 'scheduled',
        doneMessage: 'Cita cancelada',
      ),
      HealthRecordAction(
        label: 'Volver a agendar',
        icon: Icons.replay,
        patch: const {'status': 'scheduled'},
        visible: (r) => r.appointmentStatus == 'cancelled',
        doneMessage: 'Cita agendada de nuevo',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════
  // DOCUMENTOS (el alta tiene un flujo propio: elegir archivo → datos)
  // ═══════════════════════════════════════════════════════════════════════

  static final documents = HealthSection(
    resource: HealthResource.documents,
    title: 'Documentos',
    singular: 'documento',
    feminine: false,
    icon: Icons.folder_outlined,
    tint: AppColors.outline,
    tintBg: AppColors.inputFill,
    emptyTitle: 'Sin documentos',
    emptyMessage:
        'Sube análisis, radiografías, recetas o la foto del carnet físico '
        '(JPG, PNG o PDF de hasta 5 MB).',
    fields: const [
      HealthField(
        'title',
        'Título',
        required: true,
        minLength: 2,
        maxLength: 100,
        hint: 'Ej. Hemograma octubre',
      ),
      HealthField(
        'doc_type',
        'Tipo de documento',
        kind: HealthFieldKind.choice,
        options: HealthLabels.docTypes,
        defaultValue: 'other',
      ),
      HealthField(
        'issued_at',
        'Fecha del documento',
        kind: HealthFieldKind.date,
        pastOnly: true,
      ),
      _notes,
    ],
    tile: (r) => HealthTileData(
      title: r.str('title') ?? 'Documento',
      icon: r.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
      subtitle: [
        HealthLabels.docTypes[r.str('doc_type')] ?? 'Otro',
        if (r.str('issued_at') != null) HealthFormat.date(r.str('issued_at')),
      ].join(' · '),
      lines: [
        (
          Icons.attach_file,
          '${r.isPdf ? 'PDF' : 'Imagen'} · '
              '${HealthFormat.fileSize((r.raw['size_bytes'] as int?) ?? 0)}',
        ),
      ],
      leading: !r.isPdf && r.str('url') != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                r.str('url')!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.image_outlined, color: AppColors.outline),
                ),
              ),
            )
          : null,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // FICHA DE SALUD (PUT completo — no es una lista)
  // ═══════════════════════════════════════════════════════════════════════

  static final profileFields = <HealthField>[
    HealthField(
      'sex',
      'Sexo',
      kind: HealthFieldKind.choice,
      options: HealthLabels.sexes,
      defaultValue: 'unknown',
    ),
    HealthField(
      'birth_date',
      'Fecha de nacimiento',
      kind: HealthFieldKind.date,
      pastOnly: true,
      helper:
          'Si no la sabes exacta, una aproximada sirve para calcular su edad.',
    ),
    HealthField(
      'is_sterilized',
      'Esterilizada/o',
      kind: HealthFieldKind.toggle,
    ),
    HealthField(
      'allergies',
      'Alergias',
      kind: HealthFieldKind.tags,
      icon: Icons.warning_amber_outlined,
      hint: 'Ej. Pollo, penicilina',
      helper: 'Lo primero que verá el veterinario en el carnet.',
    ),
    HealthField(
      'chronic_conditions',
      'Condiciones crónicas',
      kind: HealthFieldKind.tags,
      hint: 'Ej. Displasia de cadera',
    ),
    HealthField('color', 'Color / señas', maxLength: 50),
    HealthField(
      'microchip_id',
      'Microchip',
      maxLength: 30,
      icon: Icons.memory_outlined,
    ),
    HealthField(
      'blood_type',
      'Grupo sanguíneo',
      maxLength: 20,
      hint: 'Ej. DEA 1.1+',
    ),
    HealthField(
      'diet_notes',
      'Alimentación',
      kind: HealthFieldKind.multiline,
      maxLength: 500,
      hint: 'Ej. Croquetas hipoalergénicas, 2 veces al día',
    ),
    HealthField(
      'vet_name',
      'Veterinario/a de cabecera',
      maxLength: 80,
      icon: Icons.person_outline,
    ),
    HealthField(
      'vet_clinic',
      'Clínica',
      maxLength: 100,
      icon: Icons.local_hospital_outlined,
    ),
    HealthField(
      'vet_phone',
      'Teléfono de la clínica',
      kind: HealthFieldKind.phone,
      icon: Icons.phone_outlined,
      hint: 'Ej. 44123456',
      // Mismo patrón que el backend (acepta fijos y celulares)
      pattern: _vetPhonePattern,
      patternError: 'Número inválido (ej. 44123456 o +591 71234567)',
    ),
  ];

  static final _vetPhonePattern = RegExp(r'^\+?\d[\d\s-]{6,19}$');
}
