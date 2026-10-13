import 'package:chowtrack/features/petRegistration/models/pet_model.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:chowtrack/features/pets/pet_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  // Regresión: el detalle mostraba solo el fondo de color (el layout fallaba
  // y no se pintaba ni el header ni el cuerpo).
  for (final status in ['home', 'lost']) {
    testWidgets('PetDetailView ($status) pinta header, datos y acción', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => PetsController(),
          child: MaterialApp(
            home: PetDetailView(
              pet: PetModel(
                id: 'p1',
                ownerId: 'u1',
                name: 'Maya',
                breed: 'Mestizo',
                ageYears: 1,
                status: status,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('1 año'), findsOneWidget);
      expect(find.text('Salud y carnet veterinario'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(OutlinedButton),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          status == 'lost' ? 'Ya está en casa' : 'Reportar como perdida',
        ),
        findsOneWidget,
      );
    });
  }
}
