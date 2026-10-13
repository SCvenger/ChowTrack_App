// lib/features/health/health_form_view.dart
//
// Formulario declarativo reutilizado por TODOS los registros de Salud
// (vacuna, desparasitación, consulta, medicamento, peso, cita, documento y
// ficha). Cada sección solo describe sus campos con [HealthField].
//
// - Crear  → envía todos los campos con valor (POST).
// - Editar → envía SOLO lo que cambió (PATCH); vaciar un opcional envía null.
// - Ficha  → `sendFullBody` envía todo (PUT reemplaza la ficha).
// - Validación junto a cada campo + reglas del backend (fechas no futuras,
//   refuerzo ≥ aplicación, rangos numéricos) para evitar el 422.
// - Si hay cambios sin guardar, pide confirmación antes de salir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'services/health_service.dart';
import 'utils/health_format.dart';

enum HealthFieldKind {
  text,
  multiline,
  decimal,
  integer,
  phone,
  date,
  dateTime,
  choice,
  toggle,
  tags,
}

class HealthField {
  final String key;
  final String label;
  final HealthFieldKind kind;
  final bool required;
  final String? hint;
  final String? helper;
  final String? suffix;
  final int? minLength;
  final int? maxLength;
  final double? min;
  final double? max;
  final bool minExclusive;
  final Map<String, String>? options; // choice: valor API → texto
  final String? defaultValue; // choice
  final bool pastOnly; // fecha no puede ser futura
  final String? afterKey; // fecha ≥ la de otro campo
  final List<(String, int)> quickDays; // atajos: ("+1 año", 365) desde afterKey
  final RegExp? pattern;
  final String? patternError;
  final IconData? icon;
  final int maxItems; // tags

  const HealthField(
    this.key,
    this.label, {
    this.kind = HealthFieldKind.text,
    this.required = false,
    this.hint,
    this.helper,
    this.suffix,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.minExclusive = false,
    this.options,
    this.defaultValue,
    this.pastOnly = false,
    this.afterKey,
    this.quickDays = const [],
    this.pattern,
    this.patternError,
    this.icon,
    this.maxItems = 20,
  });

  bool get isText => const {
    HealthFieldKind.text,
    HealthFieldKind.multiline,
    HealthFieldKind.decimal,
    HealthFieldKind.integer,
    HealthFieldKind.phone,
  }.contains(kind);
}

class HealthFormView extends StatefulWidget {
  final String title;
  final List<HealthField> fields;

  /// JSON del registro a editar. null = crear.
  final Map<String, dynamic>? initial;

  /// Valores sugeridos al CREAR (p. ej. fecha = hoy). No cuentan como
  /// "cambios sin guardar".
  final Map<String, dynamic>? defaults;

  /// Recibe el body ya serializado. Si lanza [HealthServiceException], el
  /// formulario muestra su mensaje y conserva lo ingresado.
  final Future<void> Function(Map<String, dynamic> body) onSubmit;

  final bool sendFullBody;
  final String? submitLabel;

  /// Contenido extra arriba del formulario (p. ej. vista previa del archivo)
  final Widget? header;

  const HealthFormView({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.initial,
    this.defaults,
    this.sendFullBody = false,
    this.submitLabel,
    this.header,
  });

  bool get isEditing => initial != null;

  @override
  State<HealthFormView> createState() => _HealthFormViewState();
}

