// lib/features/health/health_records_view.dart
//
// Lista genérica de una sección de Salud (vacunas, consultas, citas…).
// Comportamiento común a todas:
// - Pull-to-refresh, skeleton solo en la primera carga, estado vacío con CTA.
// - Tocar una tarjeta = editar. Menú "⋮" con acciones extra y eliminar
//   (con confirmación). Botón "Agregar" siempre visible.
// - Peso: gráfico arriba. Citas: "Próximas" e "Historial" separadas.
// - Documentos: elegir archivo (cámara / galería / PDF) → completar datos.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import 'health_form_view.dart';
import 'health_sections.dart';
import 'models/health_models.dart';
import 'services/health_service.dart';
import 'utils/health_format.dart';
import 'widgets/health_widgets.dart';

class HealthRecordsView extends StatefulWidget {
  final String petId;
  final String petName;
  final HealthSection section;

  /// Registro a destacar (al llegar desde un recordatorio)
  final String? highlightId;

  const HealthRecordsView({
    super.key,
    required this.petId,
    required this.petName,
    required this.section,
    this.highlightId,
  });

  @override
  State<HealthRecordsView> createState() => _HealthRecordsViewState();
}

class _HealthRecordsViewState extends State<HealthRecordsView> {
  static const _maxFileBytes = 5 * 1024 * 1024;

  List<HealthRecord>? _records;
  String? _error;

