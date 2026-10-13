import 'package:chowtrack/features/health/health_form_view.dart';
import 'package:chowtrack/features/health/models/health_models.dart';
import 'package:chowtrack/features/health/utils/health_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // Sin red en tests: Inter cae a la fuente por defecto
  GoogleFonts.config.allowRuntimeFetching = false;

  group('HealthFormat', () {
    test('fechas simples no se corren de día por zona horaria', () {
      expect(HealthFormat.date('2026-10-01'), '1 oct 2026');
    });
    test('días restantes', () {
      expect(HealthFormat.daysLeft(0), 'Vence hoy');
      expect(HealthFormat.daysLeft(5), 'Vence en 5 días');
      expect(HealthFormat.daysLeft(-12), 'Venció hace 12 días');
      expect(HealthFormat.daysLeft(-1), 'Venció ayer');
    });
    test('números con coma decimal y sin ceros sobrantes', () {
      expect(HealthFormat.number(12.5), '12,5');
      expect(HealthFormat.number(12.0), '12');
    });
    test('fecha-hora para la API incluye la zona del dispositivo', () {
      final s = HealthFormat.toApiDateTime(DateTime(2026, 10, 20, 10, 0));
      expect(s, matches(RegExp(r'^2026-10-20T10:00:00[+-]\d{2}:\d{2}$')));
    });
    test('edad desde meses', () {
      expect(HealthFormat.ageFromMonths(27), '2 años y 3 meses');
      expect(HealthFormat.ageFromMonths(12), '1 año');
    });
  });

  group('Contratos JSON (guía del backend, sección 4.2)', () {
    test('HealthSummary', () {
      final s = HealthSummaryModel.fromJson({
        'pet_id': 'p1',
        'pet_name': 'Maya',
        'photo_url': null,
        'profile': {
          'pet_id': 'p1',
          'sex': 'female',
          'allergies': ['Pollo'],
          'is_registered': true,
        },
        'vaccination_status': 'overdue',
        'deworming_status': 'up_to_date',
        'latest_weight': {
          'id': 'w1',
          'pet_id': 'p1',
          'weight_kg': 12,
          'measured_at': '2026-10-13',
        },
        'next_appointment': null,
        'active_medications': [],
        'reminders': [
          {
            'pet_id': 'p1',
            'pet_name': 'Maya',
            'kind': 'vaccination',
            'record_id': 'v1',
            'title': 'Vacuna Antirrábica',
            'due_date': '2026-10-01',
            'days_left': -12,
            'is_overdue': true,
          },
        ],
        'counts': {'vaccinations': 4, 'medications_active': 1},
      });
      expect(s.profile.allergies, ['Pollo']);
      expect(s.latestWeight!.dbl('weight_kg'), 12.0); // int → double
      expect(s.reminders.single.isOverdue, isTrue);
      expect(s.counts.vaccinations, 4);
      expect(s.counts.documents, 0);
    });

    test('HealthShare', () {
      final s = HealthShareModel.fromJson({
        'id': 's1',
        'pet_id': 'p1',
        'token': 't',
        'share_url': 'https://x/health/shared/t',
        'carnet_url': 'https://x/health/shared/t/carnet',
        'expires_at': '2026-10-14T20:00:00+00:00',
        'revoked_at': null,
        'last_accessed_at': null,
        'is_active': true,
      });
      expect(s.carnetUrl, endsWith('/carnet'));
      expect(s.isActive, isTrue);
    });
  });

  group('HealthFormView', () {
    const fields = [
      HealthField('reason', 'Motivo', required: true, minLength: 2),
      HealthField('vet_name', 'Veterinario/a'),
      HealthField('cost_bob', 'Costo', kind: HealthFieldKind.decimal, min: 0),
    ];

    Future<Map<String, dynamic>?> submit(
      WidgetTester tester, {
      Map<String, dynamic>? initial,
      required Future<void> Function() edit,
    }) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthFormView(
                        title: 'Test',
                        fields: fields,
                        initial: initial,
                        onSubmit: (body) async => sent = body,
                      ),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await edit();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('crear: valida obligatorios y envía solo campos con valor', (
      tester,
    ) async {
      final body = await submit(
        tester,
        edit: () async {
          await tester.enterText(find.byType(TextFormField).at(0), 'Vómitos');
          await tester.enterText(find.byType(TextFormField).at(2), '150,5');
        },
      );
      expect(body, {'reason': 'Vómitos', 'cost_bob': 150.5});
    });

    testWidgets('crear sin obligatorio: no envía y muestra el error', (
      tester,
    ) async {
      final body = await submit(tester, edit: () async {});
      expect(body, isNull);
      expect(find.text('Este campo es obligatorio'), findsOneWidget);
    });

    testWidgets('editar: envía solo lo que cambió (null si se vació)', (
      tester,
    ) async {
      final body = await submit(
        tester,
        initial: {
          'reason': 'Control',
          'vet_name': 'Dr. Pérez',
          'cost_bob': 100,
        },
        edit: () async {
          await tester.enterText(find.byType(TextFormField).at(1), '');
        },
      );
      expect(body, {'vet_name': null});
    });
  });
}
