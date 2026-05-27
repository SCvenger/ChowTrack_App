// lib/features/auth/email_verification_view.dart

import 'dart:async';
import 'package:chowtrack/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../petRegistration/wizard.dart';
import 'auth_controller.dart';

class EmailVerificationView extends StatefulWidget {
  final String email;

  const EmailVerificationView({super.key, required this.email});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  bool _isChecking = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();

    // Polling silencioso cada 4 segundos
    _autoCheckTimer = Timer.periodic(
      const Duration(seconds: 4),
      (timer) => _silentCheckStatus(),
    );
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  // Verificación en background — polling cada 4 segundos
  Future<void> _silentCheckStatus() async {
    final authController = context.read<AuthController>();

    try {
      final isVerified = await authController.checkEmailVerification(widget.email);

      if (!mounted) return;

      if (isVerified) {
        _autoCheckTimer?.cancel();
        _navigateToWizard();
      }
    } catch (_) {
      // Silenciar errores de background
    }
  }

  // Verificación manual cuando el usuario presiona "YA LO VERIFIQUÉ"
  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);

    final authController = context.read<AuthController>();

    try {
      final isVerified = await authController.checkEmailVerification(
        widget.email,
      );

      if (!mounted) return;

      if (isVerified) {
        _autoCheckTimer?.cancel();
        _navigateToWizard();
      } else {
        _showPendingDialog();
      }
    } catch (e) {
      if (!mounted) return;

      _showErrorDialog(
        "Error de Conexión",
        "No pudimos validar tu estado en este momento: $e",
        Icons.error_outline,
        AppColors.panicRed,
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToWizard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PetRegistrationWizard(isFirstRegistration: false,)),
      (route) => false,
    );
  }

  void _showPendingDialog() {
    _showErrorDialog(
      "Cuenta Pendiente",
      "Aún no hemos detectado tu confirmación.\nRevisa tu correo y haz clic en el enlace.",
      Icons.mark_email_unread_outlined,
      AppColors.panicRed,
    );
  }

  void _showErrorDialog(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 64),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                    ),
                    child: const Text("ENTENDIDO"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mail_lock_outlined,
              size: 80,
              color: AppColors.trustBlue,
            ),

            const SizedBox(height: 24),

            const Text(
              "¡Verifica tu correo!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "Hemos enviado un enlace de confirmación a:\n${widget.email}\n\nActiva tu cuenta desde tu bandeja para poder continuar.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.outline,
              ),
            ),

            const SizedBox(height: 40),

            _isChecking
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _checkVerificationStatus,
                    child: const Text("YA LO VERIFIQUÉ"),
                  ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Volver atrás"),
            ),
          ],
        ),
      ),
    );
  }
}