// lib/features/health/health_view.dart
//
// Pantalla principal de Salud de una mascota (GET /pets/{id}/health).
// Jerarquía pensada para la consulta con el veterinario:
//   1. Alergias (lo primero que debe ver un vet) — alerta crítica.
//   2. CTA único: "Mostrar al veterinario" (QR).
//   3. Estado de vacunas y desparasitación + recordatorios pendientes.
//   4. Próxima cita · peso actual · tratamientos activos.
//   5. Accesos a cada sección del historial + ficha de salud.

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'health_form_view.dart';
import 'health_records_view.dart';
import 'health_sections.dart';
import 'health_share_view.dart';
import 'models/health_models.dart';
import 'services/health_service.dart';
import 'utils/health_format.dart';
import 'utils/health_labels.dart';
import 'widgets/health_widgets.dart';

class HealthView extends StatefulWidget {
  final String petId;
  final String petName;

  /// Al llegar desde un recordatorio de Home: abre directo esa sección
  /// con el registro destacado.
  final HealthResource? openSection;
  final String? highlightId;

  const HealthView({
    super.key,
    required this.petId,
    required this.petName,
    this.openSection,
    this.highlightId,
  });

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  HealthSummaryModel? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSection(widget.openSection!, highlightId: widget.highlightId);
        }
      });
    }
  }

  Future<void> _load() async {
    try {
      final s = await HealthService.getSummary(widget.petId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _error = null;
      });
    } on HealthServiceException catch (e) {
      if (!mounted) return;
      if (_summary == null) {
        setState(() => _error = e.message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // Cualquier sub-pantalla puede cambiar el resumen → recargar al volver
  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  void _openSection(HealthResource r, {String? highlightId}) => _push(
    HealthRecordsView(
      petId: widget.petId,
      petName: widget.petName,
      section: HealthSection.of(r),
      highlightId: highlightId,
    ),
  );

  void _openShare() =>
      _push(HealthShareView(petId: widget.petId, petName: widget.petName));

  Future<void> _editProfile() async {
    final profile = _summary?.profile;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HealthFormView(
          title: 'Ficha de salud',
          fields: HealthSection.profileFields,
          initial: profile?.raw,
          sendFullBody: true, // PUT reemplaza la ficha completa
          submitLabel: 'Guardar ficha',
          onSubmit: (body) => HealthService.saveProfile(widget.petId, body),
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ficha de salud guardada'),
          backgroundColor: AppColors.readable(AppColors.esmeraldGreen),
        ),
      );
    }
    _load();
  }

  void _openReminder(HealthReminderModel r) {
    final resource = switch (r.kind) {
      'vaccination' => HealthResource.vaccinations,
      'deworming' => HealthResource.dewormings,
      _ => HealthResource.appointments,
    };
    _openSection(resource, highlightId: r.recordId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salud', style: AppTheme.headlineMd.copyWith(fontSize: 20)),
            Text(
              widget.petName,
              style: AppTheme.labelSm.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _summary;
    if (s == null) {
      if (_error != null) {
        return HealthErrorState(
          message: _error!,
          onRetry: () {
            setState(() => _error = null);
            _load();
          },
        );
      }
      return const HealthLoadingList(count: 5, height: 96);
    }

    final p = s.profile;
    return RefreshIndicator(
      color: AppColors.trustBlue,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          AppTheme.stackLg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // 1 ── Alergias ────────────────────────────────────────────────
          if (p.allergies.isNotEmpty) ...[
            _AllergyBanner(allergies: p.allergies),
            AppTheme.spacerMd,
          ],

          // 2 ── CTA principal ───────────────────────────────────────────
          FilledButton.icon(
            onPressed: _openShare,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Mostrar al veterinario'),
          ),
          const SizedBox(height: 6),
          Text(
            'Genera un QR temporal con su carnet de salud',
            textAlign: TextAlign.center,
            style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          ),

          AppTheme.spacerMd,

          // 3 ── Estado general ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatusTile(
                  title: 'Vacunas',
                  status: s.vaccinationStatus,
                  icon: Icons.vaccines_outlined,
                  onTap: () => _openSection(HealthResource.vaccinations),
                ),
              ),
              const SizedBox(width: AppTheme.stackSm),
              Expanded(
                child: _StatusTile(
                  title: 'Desparasitación',
                  status: s.dewormingStatus,
                  icon: Icons.bug_report_outlined,
                  onTap: () => _openSection(HealthResource.dewormings),
                ),
              ),
            ],
          ),

          if (s.reminders.isNotEmpty) ...[
            AppTheme.spacerMd,
            HealthSectionLabel('Pendientes (${s.reminders.length})'),
            HealthCard(
              accent: s.reminders.any((r) => r.isOverdue)
                  ? AppColors.panicRed
                  : AppColors.alertAmber,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final r in s.reminders.take(4))
                    _ReminderRow(reminder: r, onTap: () => _openReminder(r)),
                ],
              ),
            ),
          ],

          // 4 ── Destacados ──────────────────────────────────────────────
          AppTheme.spacerMd,
          _HighlightTile(
            icon: Icons.event_outlined,
            label: 'Próxima cita',
            value: s.nextAppointment == null
                ? 'Sin citas agendadas'
                : HealthFormat.dateTime(s.nextAppointment!.str('scheduled_at')),
            detail: s.nextAppointment == null
                ? 'Toca para agendar'
                : [
                    s.nextAppointment!.str('reason'),
                    s.nextAppointment!.str('clinic_name'),
                  ].nonNulls.join(' · '),
            muted: s.nextAppointment == null,
            onTap: () => _openSection(HealthResource.appointments),
          ),
          AppTheme.spacerSm,
          Row(
            children: [
              Expanded(
                child: _HighlightTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Peso',
                  value: s.latestWeight == null
                      ? '—'
                      : '${HealthFormat.number(s.latestWeight!.dbl('weight_kg'))} kg',
                  detail: s.latestWeight == null
                      ? 'Sin registros'
                      : HealthFormat.shortDate(
                          s.latestWeight!.str('measured_at'),
                        ),
                  muted: s.latestWeight == null,
                  onTap: () => _openSection(HealthResource.weights),
                ),
              ),
              const SizedBox(width: AppTheme.stackSm),
              Expanded(
                child: _HighlightTile(
                  icon: Icons.medication_outlined,
                  label: 'Tratamientos',
                  value: s.activeMedications.isEmpty
                      ? 'Ninguno'
                      : '${s.activeMedications.length} activo'
                            '${s.activeMedications.length == 1 ? '' : 's'}',
                  detail: s.activeMedications.isEmpty
                      ? 'Sin medicación'
                      : s.activeMedications
                            .map((m) => m.str('name'))
                            .nonNulls
                            .join(', '),
                  muted: s.activeMedications.isEmpty,
                  onTap: () => _openSection(HealthResource.medications),
                ),
              ),
            ],
          ),

          // 5 ── Historial ───────────────────────────────────────────────
          AppTheme.spacerLg,
          const HealthSectionLabel('Historial'),
          HealthCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SectionRow(
                  section: HealthSection.vaccinations,
                  count: s.counts.vaccinations,
                  onTap: () => _openSection(HealthResource.vaccinations),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.dewormings,
                  count: s.counts.dewormings,
                  onTap: () => _openSection(HealthResource.dewormings),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.visits,
                  count: s.counts.visits,
                  onTap: () => _openSection(HealthResource.visits),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.medications,
                  count: s.counts.medicationsActive,
                  countSuffix: 'activos',
                  onTap: () => _openSection(HealthResource.medications),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.weights,
                  onTap: () => _openSection(HealthResource.weights),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.appointments,
                  onTap: () => _openSection(HealthResource.appointments),
                ),
                const _RowDivider(),
                _SectionRow(
                  section: HealthSection.documents,
                  count: s.counts.documents,
                  onTap: () => _openSection(HealthResource.documents),
                ),
              ],
            ),
          ),

          // 6 ── Ficha ───────────────────────────────────────────────────
          AppTheme.spacerLg,
          HealthSectionLabel(
            'Ficha de salud',
            trailing: TextButton(
              onPressed: _editProfile,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppTheme.tapTarget, AppTheme.tapTarget),
              ),
              child: Text(p.isRegistered ? 'Editar' : 'Completar'),
            ),
          ),
          _ProfileCard(profile: p, onTap: _editProfile),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVADOS
