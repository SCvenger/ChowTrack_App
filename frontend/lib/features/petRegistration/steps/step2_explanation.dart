import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../widgets/progress_indicator.dart';

class Step2Explanation extends StatelessWidget {
  final Function() onComplete;

  const Step2Explanation({
    super.key,
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
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: ProgressIndicatorr(currentStep: 2),
              ),

              // Ilustración de trufa nasal
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.pets,
                    size: 120,
                    color: AppColors.trustBlue,
                  ),
                ),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Título
              Text(
                '¿Por qué la huella nasal?',
                textAlign: TextAlign.center,
                style: AppTheme.headlineMd,
              ),

              SizedBox(height: AppTheme.gutter),

              // Descripción
              Text(
                'Cada perro tiene un patrón único en su nariz, como una huella dactilar humana. Nuestra IA lo registra para protegerlo siempre.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.outline,
                  height: 1.6,
                ),
              ),

              SizedBox(height: AppTheme.stackLg),

              // Botón de acción
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onComplete,
                  child: Text('Entendido', style: AppTheme.labelLg.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}