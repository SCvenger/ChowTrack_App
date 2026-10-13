// lib/features/health/widgets/health_widgets.dart
//
// Piezas visuales del módulo Salud. Reutilizan el lenguaje del resto de la
// app (DESIGN.md): tarjeta blanca radio 16 + sombra cardShadow, acento
// lateral de 4 px como la card SISTEMA de Home, pills radio 999, labels de
// sección en MAYÚSCULAS 12 px como en Perfil/Detalle.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../models/health_models.dart';
import '../utils/health_format.dart';
import '../utils/health_labels.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA
// ═════════════════════════════════════════════════════════════════════════════

class HealthCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final String? semanticsLabel;
  final bool dimmed;

  const HealthCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.all(AppTheme.gutter),
    this.semanticsLabel,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dimmed
            ? null
            : const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
        border: accent != null
            ? Border(left: BorderSide(color: accent!, width: 4))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    // Registros reemplazados (vacuna renovada): atenuados, no ocultos
    if (dimmed) card = Opacity(opacity: 0.6, child: card);

    if (semanticsLabel == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: card,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PILL DE ESTADO — color + ícono + texto (nunca solo color)
// ═════════════════════════════════════════════════════════════════════════════

class StatusPill extends StatelessWidget {
  final StatusStyle style;
  final String? text; // reemplaza style.label (p. ej. "Vence en 5 días")

  const StatusPill({super.key, required this.style, this.text});

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.readable(style.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text ?? style.label,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LABEL DE SECCIÓN
// ═════════════════════════════════════════════════════════════════════════════

class HealthSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const HealthSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: AppTheme.labelSm.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ESTADOS DE PANTALLA
// ═════════════════════════════════════════════════════════════════════════════

class HealthEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HealthEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.trustBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.trustBlue),
          ),
          AppTheme.spacerMd,
          Text(title, style: AppTheme.headlineMd, textAlign: TextAlign.center),
          AppTheme.spacerSm,
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
          ),
          if (actionLabel != null) ...[
            AppTheme.spacerMd,
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class HealthErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const HealthErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
            AppTheme.spacerMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
            ),
            AppTheme.spacerMd,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de lista (mismo patrón que "Mis mascotas")
class HealthLoadingList extends StatelessWidget {
  final int count;
  final double height;

  const HealthLoadingList({super.key, this.count = 4, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => AppTheme.spacerSm,
      itemBuilder: (_, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Fila "ícono + texto" para datos secundarios de una tarjeta
class HealthInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const HealthInfoLine({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: AppColors.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTheme.labelSm.copyWith(color: AppColors.outline),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GRÁFICO DE PESO — CustomPainter liviano (sin dependencias)
// ═════════════════════════════════════════════════════════════════════════════

class WeightChart extends StatelessWidget {
  /// Registros en cualquier orden; se ordenan por fecha ascendente.
  final List<HealthRecord> records;

  const WeightChart({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final points = [...records]
      ..sort(
        (a, b) =>
            (a.str('measured_at') ?? '').compareTo(b.str('measured_at') ?? ''),
      );
    final values = points.map((r) => r.dbl('weight_kg') ?? 0).toList();
    if (values.isEmpty) return const SizedBox.shrink();

    final first = values.first, last = values.last;
    final diff = last - first;
    final trend = values.length < 2
        ? 'Primer registro'
        : diff.abs() < 0.05
        ? 'Estable desde ${HealthFormat.shortDate(points.first.str('measured_at'))}'
        : '${diff > 0 ? '+' : '−'}${HealthFormat.number(diff.abs())} kg '
              'desde ${HealthFormat.shortDate(points.first.str('measured_at'))}';

    return Semantics(
      label:
          'Evolución del peso: ${values.length} registros, '
          'actual ${HealthFormat.number(last)} kilos. $trend',
      excludeSemantics: true,
      child: HealthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  HealthFormat.number(last),
                  style: AppTheme.headlineLg.copyWith(color: AppColors.black),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'kg',
                    style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    trend,
                    style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                  ),
                ),
              ],
            ),
            if (values.length >= 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(painter: _WeightPainter(values)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<double> values;

  _WeightPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    // Margen vertical para que una serie plana no quede pegada al borde
    final span = math.max(maxV - minV, 0.5);
    final lo = minV - span * 0.2, hi = maxV + span * 0.2;

    Offset at(int i) => Offset(
      values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1),
      size.height - (values[i] - lo) / (hi - lo) * size.height,
    );

    // Líneas guía sutiles
    final grid = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = size.height * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }

    final fill = Path.from(path)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = AppColors.trustBlue.withValues(alpha: 0.08),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.trustBlue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = AppColors.trustBlue;
    final ring = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      final isLast = i == values.length - 1;
      canvas.drawCircle(at(i), isLast ? 6 : 4, ring);
      canvas.drawCircle(at(i), isLast ? 4.5 : 3, dot);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.values != values;
}
