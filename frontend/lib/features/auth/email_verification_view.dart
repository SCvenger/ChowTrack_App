import 'dart:async';
import 'package:chowtrack/core/app_theme.dart';
import 'package:chowtrack/features/petRegistration/wizardsteps.dart';
import 'package:flutter/material.dart';
import 'auth_controller.dart';

class EmailVerificationView extends StatefulWidget {
  final String email;

  const EmailVerificationView({super.key, required this.email});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  final AuthController _authController = AuthController();
  bool _isChecking = false;
  Timer? _autoCheckTimer; // 1. Mover la variable aquí arriba con los estados

  // 2. CICLO DE VIDA: ElinitState siempre va al inicio de la estructura del State
  @override
  void initState() {
    super.initState();
    // Cada 4 segundos verifica automáticamente si ya activó su cuenta
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _silentCheckStatus();
    });
  }

  @override
  void dispose() {
    _autoCheckTimer
        ?.cancel(); // Cancelar el timer antes de desechar el controlador
    _authController.dispose();
    super.dispose();
  }

  // 3. MÉTODOS LÓGICOS DE FLUJO Y DIÁLOGOS

  // Método silencioso que no levanta diálogos molestos ni bloquea la pantalla
  Future<void> _silentCheckStatus() async {
    try {
      final isVerified = await _authController.checkEmailVerification(
        widget.email,
      );
      if (isVerified && mounted) {
        _autoCheckTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PetRegistrationWizard()),
        );
      }
    } catch (_) {
      // Silenciar errores en background para no interrumpir al usuario
    }
  }

  // Función para mostrar la burbuja de error en el medio (Custom Dialog)
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
                    style: FilledButton.styleFrom(backgroundColor: color),
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

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);

    try {
      final isVerified = await _authController.checkEmailVerification(
        widget.email,
      );
      debugPrint(
        "QA Debug Frontend -> ¿El backend dice que está verificado?: $isVerified",
      );

      if (!mounted) return;

      if (isVerified) {
        _autoCheckTimer?.cancel(); // Cancelamos también aquí por seguridad
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PetRegistrationWizard()),
        );
      } else {
        _showErrorDialog(
          "Cuenta Pendiente",
          "Aún no hemos detectado tu confirmación. Por favor, revisa tu correo electrónico y haz clic en el enlace.",
          Icons.mark_email_unread_outlined,
          AppColors.panicRed,
        );
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

  // 4. DISEÑO/MÉTODO BUILD: Siempre va al final de la clase para facilitar la lectura del árbol de widgets
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Hemos enviado un enlace de confirmación a:\n${widget.email}\n\nActiva tu cuenta desde tu bandeja para poder continuar.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.outline),
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