class _HealthFormViewState extends State<HealthFormView> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {}; // date/choice/toggle/tags
  late final Map<String, dynamic> _baseline; // para detectar cambios
  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? widget.defaults ?? const {};
    for (final f in widget.fields) {
      final v = init[f.key];
      switch (f.kind) {
        case HealthFieldKind.date:
        case HealthFieldKind.dateTime:
          _values[f.key] = v is DateTime ? v : HealthFormat.parse(v as String?);
        case HealthFieldKind.choice:
          _values[f.key] = (v as String?) ?? f.defaultValue;
        case HealthFieldKind.toggle:
          _values[f.key] = (v as bool?) ?? false;
        case HealthFieldKind.tags:
          _values[f.key] = (v as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
        default:
          _text[f.key] = TextEditingController(text: _textFrom(f, v));
      }
    }
    _baseline = _collect(all: true);
  }

  String _textFrom(HealthField f, dynamic v) {
    if (v == null) return '';
    if (v is num && f.kind == HealthFieldKind.decimal) {
      return HealthFormat.number(v, decimals: 2);
    }
    return v.toString();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Serialización ────────────────────────────────────────────────────────

  dynamic _serialize(HealthField f) {
    switch (f.kind) {
      case HealthFieldKind.date:
        final d = _values[f.key] as DateTime?;
        return d == null ? null : HealthFormat.toApiDate(d);
      case HealthFieldKind.dateTime:
        final d = _values[f.key] as DateTime?;
        return d == null ? null : HealthFormat.toApiDateTime(d);
      case HealthFieldKind.choice:
      case HealthFieldKind.toggle:
        return _values[f.key];
      case HealthFieldKind.tags:
        return List<String>.from(_values[f.key] as List);
      case HealthFieldKind.decimal:
        final t = _text[f.key]!.text.trim().replaceAll(',', '.');
        return t.isEmpty ? null : double.tryParse(t);
      case HealthFieldKind.integer:
        final t = _text[f.key]!.text.trim();
        return t.isEmpty ? null : int.tryParse(t);
      default:
        final t = _text[f.key]!.text.trim();
        return t.isEmpty ? null : t;
    }
  }

  Map<String, dynamic> _collect({bool all = false}) {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      final v = _serialize(f);
      if (all || v != null) out[f.key] = v;
    }
    return out;
  }

  bool _same(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  Map<String, dynamic> _changes() {
    final now = _collect(all: true);
    return {
      for (final e in now.entries)
        if (!_same(e.value, _baseline[e.key])) e.key: e.value,
    };
  }

  bool get _dirty => _changes().isNotEmpty;

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> body;
    if (widget.sendFullBody) {
      body = _collect(all: true);
    } else if (widget.isEditing) {
      body = _changes();
      if (body.isEmpty) {
        Navigator.pop(context, false); // nada que guardar
        return;
      }
    } else {
      body = _collect();
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(body);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e is HealthServiceException
          ? e.message
          : 'No se pudo guardar. Intenta de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.panicRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Lo que ingresaste no se guardará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.title, style: AppTheme.headlineMd),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppTheme.marginMobile,
              AppTheme.gutter,
              AppTheme.marginMobile,
              AppTheme.stackLg + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (widget.header != null) ...[widget.header!, AppTheme.spacerMd],
              for (final f in widget.fields) ...[
                _buildField(f),
                const SizedBox(height: AppTheme.gutter),
              ],
              Text(
                '* Campo obligatorio',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
              AppTheme.spacerMd,
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.submitLabel ??
                            (widget.isEditing ? 'Guardar cambios' : 'Guardar'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelOf(HealthField f) => f.required ? '${f.label} *' : f.label;

  Widget _buildField(HealthField f) {
    switch (f.kind) {
      case HealthFieldKind.date:
      case HealthFieldKind.dateTime:
        return _DateField(
          field: f,
          label: _labelOf(f),
          value: _values[f.key] as DateTime?,
          after: f.afterKey != null ? _values[f.afterKey] as DateTime? : null,
          afterLabel: f.afterKey != null
              ? widget.fields.firstWhere((x) => x.key == f.afterKey).label
              : null,
          onChanged: (d) => setState(() => _values[f.key] = d),
        );
      case HealthFieldKind.choice:
        return DropdownButtonFormField<String>(
          initialValue: _values[f.key] as String?,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _labelOf(f),
            helperText: f.helper,
            helperMaxLines: 3,
            prefixIcon: f.icon != null ? Icon(f.icon) : null,
          ),
          items: [
            for (final e in f.options!.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          validator: (v) =>
              f.required && v == null ? 'Selecciona una opción' : null,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case HealthFieldKind.toggle:
        final on = _values[f.key] as bool;
        return MergeSemantics(
          child: Material(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            child: SwitchListTile(
              value: on,
              onChanged: (v) => setState(() => _values[f.key] = v),
              title: Text(f.label, style: AppTheme.bodyMd),
              subtitle: f.helper != null
                  ? Text(
                      f.helper!,
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.outline,
                      ),
                    )
                  : null,
              activeThumbColor: AppColors.trustBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      case HealthFieldKind.tags:
        return _TagsField(
          field: f,
          values: _values[f.key] as List<String>,
          onChanged: (list) => setState(() => _values[f.key] = list),
        );
      default:
        return _buildTextField(f);
    }
  }

  Widget _buildTextField(HealthField f) {
    final isNumber =
        f.kind == HealthFieldKind.decimal || f.kind == HealthFieldKind.integer;
    return TextFormField(
      controller: _text[f.key],
      onChanged: (_) => setState(() {}), // refresca el estado "sucio"
      decoration: InputDecoration(
        labelText: _labelOf(f),
        hintText: f.hint,
        helperText: f.helper,
        helperMaxLines: 2,
        suffixText: f.suffix,
        prefixIcon: f.icon != null ? Icon(f.icon) : null,
        alignLabelWithHint: f.kind == HealthFieldKind.multiline,
      ),
      style: AppTheme.bodyMd,
      maxLength: f.kind == HealthFieldKind.multiline ? f.maxLength : null,
      minLines: f.kind == HealthFieldKind.multiline ? 3 : 1,
      maxLines: f.kind == HealthFieldKind.multiline ? 6 : 1,
      textCapitalization:
          f.kind == HealthFieldKind.text || f.kind == HealthFieldKind.multiline
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      textInputAction: f.kind == HealthFieldKind.multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      keyboardType: switch (f.kind) {
        HealthFieldKind.decimal => const TextInputType.numberWithOptions(
          decimal: true,
        ),
        HealthFieldKind.integer => TextInputType.number,
        HealthFieldKind.phone => TextInputType.phone,
        HealthFieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      autofillHints: f.kind == HealthFieldKind.phone
          ? const [AutofillHints.telephoneNumber]
          : null,
      inputFormatters: [
        if (f.kind == HealthFieldKind.integer)
          FilteringTextInputFormatter.digitsOnly,
        if (f.kind == HealthFieldKind.decimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        if (f.maxLength != null && f.kind != HealthFieldKind.multiline)
          LengthLimitingTextInputFormatter(f.maxLength),
      ],
      validator: (raw) {
        final v = (raw ?? '').trim();
        if (v.isEmpty) return f.required ? 'Este campo es obligatorio' : null;
        if (f.minLength != null && v.length < f.minLength!) {
          return 'Mínimo ${f.minLength} caracteres';
        }
        if (isNumber) {
          final n = double.tryParse(v.replaceAll(',', '.'));
          if (n == null) return 'Ingresa un número válido';
          if (f.min != null && (f.minExclusive ? n <= f.min! : n < f.min!)) {
            return f.minExclusive
                ? 'Debe ser mayor a ${HealthFormat.number(f.min)}'
                : 'Mínimo ${HealthFormat.number(f.min)}';
          }
          if (f.max != null && n > f.max!) {
            return 'Máximo ${HealthFormat.number(f.max)}';
          }
        }
        if (f.pattern != null && !f.pattern!.hasMatch(v)) {
          return f.patternError ?? 'Formato inválido';
        }
        return null;
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CAMPO DE FECHA / FECHA-HORA — con atajos ("+1 año") y botón para limpiar
// ═════════════════════════════════════════════════════════════════════════════

class _DateField extends StatelessWidget {
  final HealthField field;
  final String label;
  final DateTime? value;
  final DateTime? after;
  final String? afterLabel;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.field,
    required this.label,
    required this.value,
    required this.after,
    required this.afterLabel,
    required this.onChanged,
  });

  bool get _withTime => field.kind == HealthFieldKind.dateTime;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = after ?? DateTime(now.year - 30);
    final last = field.pastOnly ? today : DateTime(now.year + 5, 12, 31);
    var initial = value ?? (field.pastOnly ? today : (after ?? today));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: field.label,
    );
    if (date == null || !context.mounted) return;

    if (!_withTime) {
      onChanged(date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: value != null
          ? TimeOfDay.fromDateTime(value!)
          : const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Hora de la cita',
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      // La key fuerza a re-validar con el valor actual (el FormField no es
      // dueño del valor: vive en el estado del formulario)
      key: ValueKey('${field.key}-$value-$after'),
      initialValue: value,
      validator: (_) {
        if (value == null) {
          return field.required ? 'Selecciona una fecha' : null;
        }
        final now = DateTime.now();
        if (field.pastOnly &&
            value!.isAfter(DateTime(now.year, now.month, now.day, 23, 59))) {
          return 'No puede ser una fecha futura';
        }
        if (after != null && value!.isBefore(after!)) {
          return 'Debe ser igual o posterior a "${afterLabel ?? ''}"';
        }
        return null;
      },
      builder: (state) {
        final text = value == null
            ? null
            : (_withTime
                  ? HealthFormat.dateTime(value!.toIso8601String())
                  : HealthFormat.date(HealthFormat.toApiDate(value!)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '$label: ${text ?? 'sin definir'}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pick(context),
                child: InputDecorator(
                  isEmpty: value == null,
                  decoration: InputDecoration(
                    labelText: label,
                    helperText: field.helper,
                    helperMaxLines: 2,
                    errorText: state.errorText,
                    prefixIcon: Icon(
                      _withTime
                          ? Icons.event_outlined
                          : Icons.calendar_today_outlined,
                    ),
                    suffixIcon: value != null && !field.required
                        ? IconButton(
                            tooltip: 'Quitar fecha',
                            icon: const Icon(Icons.close),
                            onPressed: () => onChanged(null),
                          )
                        : null,
                  ),
                  child: Text(text ?? '', style: AppTheme.bodyMd),
                ),
              ),
            ),
            if (field.quickDays.isNotEmpty && after != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (txt, days) in field.quickDays)
                    _QuickChip(
                      label: txt,
                      onTap: () => onChanged(after!.add(Duration(days: days))),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sugerir $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // Sin `alignment`: con él, el Container se expande a todo el ancho
          // del Wrap. El texto se centra verticalmente con el padding.
          decoration: BoxDecoration(
            color: AppColors.tintBlueBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTheme.labelSm.copyWith(
              color: AppColors.trustBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CAMPO DE ETIQUETAS (alergias, condiciones crónicas)
// ═════════════════════════════════════════════════════════════════════════════

class _TagsField extends StatefulWidget {
  final HealthField field;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const _TagsField({
    required this.field,
    required this.values,
    required this.onChanged,
  });

  @override
  State<_TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<_TagsField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    if (v.length > 50) {
      setState(() => _error = 'Máximo 50 caracteres');
      return;
    }
    final exists = widget.values.any((e) => e.toLowerCase() == v.toLowerCase());
    if (exists) {
      setState(() => _error = '"$v" ya está en la lista');
      return;
    }
    if (widget.values.length >= widget.field.maxItems) {
      setState(() => _error = 'Máximo ${widget.field.maxItems} elementos');
      return;
    }
    widget.onChanged([...widget.values, v]);
    _controller.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: widget.field.label,
            hintText: widget.field.hint,
            helperText: widget.field.helper,
            errorText: _error,
            prefixIcon: widget.field.icon != null
                ? Icon(widget.field.icon)
                : null,
            suffixIcon: IconButton(
              tooltip: 'Agregar',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _add,
            ),
          ),
          style: AppTheme.bodyMd,
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in widget.values)
                InputChip(
                  label: Text(v, style: AppTheme.labelLg),
                  backgroundColor: AppColors.inputFill,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  deleteButtonTooltipMessage: 'Quitar $v',
                  onDeleted: () => widget.onChanged(
                    widget.values.where((e) => e != v).toList(),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