  HealthSection get _s => widget.section;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await HealthService.list(widget.petId, _s.resource);
      if (!mounted) return;
      setState(() {
        _records = list;
        _error = null;
      });
    } on HealthServiceException catch (e) {
      if (!mounted) return;
      // Con datos en pantalla, el error va a un snackbar (no se pierde la lista)
      if (_records == null) {
        setState(() => _error = e.message);
      } else {
        _snack(e.message, error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error
              ? AppColors.panicRed
              : AppColors.readable(AppColors.esmeraldGreen),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CREAR / EDITAR / ELIMINAR
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _add() async {
    if (_s.resource == HealthResource.documents) {
      await _addDocument();
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HealthFormView(
          title: '${_s.feminine ? 'Nueva' : 'Nuevo'} ${_s.singular}',
          fields: _s.fields,
          defaults: _s.defaults?.call(),
          onSubmit: (body) =>
              HealthService.create(widget.petId, _s.resource, body),
        ),
      ),
    );
    if (saved == true && mounted) {
      _snack(_s.savedMessage);
      _load();
    }
  }

  Future<void> _edit(HealthRecord r) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HealthFormView(
          title: 'Editar ${_s.singular}',
          fields: _s.fields,
          initial: r.raw,
          onSubmit: (changes) =>
              HealthService.update(widget.petId, _s.resource, r.id, changes),
        ),
      ),
    );
    if (saved == true && mounted) {
      _snack(_s.savedMessage);
      _load();
    }
  }

  Future<void> _delete(HealthRecord r) async {
    final title = _s.tile(r).title;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "$title"?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppTheme.tapTarget),
              backgroundColor: AppColors.panicRed,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Optimista: desaparece al instante; si falla, vuelve
    final before = _records!;
    setState(() => _records = before.where((x) => x.id != r.id).toList());
    try {
      await HealthService.delete(widget.petId, _s.resource, r.id);
      if (mounted) _snack(_s.deletedMessage);
    } on HealthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _records = before);
      _snack(e.message, error: true);
    }
  }

  Future<void> _runAction(HealthRecord r, HealthRecordAction a) async {
    try {
      await HealthService.update(widget.petId, _s.resource, r.id, a.patch);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _snack(a.doneMessage);
      _load();
    } on HealthServiceException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DOCUMENTOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _addDocument() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.trustBlue,
                ),
                title: Text('Tomar foto', style: AppTheme.bodyMd),
                subtitle: Text(
                  'Carnet físico, receta en papel…',
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.trustBlue,
                ),
                title: Text('Elegir de galería', style: AppTheme.bodyMd),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppColors.trustBlue,
                ),
                title: Text('Subir PDF', style: AppTheme.bodyMd),
                subtitle: Text(
                  'Resultados de laboratorio, informes',
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    Uint8List? bytes;
    String mime = 'image/jpeg';
    String name = 'Foto';
    try {
      if (source == 'pdf') {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
        mime = 'application/pdf';
        name = file.name;
      } else {
        final img = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        if (img == null) return;
        bytes = await img.readAsBytes();
        mime = img.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        name = img.name;
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'No se pudo abrir el archivo. Revisa los permisos.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;

    // Validación local: evita esperar la subida para recibir un 413
    if (bytes.length > _maxFileBytes) {
      _snack(
        'El archivo pesa ${HealthFormat.fileSize(bytes.length)}. '
        'El máximo es 5 MB.',
        error: true,
      );
      return;
    }

    final fileBytes = bytes;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HealthFormView(
          title: 'Nuevo documento',
          fields: _s.fields,
          defaults: {
            'doc_type': mime == 'application/pdf' ? 'lab_result' : 'other',
          },
          submitLabel: 'Subir documento',
          header: _FilePreview(bytes: fileBytes, mime: mime, name: name),
          onSubmit: (body) =>
              HealthService.create(widget.petId, HealthResource.documents, {
                ...body,
                'file_base64': 'data:$mime;base64,${base64Encode(fileBytes)}',
              }),
        ),
      ),
    );
    if (saved == true && mounted) {
      _snack('Documento subido');
      _load();
    }
  }

  Future<void> _openDocument(HealthRecord r) async {
    final url = r.str('url');
    if (url == null) {
      _snack('El enlace del documento expiró. Actualizando…', error: true);
      _load();
      return;
    }
    if (!r.isPdf) {
      await showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      _snack('No hay una app para abrir PDF en este dispositivo.', error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDocs = _s.resource == HealthResource.documents;
    final addLabel = isDocs
        ? 'Subir documento'
        : 'Agregar ${_s.resource == HealthResource.weights ? 'peso' : _s.singular}';

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
            Text(_s.title, style: AppTheme.headlineMd.copyWith(fontSize: 20)),
            Text(
              widget.petName,
              style: AppTheme.labelSm.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
      floatingActionButton: _records == null || _records!.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: AppColors.trustBlue,
              foregroundColor: Colors.white,
              icon: Icon(isDocs ? Icons.upload_file : Icons.add),
              label: Text(addLabel),
            ),
      body: _buildBody(addLabel),
    );
  }

  Widget _buildBody(String addLabel) {
    if (_records == null) {
      if (_error != null) {
        return HealthErrorState(message: _error!, onRetry: _load);
      }
      return const HealthLoadingList();
    }

    final records = _records!;
    if (records.isEmpty) {
      return RefreshIndicator(
        color: AppColors.trustBlue,
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 40),
            HealthEmptyState(
              icon: _s.icon,
              title: _s.emptyTitle,
              message: _s.emptyMessage,
              actionLabel: addLabel,
              onAction: _add,
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];

    if (_s.resource == HealthResource.weights) {
      children
        ..add(WeightChart(records: records))
        ..add(AppTheme.spacerMd)
        ..add(const HealthSectionLabel('Registros'));
    }

    if (_s.resource == HealthResource.appointments) {
      final upcoming = records
          .where((r) => r.appointmentStatus == 'scheduled')
          .toList();
      final history = records
          .where((r) => r.appointmentStatus != 'scheduled')
          .toList()
          .reversed
          .toList();
      if (upcoming.isNotEmpty) {
        children.add(const HealthSectionLabel('Próximas'));
        children.addAll(_tiles(upcoming));
      }
      if (history.isNotEmpty) {
        if (upcoming.isNotEmpty) children.add(AppTheme.spacerSm);
        children.add(const HealthSectionLabel('Historial'));
        children.addAll(_tiles(history));
      }
    } else {
      children.addAll(_tiles(records));
    }

    return RefreshIndicator(
      color: AppColors.trustBlue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          104, // espacio para el botón "Agregar"
        ),
        children: children,
      ),
    );
  }

  List<Widget> _tiles(List<HealthRecord> list) => [
    for (final r in list) ...[
      _RecordTile(
        data: _s.tile(r),
        highlighted: r.id == widget.highlightId,
        tint: _s.tint,
        tintBg: _s.tintBg,
        actions: _s.actions.where((a) => a.visible(r)).toList(),
        isDocument: _s.resource == HealthResource.documents,
        onTap: () => _s.resource == HealthResource.documents
            ? _openDocument(r)
            : _edit(r),
        onEdit: () => _edit(r),
        onDelete: () => _delete(r),
        onAction: (a) => _runAction(r, a),
      ),
      AppTheme.spacerSm,
    ],
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA DE REGISTRO
// ═════════════════════════════════════════════════════════════════════════════

class _RecordTile extends StatelessWidget {
  final HealthTileData data;
  final bool highlighted;
  final Color tint;
  final Color tintBg;
  final List<HealthRecordAction> actions;
  final bool isDocument;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<HealthRecordAction> onAction;

  const _RecordTile({
    required this.data,
    required this.highlighted,
    required this.tint,
    required this.tintBg,
    required this.actions,
    required this.isDocument,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.readable(tint);
    final semantic = [
      data.title,
      if (data.subtitle != null && data.subtitle!.isNotEmpty) data.subtitle!,
      if (data.pill != null) data.pill!.text ?? data.pill!.style.label,
      ...data.lines.map((l) => l.$2),
    ].join('. ');

    return HealthCard(
      dimmed: data.dimmed,
      accent: highlighted ? AppColors.trustBlue : null,
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, 4, 14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tocar la tarjeta abre/edita; el lector anuncia todo junto
          Expanded(
            child: Semantics(
              button: true,
              label: semantic,
              hint: isDocument ? 'Abrir documento' : 'Editar',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  data.leading ??
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tintBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(data.icon, color: iconColor, size: 22),
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: AppTheme.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data.subtitle != null && data.subtitle!.isNotEmpty)
                          Text(
                            data.subtitle!,
                            style: AppTheme.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                        if (data.pill != null) ...[
                          const SizedBox(height: 6),
                          data.pill!,
                        ],
                        for (final (icon, text) in data.lines)
                          HealthInfoLine(icon: icon, text: text),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert, color: AppColors.outline),
            onSelected: (v) {
              if (v == 'edit') return onEdit();
              if (v == 'delete') return onDelete();
              onAction(actions.firstWhere((a) => a.label == v));
            },
            itemBuilder: (_) => [
              for (final a in actions)
                PopupMenuItem(
                  value: a.label,
                  child: _MenuRow(icon: a.icon, label: a.label),
                ),
              PopupMenuItem(
                value: 'edit',
                child: _MenuRow(
                  icon: Icons.edit_outlined,
                  label: isDocument ? 'Editar datos' : 'Editar',
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Eliminar',
                  color: AppColors.readable(AppColors.panicRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? AppColors.outline),
        const SizedBox(width: 12),
        Text(label, style: AppTheme.bodyMd.copyWith(color: color)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VISTA PREVIA DEL ARCHIVO A SUBIR
// ═════════════════════════════════════════════════════════════════════════════

class _FilePreview extends StatelessWidget {
  final Uint8List bytes;
  final String mime;
  final String name;

  const _FilePreview({
    required this.bytes,
    required this.mime,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = mime == 'application/pdf';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: isPdf
                  ? const ColoredBox(
                      color: AppColors.cardSurface,
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 32,
                        color: AppColors.trustBlue,
                      ),
                    )
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${isPdf ? 'PDF' : 'Imagen'} · '
                  '${HealthFormat.fileSize(bytes.length)}',
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.trustBlue,
            semanticLabel: 'Archivo listo',
          ),
        ],
      ),
    );
  }
}
