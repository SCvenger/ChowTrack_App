import 'package:chowtrack/core/app_theme.dart';
import 'package:chowtrack/core/utils/app_validators.dart';
import 'package:chowtrack/features/home/homeview.dart';
import 'package:chowtrack/features/petRegistration/wizardsteps.dart';
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

  final _emailController = TextEditingController();
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
    // Limpiamos controladores para evitar fugas de memoria
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authController.dispose();
    super.dispose();
  }

  // Ejecuta la validación del frontend y dispara la lógica del controlador
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.authenticateWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (success && mounted) {
        if (_authController.isLoginMode) {
          // Usuario antiguo -> Va directo al Inicio
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeView()),
          );
        } else {
          // Usuario nuevo -> Va al paso a paso de la mascota
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PetRegistrationWizard()),
          );
        }
      } else if (mounted && _authController.errorMessage != null) {
        // Muestra errores devueltos por el servidor si los hubiera
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

                // CAMPOS DEL FORMULARIO
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    hintText: "usuario@gmail.com",
                  ),
                  validator: AppValidators.email,
                ),
                AppTheme.spacer,
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
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
                    decoration: InputDecoration(
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

                // BOTÓN PRINCIPAL ADAPTATIVO
                _authController.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : FilledButton(
                        onPressed:
                            _submitForm, // Cambiado de () {} a nuestra función de lógica
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

                // BOTONES SOCIALES
                OutlinedButton.icon(
                  onPressed: () async {
                    final googleSuccess = await _authController
                        .signInWithGoogle();
                    if (googleSuccess && mounted) {
                      // Manejar redirección tras autenticar con Google
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
                  onPressed:
                      _authController.signInWithApple, // Apunta al stub vacío
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
