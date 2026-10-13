// lib/features/health/health_share_view.dart
//
// "Mostrar al veterinario": genera un enlace temporal al carnet y lo muestra
// como QR. El vet lo escanea y abre una página imprimible, sin cuenta.
// El dueño elige la duración, puede copiar/abrir el enlace y revocarlo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import 'models/health_models.dart';
import 'services/health_service.dart';
import 'utils/health_format.dart';
import 'widgets/health_widgets.dart';

class HealthShareView extends StatefulWidget {
  final String petId;
  final String petName;

  const HealthShareView({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<HealthShareView> createState() => _HealthShareViewState();
}

class _HealthShareViewState extends State<HealthShareView> {
  static const _durations = [(2, '2 horas'), (24, '24 horas'), (168, '7 días')];

  int _hours = 24;
  bool _creating = false;
  HealthShareModel? _current;
  List<HealthShareModel> _shares = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadShares(pickCurrent: true);
  }

  Future<void> _loadShares({bool pickCurrent = false}) async {
    try {
      final list = await HealthService.listShares(widget.petId);
      if (!mounted) return;
      setState(() {
        _shares = list.where((s) => s.isActive).toList();
        // Si ya hay un enlace vigente, mostrarlo directo (no crear otro)
        if (pickCurrent && _current == null && _shares.isNotEmpty) {
          _current = _shares.first;
        }
      });
    } on HealthServiceException catch (_) {
      // La lista es secundaria: si falla, igual se puede generar un QR
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final share = await HealthService.createShare(widget.petId, _hours);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _current = share);
      _loadShares();
    } on HealthServiceException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revoke(HealthShareModel share) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Revocar el acceso?'),
        content: const Text(
          'El enlace y el código QR dejarán de funcionar de inmediato.',
        ),
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
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await HealthService.revokeShare(widget.petId, share.id);
      if (!mounted) return;
      setState(() {
        if (_current?.id == share.id) _current = null;
        _shares.removeWhere((s) => s.id == share.id);
      });
      _snack('Acceso revocado');
    } on HealthServiceException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.panicRed : null,
        ),
      );
  }

  String _expiresText(HealthShareModel s) {
    final d = HealthFormat.parse(s.expiresAt);
    if (d == null) return '';
    final left = d.difference(DateTime.now());
    if (left.inMinutes < 60) {
      return 'Vence en ${left.inMinutes.clamp(1, 59)} min';
    }
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'Vence hoy a las ${HealthFormat.time(d)}';
    if (days == 1) return 'Vence mañana a las ${HealthFormat.time(d)}';
    return 'Vence el ${HealthFormat.dateTime(s.expiresAt)}';
  }

  String _accessText(HealthShareModel s) => s.lastAccessedAt == null
      ? 'Aún no se abrió'
      : 'Abierto por última vez: ${HealthFormat.dateTime(s.lastAccessedAt)}';

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
        title: Text(
          'Mostrar al veterinario',
          style: AppTheme.headlineMd.copyWith(fontSize: 20),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.marginMobile,
          AppTheme.gutter,
          AppTheme.marginMobile,
          AppTheme.stackLg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _current == null ? _buildGenerator() : _buildQr(_current!),
          ),
          if (_shares.length > (_current == null ? 0 : 1)) ...[
            AppTheme.spacerLg,
            const HealthSectionLabel('Enlaces activos'),
            for (final s in _shares.where((s) => s.id != _current?.id)) ...[
              HealthCard(
                onTap: () => setState(() => _current = s),
                semanticsLabel:
                    'Enlace activo. ${_expiresText(s)}. ${_accessText(s)}. '
                    'Toca para ver el código QR',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, color: AppColors.trustBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_expiresText(s), style: AppTheme.bodyMd),
                          Text(
                            _accessText(s),
                            style: AppTheme.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.outline),
                  ],
                ),
              ),
              AppTheme.spacerSm,
            ],
          ] else if (_loadingList) ...[
            AppTheme.spacerLg,
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Paso 1: elegir duración y generar ─────────────────────────────────────

  Widget _buildGenerator() {
    return Column(
      key: const ValueKey('generator'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.trustBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 48,
              color: AppColors.trustBlue,
            ),
          ),
        ),
        AppTheme.spacerMd,
        Text(
          'Comparte el carnet de ${widget.petName}',
          textAlign: TextAlign.center,
          style: AppTheme.headlineMd,
        ),
        AppTheme.spacerSm,
        Text(
          'Generaremos un código QR temporal. El veterinario lo escanea y ve '
          'vacunas, alergias, tratamientos y consultas — sin instalar nada. '
          'Tus datos de contacto no se comparten.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
        ),
        AppTheme.spacerLg,
        const HealthSectionLabel('¿Por cuánto tiempo?'),
        SegmentedButton<int>(
          segments: [
            for (final (h, label) in _durations)
              ButtonSegment(value: h, label: Text(label)),
          ],
          selected: {_hours},
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, AppTheme.tapTarget),
            selectedBackgroundColor: AppColors.tintBlueBg,
            selectedForegroundColor: AppColors.trustBlue,
            textStyle: AppTheme.labelLg,
          ),
          onSelectionChanged: (v) => setState(() => _hours = v.first),
        ),
        AppTheme.spacerMd,
        FilledButton.icon(
          onPressed: _creating ? null : _create,
          icon: _creating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.qr_code),
          label: Text(_creating ? 'Generando…' : 'Generar código QR'),
        ),
      ],
    );
  }

  // ── Paso 2: QR listo ──────────────────────────────────────────────────────

  Widget _buildQr(HealthShareModel s) {
    return Column(
      key: ValueKey(s.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pide al veterinario que escanee este código',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppColors.black),
        ),
        AppTheme.spacerMd,
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            // Fondo blanco + negro puro: máximo contraste para escanear
            child: QrImageView(
              data: s.carnetUrl,
              size: 232,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              semanticsLabel:
                  'Código QR del carnet de salud de ${widget.petName}',
            ),
          ),
        ),
        AppTheme.spacerMd,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 16, color: AppColors.outline),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _expiresText(s),
                style: AppTheme.labelLg.copyWith(color: AppColors.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _accessText(s),
          textAlign: TextAlign.center,
          style: AppTheme.labelSm.copyWith(color: AppColors.outline),
        ),
        AppTheme.spacerMd,
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.carnetUrl));
                  if (mounted) _snack('Enlace copiado');
                },
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Copiar enlace'),
              ),
            ),
            const SizedBox(width: AppTheme.stackSm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(s.carnetUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 20),
                label: const Text('Ver carnet'),
              ),
            ),
          ],
        ),
        AppTheme.spacerSm,
        TextButton.icon(
          onPressed: () => _revoke(s),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.readable(AppColors.panicRed),
            minimumSize: const Size.fromHeight(AppTheme.tapTarget),
          ),
          icon: const Icon(Icons.link_off),
          label: const Text('Revocar acceso'),
        ),
        TextButton(
          onPressed: () => setState(() => _current = null),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppTheme.tapTarget),
          ),
          child: const Text('Generar otro código'),
        ),
      ],
    );
  }
}
