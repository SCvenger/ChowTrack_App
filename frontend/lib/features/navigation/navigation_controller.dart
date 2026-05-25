// lib/features/navigation/navigation_controller.dart
//
// Cerebro de la navegación por tabs.
// Mantiene el índice activo, las GlobalKeys de cada Navigator
// y el estado de visibilidad de la barra flotante.
//
// RESPONSABILIDADES:
//   - Cambiar de tab (setIndex)
//   - Volver al root de un tab cuando se toca el tab activo
//   - Mostrar/ocultar la nav bar (wizard, sub-pantallas de perfil)
//   - Deep linking desde notificaciones (navigateToTab)
//
// USO:
//   context.read<NavigationController>().setIndex(2);
//   context.read<NavigationController>().hideNavBar();

import 'package:flutter/material.dart';

class NavigationController extends ChangeNotifier {
  // Índice del tab actualmente visible (0=Home, 1=Map, 2=Pets, 3=Profile)
  int _currentIndex = 0;

  // Controla si la barra flotante se muestra.
  // Se oculta durante el wizard y en sub-pantallas de perfil.
  bool _isNavBarVisible = true;

  int get currentIndex => _currentIndex;
  bool get isNavBarVisible => _isNavBarVisible;

  // Una GlobalKey por tab — permite navegar programáticamente
  // dentro del stack de cualquier tab desde cualquier contexto.
  final List<GlobalKey<NavigatorState>> navigatorKeys = [
    GlobalKey<NavigatorState>(), // 0: Home
    GlobalKey<NavigatorState>(), // 1: Map
    GlobalKey<NavigatorState>(), // 2: Pets
    GlobalKey<NavigatorState>(), // 3: Profile
  ];

  // Cambia al tab indicado.
  // Si el tab ya está activo, limpia su stack (vuelve a la pantalla raíz).
  void setIndex(int index) {
    if (_currentIndex == index) {
      navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  // Muestra la barra. Llamar desde dispose() de pantallas inmersivas.
  void showNavBar() {
    if (_isNavBarVisible) return;
    _isNavBarVisible = true;
    notifyListeners();
  }

  // Oculta la barra. Llamar desde initState() de pantallas inmersivas
  // como el wizard o las sub-pantallas de perfil.
  void hideNavBar() {
    if (!_isNavBarVisible) return;
    _isNavBarVisible = false;
    notifyListeners();
  }

  // Navega a un tab específico y opcionalmente empuja una ruta dentro de él.
  // Usado principalmente por el sistema de notificaciones push (FCM).
  void navigateToTab(int index, {String? route, Object? args}) {
    setIndex(index);
    if (route != null) {
      navigatorKeys[index].currentState?.pushNamed(route, arguments: args);
    }
  }
}