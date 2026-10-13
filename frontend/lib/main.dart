// lib/main.dart

import 'package:chowtrack/features/map/controllers/map_controller.dart';
import 'package:chowtrack/features/petRegistration/wizard.dart';
import 'package:chowtrack/features/pets/controllers/pets_controller.dart';
import 'package:chowtrack/features/profile/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_view.dart';
import 'features/health/controllers/health_reminders_controller.dart';
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
        ChangeNotifierProvider(create: (_) => HealthRemindersController()),
      ],
      child: MaterialApp(
        title: 'ChowTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Español en los componentes de Material: calendario, reloj,
        // tooltips ("Atrás", "Cerrar"), botones de diálogos, etc.
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer<AuthController>(
          builder: (context, auth, child) {
            final Widget screen;
            final String screenKey;

            if (auth.state == AuthState.initial) {
              screen = const _SplashScreen();
              screenKey = 'splash';
            } else if (auth.isAuthenticated) {
              if (auth.hasPets == true) {
                screen = const HomeShell();
                screenKey = 'home';
              } else {
                screen = const PetRegistrationWizard(isFirstRegistration: true);
                screenKey = 'wizard';
              }
            } else {
              screen = const AuthView();
              screenKey = 'auth';
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(key: ValueKey(screenKey), child: screen),
            );
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + (0.1 * value), child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.trustBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.trustBlue.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'ChowTrack',
                style: AppTheme.headlineLg.copyWith(color: AppColors.trustBlue),
              ),
              const SizedBox(height: 4),
              Text(
                'Recuperación de mascotas',
                style: AppTheme.labelLg.copyWith(color: AppColors.outline),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.trustBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