// ═════════════════════════════════════════════════════════════════════════════

class _AllergyBanner extends StatelessWidget {
  final List<String> allergies;

  const _AllergyBanner({required this.allergies});

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.readable(AppColors.panicRed);
    return Semantics(
      container: true,
      label: 'Alerta: alérgica a ${allergies.join(', ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panicRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.panicRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alergias', style: AppTheme.labelLg.copyWith(color: fg)),
                  const SizedBox(height: 2),
                  Text(
                    allergies.join(' · '),
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String status;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusTile({
    required this.title,
    required this.status,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = HealthLabels.dueStatus(status);
    return HealthCard(
      accent: style.color,
      onTap: onTap,
      semanticsLabel: '$title: ${style.label}',
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatusPill(style: style),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final HealthReminderModel reminder;
  final VoidCallback onTap;

  const _ReminderRow({required this.reminder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final color = r.isOverdue ? AppColors.panicRed : AppColors.alertAmber;
    final when = r.isAppointment
        ? (r.isOverdue
              ? 'Pasó el ${HealthFormat.shortDate(r.dueDate)} · ¿ya fue?'
              : HealthFormat.dateTime(r.dueDate))
        : HealthFormat.daysLeft(r.daysLeft);

    return Semantics(
      button: true,
      label: '${r.title}. $when',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                HealthLabels.reminderIcon(r.kind),
                color: AppColors.readable(color),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: AppTheme.bodyMd),
                    Text(
                      when,
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.readable(color),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final bool muted;
  final VoidCallback onTap;

  const _HighlightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      onTap: onTap,
      semanticsLabel: '$label: $value. $detail',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tintBlueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.trustBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted ? AppColors.outline : AppColors.black,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final HealthSection section;
  final int? count;
  final String? countSuffix;
  final VoidCallback onTap;

  const _SectionRow({
    required this.section,
    required this.onTap,
    this.count,
    this.countSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final countText = count == null
        ? null
        : (countSuffix != null ? '$count $countSuffix' : '$count');
    return Semantics(
      button: true,
      label: countText == null ? section.title : '${section.title}, $countText',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Mismo patrón de ícono con tinte que el menú de Perfil
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: section.tintBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    section.icon,
                    size: 18,
                    color: AppColors.readable(section.tint),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(section.title, style: AppTheme.bodyMd)),
                if (countText != null)
                  Text(
                    countText,
                    style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final HealthProfileModel profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (!p.isRegistered) {
      return HealthCard(
        onTap: onTap,
        semanticsLabel: 'Ficha de salud sin completar. Toca para completarla',
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined, color: AppColors.trustBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Completa sexo, nacimiento, alergias, microchip y veterinario '
                'de cabecera. El vet lo verá en el carnet.',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      );
    }

    final rows = <(String, String)>[
      ('Sexo', HealthLabels.sexes[p.sex] ?? 'Sin especificar'),
      if (p.ageMonths != null)
        ('Edad', HealthFormat.ageFromMonths(p.ageMonths)),
      ('Esterilizada/o', p.isSterilized ? 'Sí' : 'No'),
      if (p.chronicConditions.isNotEmpty)
        ('Condiciones', p.chronicConditions.join(', ')),
      if (p.microchipId != null) ('Microchip', p.microchipId!),
      if (p.bloodType != null) ('Grupo sanguíneo', p.bloodType!),
      if (p.dietNotes != null) ('Alimentación', p.dietNotes!),
      if (p.vetName != null || p.vetClinic != null)
        ('Veterinario', [p.vetName, p.vetClinic].nonNulls.join(' · ')),
      if (p.vetPhone != null) ('Teléfono vet', p.vetPhone!),
    ];

    return HealthCard(
      onTap: onTap,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16, thickness: 0.5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    rows[i].$1,
                    style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                  ),
                ),
                Expanded(child: Text(rows[i].$2, style: AppTheme.bodyMd)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
