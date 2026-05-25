// lib/features/navigation/home_shell.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation_controller.dart';
import 'widgets/floating_nav_bar.dart';
import '../home/homeView.dart';
import '../map/mapView.dart';
import '../pets/petsView.dart';
import '../profile/profileView.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  Widget _buildTabNavigator({
    required GlobalKey<NavigatorState> navigatorKey,
    required Widget root,
  }) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navController = context.watch<NavigationController>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        final currentNav =
            navController.navigatorKeys[navController.currentIndex].currentState;

        // Si hay pantallas en el stack del tab actual, hace pop
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          return;
        }

        // Si no estamos en Home, vuelve a Home
        if (navController.currentIndex != 0) {
          navController.setIndex(0);
          return;
        }

        // Si ya estamos en Home sin stack, sale de la app
        Navigator.of(context).pop();
      },
      child: Scaffold(
        extendBody: true, // El contenido pasa por debajo de la nav flotante
        body: Stack(
          children: [
            // ── Contenido de cada tab ─────────────────────────────────────
            IndexedStack(
              index: navController.currentIndex,
              children: [
                _buildTabNavigator(
                  navigatorKey: navController.navigatorKeys[0],
                  root: const HomeView(),
                ),
                _buildTabNavigator(
                  navigatorKey: navController.navigatorKeys[1],
                  root: const MapView(),
                ),
                _buildTabNavigator(
                  navigatorKey: navController.navigatorKeys[2],
                  root: const PetsView(),
                ),
                _buildTabNavigator(
                  navigatorKey: navController.navigatorKeys[3],
                  root: const ProfileView(),
                ),
              ],
            ),

            // ── Nav bar flotante con slide animation ─────────────────────
            AnimatedSlide(
              offset: navController.isNavBarVisible
                  ? Offset.zero
                  : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNavBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}