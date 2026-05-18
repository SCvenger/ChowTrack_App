import 'package:chowtrack/features/auth/auth_view.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';

void main() {
  // 1. Punto de entrada
  runApp(const ChowTrackApp());
}

class ChowTrackApp extends StatelessWidget {
  const ChowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. El Administrador de la aplicación
    return MaterialApp(
      title: 'Chow-Track',
      debugShowCheckedModeBanner: false,
      // 3. Conexión del Tema
      theme: AppTheme.lightTheme,
      // 4. La pantalla inicial
      home: const AuthView(),
    );
  }
}
