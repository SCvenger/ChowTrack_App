// lib/features/health/utils/health_labels.dart
//
// Enums del backend → texto, color e ícono. Un solo lugar para que todas las
// pantallas de Salud hablen igual (Guía de integración, sección 5).
// Regla de color: fondos/puntos con el token; texto con AppColors.readable().

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class StatusStyle {
  final String label;
  final Color color; // token base (usar readable() para texto)
  final IconData icon;

  const StatusStyle(this.label, this.color, this.icon);
}

class HealthLabels {
  HealthLabels._();

  /// `due_status` por registro y `vaccination_status`/`deworming_status` global
  static StatusStyle dueStatus(String status) => switch (status) {
    'up_to_date' => const StatusStyle(
      'Al día',
      AppColors.esmeraldGreen,
      Icons.check_circle_outline,
    ),
    'due_soon' => const StatusStyle(
      'Vence pronto',
      AppColors.alertAmber,
      Icons.schedule,
    ),
    'overdue' => const StatusStyle(
      'Vencida',
      AppColors.panicRed,
      Icons.error_outline,
    ),
    'superseded' => const StatusStyle(
      'Renovada',
      AppColors.outline,
      Icons.history,
    ),
    'no_records' => const StatusStyle(
      'Sin registros',
      AppColors.outline,
      Icons.remove_circle_outline,
    ),
    _ => const StatusStyle(
      'Sin refuerzo',
      AppColors.outline,
      Icons.event_busy_outlined,
    ),
  };

  static const vaccineTypes = {
    'rabies': 'Antirrábica',
    'polyvalent': 'Polivalente (séxtuple/óctuple)',
    'leptospirosis': 'Leptospirosis',
    'bordetella': 'Bordetella (tos de las perreras)',
    'other': 'Otra',
  };

  static const dewormingTypes = {
    'internal': 'Interna',
    'external': 'Externa (pulgas/garrapatas)',
    'both': 'Interna y externa',
  };

  static const appointmentStatus = {
    'scheduled': 'Agendada',
    'completed': 'Realizada',
    'cancelled': 'Cancelada',
  };

  static StatusStyle appointment(String status) => switch (status) {
    'completed' => const StatusStyle(
      'Realizada',
      AppColors.esmeraldGreen,
      Icons.check_circle_outline,
    ),
    'cancelled' => const StatusStyle(
      'Cancelada',
      AppColors.outline,
      Icons.cancel_outlined,
    ),
    _ => const StatusStyle(
      'Agendada',
      AppColors.trustBlue,
      Icons.event_outlined,
    ),
  };

  static const docTypes = {
    'vaccine_certificate': 'Certificado de vacuna',
    'lab_result': 'Análisis',
    'xray': 'Radiografía',
    'prescription': 'Receta',
    'other': 'Otro',
  };

  static const sexes = {
    'female': 'Hembra',
    'male': 'Macho',
    'unknown': 'Sin especificar',
  };

  static IconData reminderIcon(String kind) => switch (kind) {
    'vaccination' => Icons.vaccines_outlined,
    'deworming' => Icons.bug_report_outlined,
    _ => Icons.event_outlined,
  };
}
