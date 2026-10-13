import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../widgets/progress_indicator.dart';

class Step2Explanation extends StatelessWidget {
  final Function() onComplete;
  final VoidCallback onBack;

  const Step2Explanation({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Atrás visible (antes solo funcionaba el botón del sistema)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const ProgressIndicatorr(currentStep: 2),
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
              const SizedBox(height: 12),

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