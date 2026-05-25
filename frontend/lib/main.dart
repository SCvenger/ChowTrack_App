// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_view.dart';
import 'features/navigation/navigation_controller.dart';
import 'features/navigation/home_shell.dart';
import 'features/petRegistration/wizard.dart';

void main() {
  runApp(const ChowTrackApp());
}

class ChowTrackApp extends StatelessWidget {
  const ChowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => NavigationController()),
      ],
      child: MaterialApp(
        title: 'ChowTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        home: Consumer<AuthController>(
          builder: (context, auth, child) {
            // Verificando sesión al inicio
            if (auth.state == AuthState.initial) {
              return const _SplashScreen();
            }

            // Autenticado — rutar según si tiene mascotas
            if (auth.isAuthenticated) {
              if (auth.hasPets == true) {
                return const HomeShell();
              }
              return const PetRegistrationWizard();
            }

            // No autenticado
            return const AuthView();
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}