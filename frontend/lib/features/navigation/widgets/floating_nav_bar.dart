// lib/features/navigation/widgets/floating_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../navigation_controller.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(44, 0, 44, 16 + bottomPadding),
      child: Material(
        elevation: 12,
        shadowColor: AppColors.outline.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                label: 'Inicio',
                activeIcon: Icons.home,
                inactiveIcon: Icons.home_outlined,
                isActive: nav.currentIndex == 0,
                onTap: () => nav.setIndex(0),
              ),
              _NavItem(
                label: 'Mapa',
                activeIcon: Icons.map,
                inactiveIcon: Icons.map_outlined,
                isActive: nav.currentIndex == 1,
                onTap: () => nav.setIndex(1),
              ),
              _NavItem(
                label: 'Mis mascotas',
                activeIcon: Icons.pets,
                inactiveIcon: Icons.pets,
                isActive: nav.currentIndex == 2,
                onTap: () => nav.setIndex(2),
              ),
              _NavAvatarItem(
                isActive: nav.currentIndex == 3,
                onTap: () => nav.setIndex(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
//  Items nav

// Envuelve cada ítem con semántica de tab (nombre + seleccionado) para
// lectores de pantalla, tooltip al mantener presionado y un click háptico.
// La barra es solo-íconos por diseño; sin esto TalkBack lee "botón" a secas.
class _NavTapTarget extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;

  const _NavTapTarget({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.longPress,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(width: 64, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _NavTapTarget(
      label: label,
      isActive: isActive,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isActive ? -4.0 : 0, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 16 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.trustBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? activeIcon : inactiveIcon,
              key: ValueKey(isActive),
              size: 24,
              color: isActive
                  ? AppColors.surface.withValues(alpha: 0.9)
                  : AppColors.outline,
            ),
          ),
        ),
      ),
    );
  }
}

//
// Avatar circular

class _NavAvatarItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _NavAvatarItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _NavTapTarget(
      label: 'Perfil',
      isActive: isActive,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isActive ? -4.0 : 0, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.trustBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: isActive
                ? AppColors.surface.withValues(alpha: 0.25)
                : AppColors.inputFill,
            child: Icon(
              Icons.person,
              size: 18,
              color: isActive ? AppColors.surface : AppColors.outline,
            ),
          ),
        ),
      ),
    );
  }
}
