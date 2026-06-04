
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../navigation/navigation_controller.dart';
import '../pets/controllers/pets_controller.dart';
import 'edit_profile_screen.dart';
import 'models/profile_model.dart';
import 'controllers/profile_controller.dart';
import 'security_screen.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileController>().loadProfile();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NAVEGACIÓN A SUB-PANTALLAS
  // ──────────────────────────────────────────────────────────────────────────

  void _openSubScreen(Widget screen) {
    final nav = context.read<NavigationController>();
    nav.hideNavBar();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (mounted) nav.showNavBar();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a iniciar sesión para acceder a ChowTrack.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.panicRed,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    context.read<PetsController>().clear();
    context.read<ProfileController>().clear();
    await context.read<AuthController>().logout();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHOTO VIEWER
  // ──────────────────────────────────────────────────────────────────────────

  void _openPhotoViewer(ProfileModel? profile) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => _PhotoViewerDialog(
        avatarUrl: profile?.avatarUrl,
        displayName: profile?.displayName,
        onImagePicked: (path) {
          Navigator.pop(ctx);
          // TODO: subir a Supabase Storage y actualizar perfil
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileController = context.watch<ProfileController>();
    final profile = profileController.profile;
    final isLoading = profileController.isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            // ── Header ─────────────────────────────────────────────────
            _ProfileHeader(
              profile: profile,
              isLoading: isLoading,
              onAvatarTap: () => _openPhotoViewer(profile),
            ),

            const SizedBox(height: 24),

            // ── Sección CUENTA ─────────────────────────────────────────
            _SectionLabel(label: 'Cuenta'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.marginMobile,
              ),
              child: _SettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline,
                    iconColor: AppColors.trustBlue,
                    iconBg: const Color(0xFFE8F0FB),
                    title: 'Mi perfil',
                    subtitle: 'Nombre, teléfono, foto',
                    onTap: () => _openSubScreen(const EditProfileScreen()),
                  ),
                  const _Divider(),
                  _SettingsRow(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF6D51D8),
                    iconBg: const Color(0xFFF0EEFE),
                    title: 'Seguridad',
                    subtitle: 'Cambiar contraseña',
                    onTap: () => _openSubScreen(const SecurityScreen()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Sección NOTIFICACIONES ─────────────────────────────────
            _SectionLabel(label: 'Notificaciones'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.marginMobile,
              ),
              child: _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFFB45309),
                    iconBg: const Color(0xFFFEF3CD),
                    title: 'Notificaciones',
                    subtitle: 'Alertas y avisos de mascotas',
                    value: _notificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _notificationsEnabled = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Sección INFORMACIÓN (placeholder) ─────────────────────
            _SectionLabel(label: 'Información'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.marginMobile,
              ),
              child: _SettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.help_outline,
                    iconColor: AppColors.esmeraldGreen,
                    iconBg: const Color(0xFFE6F4EE),
                    title: 'Ayuda y soporte',
                    subtitle: 'Preguntas frecuentes',
                    isPlaceholder: true,
                    onTap: () => _showComingSoon(),
                  ),
                  const _Divider(),
                  _SettingsRow(
                    icon: Icons.info_outline,
                    iconColor: AppColors.outline,
                    iconBg: AppColors.inputFill,
                    title: 'Acerca de ChowTrack',
                    subtitle: 'Versión, términos, privacidad',
                    isPlaceholder: true,
                    onTap: () => _showComingSoon(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Cerrar sesión ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.marginMobile,
              ),
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: AppColors.panicRed),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.panicRed,
                  side: const BorderSide(
                    color: AppColors.panicRed,
                    width: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Versión ────────────────────────────────────────────────
            Center(
              child: Text(
                'ChowTrack v1.0.0',
                style: AppTheme.labelSm.copyWith(color: AppColors.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente disponible')),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HEADER — avatar + nombre + email con skeleton
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final ProfileModel? profile;
  final bool isLoading;
  final VoidCallback onAvatarTap;

  const _ProfileHeader({
    required this.profile,
    required this.isLoading,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          // Avatar tappable
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.inputFill,
                  backgroundImage: profile?.avatarUrl != null
                      ? NetworkImage(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 48,
                          color: AppColors.trustBlue,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.trustBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Nombre
          isLoading
              ? const _SkeletonBox(width: 140, height: 18)
              : Text(
                  profile?.displayName ?? 'Sin nombre',
                  style: AppTheme.headlineMd,
                ),

          const SizedBox(height: 6),

          // Email / subtítulo
          isLoading
              ? const _SkeletonBox(width: 180, height: 13)
              : Text(
                  profile?.phone ?? 'Sin teléfono registrado',
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHOTO VIEWER DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _PhotoViewerDialog extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final ValueChanged<String> onImagePicked;

  const _PhotoViewerDialog({
    required this.avatarUrl,
    required this.displayName,
    required this.onImagePicked,
  });

  Future<void> _pick(BuildContext ctx, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    onImagePicked(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Foto expandida
          CircleAvatar(
            radius: 100,
            backgroundColor: AppColors.inputFill,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(
                    Icons.person,
                    size: 80,
                    color: AppColors.trustBlue,
                  )
                : null,
          ),

          const SizedBox(height: 16),

          if (displayName != null)
            Text(
              displayName!,
              style: AppTheme.headlineMd.copyWith(color: Colors.white),
            ),

          const SizedBox(height: 40),

          // Acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _PhotoAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Cambiar imagen',
                  onTap: () => _pick(context, ImageSource.gallery),
                ),
                const SizedBox(height: 12),
                _PhotoAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'Tomar foto',
                  onTap: () => _pick(context, ImageSource.camera),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Cancelar
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: AppTheme.bodyMd.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTheme.bodyMd.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COMPONENTES REUTILIZABLES
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.marginMobile,
        0,
        AppTheme.marginMobile,
        8,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.labelSm.copyWith(
          color: AppColors.outline,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPlaceholder;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Ícono
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),

              const SizedBox(width: 14),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMd.copyWith(
                        color: isPlaceholder
                            ? AppColors.outline
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // Flecha
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isPlaceholder
                    ? AppColors.outline.withValues(alpha: 0.4)
                    : AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyMd),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.trustBlue,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}