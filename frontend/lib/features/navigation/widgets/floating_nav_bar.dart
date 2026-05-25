// lib/features/navigation/widgets/floating_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../../features/auth/auth_controller.dart';
import '../navigation_controller.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomPadding),
      child: Material(
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.85),
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
                activeIcon: Icons.home,
                inactiveIcon: Icons.home_outlined,
                isActive: nav.currentIndex == 0,
                onTap: () => nav.setIndex(0),
              ),
              _NavItem(
                activeIcon: Icons.map,
                inactiveIcon: Icons.map_outlined,
                isActive: nav.currentIndex == 1,
                onTap: () => nav.setIndex(1),
              ),
              _NavItem(
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

class _NavItem extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 48,
        child: Center(
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
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.outline,
                ),
              ),
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

  const _NavAvatarItem({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 48,
        child: Center(
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
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.inputFill,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: isActive ? Colors.white : AppColors.outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}