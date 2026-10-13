// lib/features/petRegistration/widgets/progress_indicator.dart
// Indicador de progreso con puntos para cada paso

import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class ProgressIndicatorr extends StatelessWidget {
  final int currentStep; // 1-5
  final int totalSteps; // 5

  const ProgressIndicatorr({
    super.key,
    required this.currentStep,
    this.totalSteps = 5,
  });

  @override
  Widget build(BuildContext context) {
    // Los puntos son solo visuales: el lector de pantalla anuncia el texto.
    return Semantics(
      label: 'Paso $currentStep de $totalSteps',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalSteps, (index) {
          final stepNumber = index + 1;
          final isCompleted = stepNumber < currentStep;
          final isCurrent = stepNumber == currentStep;

          Color dotColor;
          if (isCurrent) {
            dotColor = AppColors.trustBlue; // Azul actual
          } else if (isCompleted) {
            dotColor = AppColors.esmeraldGreen; // Verde completado
          } else {
            dotColor = AppColors.outline.withValues(
              alpha: 0.3,
            ); // Gris pendiente
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isCurrent ? 28 : 12,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}
