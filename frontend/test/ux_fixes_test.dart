import 'dart:math';

import 'package:chowtrack/core/app_theme.dart';
import 'package:chowtrack/core/utils/app_validators.dart';
import 'package:chowtrack/features/petRegistration/widgets/progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Contraste WCAG 2.x entre dos colores opacos
double _contrast(Color a, Color b) {
  double lin(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  final la = lum(a), lb = lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

// Fondo de badge: color de estado al 12% sobre blanco
Color _tint(Color c) =>
    Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white);

void main() {
  group('AppValidators.phoneBolivia', () {
    test('acepta el formato guardado en el perfil (+591 …)', () {
      expect(AppValidators.phoneBolivia('+591 71234567'), isNull);
      expect(AppValidators.phoneBolivia('59171234567'), isNull);
    });
    test('sigue aceptando 8 dígitos y vacío (opcional)', () {
      expect(AppValidators.phoneBolivia('71234567'), isNull);
      expect(AppValidators.phoneBolivia(''), isNull);
    });
    test('rechaza números inválidos', () {
      expect(AppValidators.phoneBolivia('1234'), isNotNull);
      expect(AppValidators.phoneBolivia('+591 1234'), isNotNull);
      expect(AppValidators.phoneBolivia('51234567'), isNotNull);
    });
  });

  group('AppColors.readable cumple WCAG AA (4.5:1) como texto', () {
    for (final entry in {
      'esmeraldGreen': AppColors.esmeraldGreen,
      'panicRed': AppColors.panicRed,
      'alertAmber': AppColors.alertAmber,
      'trustBlue': AppColors.trustBlue,
    }.entries) {
      test('${entry.key} sobre blanco y sobre su tinte', () {
        final text = AppColors.readable(entry.value);
        expect(_contrast(text, Colors.white), greaterThanOrEqualTo(4.5));
        expect(_contrast(text, _tint(entry.value)), greaterThanOrEqualTo(4.5));
      });
    }

    test('blanco sobre el verde legible (chip/snackbar) ≥ 4.5', () {
      expect(
        _contrast(Colors.white, AppColors.readable(AppColors.esmeraldGreen)),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  testWidgets('ProgressIndicatorr se anuncia como "Paso X de Y"', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProgressIndicatorr(currentStep: 2)),
    );
    expect(find.bySemanticsLabel('Paso 2 de 5'), findsOneWidget);
  });
}
