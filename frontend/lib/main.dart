import 'package:chowtrack/features/auth/auth_view.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';

void main() {
  // 1. El punto de inicio absoluto
  runApp(const ChowTrackApp());
}

class ChowTrackApp extends StatelessWidget {
  const ChowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. El Administrador de la aplicación
    return MaterialApp(
      title: 'Chow-Track',
      debugShowCheckedModeBanner: false, // Quita la etiqueta roja de "Debug"
      // 3. Conexión del Tema
      theme: AppTheme.lightTheme,

      // 4. La pantalla inicial
      home: const AuthView(),
    );
  }
}

// Pantalla temporal para ver los resultados
class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chow-Track")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "BIENVENIDO",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "usuario@ejemplo.com",
              ),
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () {
                debugPrint("Botón presionado");
              },
              child: const Text("ENTRAR"),
            ),
          ],
        ),
      ),
    );
  }
}
