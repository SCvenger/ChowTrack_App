import 'package:chowtrack/features/auth/auth_controller.dart';
import 'package:chowtrack/features/auth/auth_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('La pantalla de acceso muestra el formulario de inicio de sesión',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: const MaterialApp(home: AuthView()),
      ),
    );
    await tester.pump();

    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
