import 'package:chowtrack/features/petRegistration/wizard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_view.dart';
import 'features/home/homeview.dart';

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

      ], 
      child: MaterialApp(
        title: 'ChowTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        // Ruta inicial con guard de autenticación
        home: Consumer<AuthController>(
          builder: (context, authController, child) {
            if (authController.state == AuthState.initial) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (authController.isAuthenticated) {
              // hasPets null no debería ocurrir aquí,
              // pero por seguridad tratamos null como false (→ Wizard)
              if (authController.hasPets == true) {
                return const HomeView();
              }
              return const PetRegistrationWizard();
            }
 
            // No autenticado 
            return const AuthView();
          },
        ),

        // Rutas nombradas para navegación
        routes: {
          '/auth': (context) => const AuthView(),
          '/home': (context) => const HomeView(),
        },
      ),
    );
  }
}
