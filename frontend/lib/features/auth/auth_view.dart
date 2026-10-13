// lib/features/auth/auth_view.dart

import 'package:chowtrack/core/app_theme.dart';
import 'package:chowtrack/core/utils/app_validators.dart';
import 'package:chowtrack/features/auth/email_verification_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm(AuthController authController) async {
    if (authController.isLoading) return; // evita doble envío por teclado
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final success = await authController.authenticateWithEmail(
      identity: _identityController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      if (!authController.isLoginMode) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EmailVerificationView(email: _identityController.text.trim()),
          ),
        );
      }
    } else if (authController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authController.errorMessage!),
          backgroundColor: AppColors.panicRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // AutofillGroup + autofillHints: el gestor de contraseñas del
          // sistema puede completar y guardar las credenciales.
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // Logo
                  const Icon(Icons.pets, size: 80, color: AppColors.trustBlue),

                  const SizedBox(height: 16),

                  Semantics(
                    header: true,
                    child: Text(
                      authController.isLoginMode
                          ? 'Bienvenido de vuelta'
                          : 'Crea tu cuenta',
                      textAlign: TextAlign.center,
                      style: AppTheme.headlineLg,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    authController.isLoginMode
                        ? 'Ingresa tus datos para continuar'
                        : 'Protege a tu mascota con ChowTrack',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
                  ),

                  const SizedBox(height: 40),

                  // Campo para el email o usuario
                  TextFormField(
                    controller: _identityController,
                    keyboardType: authController.isLoginMode
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    autofillHints: authController.isLoginMode
                        ? const [AutofillHints.username, AutofillHints.email]
                        : const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      labelText: authController.isLoginMode
                          ? "E-mail o Usuario"
                          : "Correo Electrónico",
                      hintText: authController.isLoginMode
                          ? "juan@gmail.com o juan"
                          : "usuario@gmail.com",
                    ),
                    validator: (value) {
                      if (authController.isLoginMode) {
                        return AppValidators.identity(value);
                      } else {
                        return AppValidators.email(value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Campo para la contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    autofillHints: authController.isLoginMode
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: AppValidators.password,
                    textInputAction: authController.isLoginMode
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onFieldSubmitted: authController.isLoginMode
                        ? (_) => _submitForm(authController)
                        : null,
                  ),

                  // Campo para confirmar contraseña
                  if (!authController.isLoginMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitForm(authController),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Botón principal
                  FilledButton(
                    onPressed: authController.isLoading
                        ? null
                        : () => _submitForm(authController),
                    child: authController.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            authController.isLoginMode
                                ? 'Iniciar sesión'
                                : 'Registrarme',
                          ),
                  ),

                  // NOTA: el botón "Continuar con Google" se ocultó porque el
                  // flujo OAuth no puede completarse aún (falta deep link en la
                  // app para recibir el callback). Se reactivará cuando el flujo
                  // esté implementado de extremo a extremo.
                  const SizedBox(height: 24),

                  // Toggle login/registro
                  TextButton(
                    onPressed: authController.isLoading
                        ? null
                        : () {
                            // La confirmación no se arrastra entre modos
                            _confirmPasswordController.clear();
                            authController.toggleMode();
                          },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppTheme.tapTarget),
                    ),
                    child: Text(
                      authController.isLoginMode
                          ? '¿No tienes cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Inicia sesión',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
