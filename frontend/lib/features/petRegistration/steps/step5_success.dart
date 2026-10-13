import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../widgets/progress_indicator.dart';

class Step5Success extends StatelessWidget {
  final String petName;
  final String breed;
  final int age;
  final String? phoneNumber;
  final bool hasNoseScan;
  final bool isSaving;
  final VoidCallback onBack;
  final Function() onComplete;

  const Step5Success({
    super.key,
    required this.petName,
    required this.breed,
    required this.age,
    this.phoneNumber,
    required this.hasNoseScan,
    required this.isSaving,
    required this.onBack,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Volver y editar',
          icon: const Icon(Icons.arrow_back),
          onPressed: isSaving ? null : onBack,
        ),
        title: const ProgressIndicatorr(currentStep: 5),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.marginMobile,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícono de revisión: el registro todavía NO se guardó.
              // (Antes decía "¡Perfecto! … está protegido" antes de enviar
              // nada; si el usuario salía aquí, la mascota nunca se creaba.)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.trustBlue.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 64,
                  color: AppColors.trustBlue,
                ),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Título
              Semantics(
                header: true,
                child: Text(
                  'Último paso',
                  style: AppTheme.headlineLg,
                ),
              ),

              SizedBox(height: AppTheme.stackSm),

              // Descripción
              Text(
                'Revisa los datos de $petName y confirma el registro.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyLg.copyWith(color: AppColors.outline),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Resumen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryItem(label: 'Nombre', value: petName),
                    const Divider(height: 16),
                    _SummaryItem(label: 'Raza', value: breed),
                    const Divider(height: 16),
                    _SummaryItem(
                      label: 'Edad',
                      value: age == 1 ? '1 año' : '$age años',
                    ),
                    const Divider(height: 16),
                    _SummaryItem(
                      label: 'Huella nasal',
                      value: hasNoseScan ? 'Capturada' : 'Pendiente',
                      valueColor: AppColors.readable(
                        hasNoseScan
                            ? AppColors.esmeraldGreen
                            : AppColors.alertAmber,
                      ),
                    ),
                    if (phoneNumber != null) ...[
                      const Divider(height: 16),
                      _SummaryItem(label: 'Teléfono', value: phoneNumber!),
                    ],
                  ],
                ),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Próximos pasos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.trustBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.trustBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Después del registro podrás:',
                      style: AppTheme.labelLg.copyWith(
                        color: AppColors.trustBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _ProximoStep(
                      number: '1',
                      text: 'Explora el mapa de mascotas perdidas',
                    ),
                    const _ProximoStep(
                      number: '2',
                      text: 'Reporta avistamientos de otras mascotas',
                    ),
                    const _ProximoStep(
                      number: '3',
                      text: 'Mantente conectado para recibir notificaciones',
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.stackLg),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onComplete,
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Registrar a $petName',
                    style: AppTheme.labelLg.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.labelLg.copyWith(
            color: AppColors.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        // Flexible: razas/nombres largos se cortan con "…" en vez de desbordar
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.labelLg.copyWith(
              color: valueColor ?? AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProximoStep extends StatelessWidget {
  final String number;
  final String text;

  const _ProximoStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.trustBlue,
            ),
            child: Center(
              child: Text(
                number,
                style: AppTheme.labelSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}