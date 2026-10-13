// lib/features/health/utils/health_format.dart
//
// Formato de fechas/números del módulo Salud, en español y sin depender de
// `intl`. El backend envía fechas simples "YYYY-MM-DD" y fechas-hora ISO.

class HealthFormat {
  HealthFormat._();

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];

  /// "YYYY-MM-DD" o ISO → DateTime local. Las fechas simples se interpretan
  /// como fecha de calendario (sin corrimiento de zona).
  static DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return value.length <= 10 ? dt : dt.toLocal();
  }

  /// 13 oct 2026
  static String date(String? value) {
    final d = parse(value);
    if (d == null) return '—';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// 13 oct (año omitido si es el actual)
  static String shortDate(String? value) {
    final d = parse(value);
    if (d == null) return '—';
    final base = '${d.day} ${_months[d.month - 1]}';
    return d.year == DateTime.now().year ? base : '$base ${d.year}';
  }

  /// 20 oct 2026, 10:00
  static String dateTime(String? value) {
    final d = parse(value);
    if (d == null) return '—';
    return '${date(value)}, ${time(d)}';
  }

  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// DateTime → "YYYY-MM-DD" (lo que espera el backend en fechas simples)
  static String toApiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// DateTime local → ISO con la zona del dispositivo ("…T10:00:00-04:00"),
  /// así la cita queda a la hora que el usuario eligió en su reloj.
  static String toApiDateTime(DateTime d) {
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${toApiDate(d)}T${time(d)}:00$sign$h:$m';
  }

  /// Días restantes → texto. Negativo = vencido.
  static String daysLeft(
    int? days, {
    String past = 'Venció',
    String future = 'Vence',
  }) {
    if (days == null) return '';
    if (days == 0) return '$future hoy';
    if (days == 1) return '$future mañana';
    if (days == -1) return '$past ayer';
    if (days < 0) return '$past hace ${-days} días';
    return '$future en $days días';
  }

  /// 12.5 → "12,5"; 12.0 → "12"
  static String number(num? value, {int decimals = 1}) {
    if (value == null) return '—';
    final fixed = value.toStringAsFixed(decimals);
    final trimmed = fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
    return trimmed.replaceAll('.', ',');
  }

  /// Edad a partir de meses: "2 años y 3 meses"
  static String ageFromMonths(int? months) {
    if (months == null) return '—';
    final y = months ~/ 12, m = months % 12;
    final years = y == 0 ? '' : (y == 1 ? '1 año' : '$y años');
    final mon = m == 0 ? '' : (m == 1 ? '1 mes' : '$m meses');
    if (years.isEmpty && mon.isEmpty) return 'Menos de 1 mes';
    if (years.isEmpty) return mon;
    if (mon.isEmpty) return years;
    return '$years y $mon';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${number(bytes / (1024 * 1024))} MB';
  }
}
