import 'package:chowtrack/core/app_theme.dart';
import 'package:chowtrack/core/utils/app_validators.dart';
import 'package:chowtrack/features/auth/email_verification_view.dart';
import 'package:chowtrack/features/home/homeview.dart';
import 'package:chowtrack/features/petRegistration/wizardsteps.dart'; // ¡Vuelve a ser útil aquí!
import 'package:flutter/material.dart';
import 'auth_controller.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final AuthController _authController = AuthController();
  final _formKey = GlobalKey<FormState>();

  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.authenticateWithEmail(
        identity: _identityController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (success && mounted) {
        if (_authController.isLoginMode) {
          // Flujo Email 1: Usuario existente -> Al mapa
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeView()),
          );
        } else {
          // Flujo Email 2: Usuario nuevo -> A verificar correo (quien luego lo mandará al Wizard)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EmailVerificationView(email: _identityController.text.trim()),
            ),
          );
        }
      } else if (mounted && _authController.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_authController.errorMessage!),
            backgroundColor: AppColors.panicRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  _authController.isLoginMode
                      ? "¡Hola de nuevo!"
                      : "Crea tu cuenta",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _identityController,
                  keyboardType: _authController.isLoginMode
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _authController.isLoginMode
                        ? "Correo o Nombre de Usuario"
                        : "Correo Electrónico",
                    hintText: _authController.isLoginMode
                        ? "ejemplo@gmail.com o tu_usuario"
                        : "usuario@gmail.com",
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    if (!_authController.isLoginMode) {
                      return AppValidators.email(value);
                    }
                    return null;
                  },
                ),
                AppTheme.spacer,

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Contraseña",
                    hintText: "**********",
                  ),
                  validator: AppValidators.password,
                ),

                if (!_authController.isLoginMode) ...[
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirmar Contraseña",
                      hintText: "**********",
                    ),
                    validator: (value) => AppValidators.match(
                      value,
                      _passwordController.text,
                      'Las contraseñas no coinciden',
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                _authController.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : FilledButton(
                        onPressed: _submitForm,
                        child: Text(
                          _authController.isLoginMode
                              ? "ENTRAR"
                              : "REGISTRARME",
                        ),
                      ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: _authController.toggleMode,
                  child: Text(
                    _authController.isLoginMode
                        ? "¿No tienes cuenta? Regístrate"
                        : "¿Ya tienes cuenta? Inicia sesión",
                  ),
                ),

                const SizedBox(height: 40),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("o"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 40),

                OutlinedButton.icon(
                  onPressed: () async {
                    final currentContext = context;
                    final googleSuccess = await _authController
                        .signInWithGoogle();

                    if (!currentContext.mounted) return;

                    if (googleSuccess) {
                      // Corrección de lógica para Google: Filtramos por modo de pantalla
                      if (_authController.isLoginMode) {
                        // Flujo Google 1: Login exitoso -> Al mapa directamente
                        Navigator.pushReplacement(
                          currentContext,
                          MaterialPageRoute(builder: (_) => const HomeView()),
                        );
                      } else {
                        // Flujo Google 2: Registro exitoso -> Se salta la verificación y va al Wizard
                        Navigator.pushReplacement(
                          currentContext,
                          MaterialPageRoute(
                            builder: (_) => const PetRegistrationWizard(),
                          ),
                        );
                      }
                    } else if (_authController.errorMessage != null) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(_authController.errorMessage!),
                          backgroundColor: AppColors.panicRed,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 30),
                  label: Text(
                    _authController.isLoginMode
                        ? "Continuar con Google"
                        : "Registrarse con Google",
                  ),
                ),
                AppTheme.spacer,

                OutlinedButton.icon(
                  onPressed: _authController.signInWithApple,
                  icon: const Icon(Icons.apple),
                  label: Text(
                    _authController.isLoginMode
                        ? "Continuar con Apple"
                        : "Registrarse con Apple",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
