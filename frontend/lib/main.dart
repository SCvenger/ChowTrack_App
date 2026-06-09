// lib/main.dart

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:chowtrack/features/petRegistration/wizard.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:chowtrack/features/profile/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_view.dart';
import 'features/navigation/navigation_controller.dart';
import 'features/navigation/home_shell.dart';

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
        ChangeNotifierProvider(create: (_) => PetsController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => PetsMapController()),
      ],
      child: MaterialApp(
        title: 'ChowTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Consumer<AuthController>(
          builder: (context, auth, child) {
            if (auth.state == AuthState.initial) {
              return const _SplashScreen();
            }

            if (auth.isAuthenticated) {
              if (auth.hasPets == true) {
                return const HomeShell();
              }
              return const PetRegistrationWizard(isFirstRegistration: true);
            }

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