import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../widgets/progress_indicator.dart';

class Step5Success extends StatelessWidget {
  final String petName;
  final String breed;
  final int age;
  final String? phoneNumber;
  final Function() onComplete;

  const Step5Success({
    super.key,
    required this.petName,
    required this.breed,
    required this.age,
    this.phoneNumber,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.marginMobile,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Progreso
              const ProgressIndicatorr(currentStep: 5),

              SizedBox(height: AppTheme.stackMd),

              // Ícono de éxito
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.esmeraldGreen.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.esmeraldGreen,
                ),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Título
              Text(
                '¡Perfecto!',
                style: AppTheme.headlineLg,
              ),

              SizedBox(height: AppTheme.stackSm),

              // Descripción
              Text(
                '$petName está protegido con ChowTrack',
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
                    _SummaryItem(label: 'Edad', value: '$age años'),
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
                      'Próximos pasos:',
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
                child: FilledButton(
                  onPressed: onComplete,
                  child: Text(
                    'Ir al mapa de mascotas',
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

  const _SummaryItem({
    required this.label,
    required this.value,
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
        Text(
          value,
          style: AppTheme.labelLg.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w600,
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