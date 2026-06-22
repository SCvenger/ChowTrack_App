import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/app_theme.dart';
import '../../core/services/pet_service.dart';
import '../../core/services/token_storage.dart';
import '../profile/services/profile_service.dart';
import '../auth/auth_controller.dart';
import 'models/pet_registration_data.dart';
import 'steps/step1_pet_data.dart';
import 'steps/step2_explanation.dart';
import 'steps/step3_nose_scan.dart';
import 'steps/step4_phone.dart';
import 'steps/step5_success.dart';

class PetRegistrationWizard extends StatefulWidget {
  final bool isFirstRegistration;

  const PetRegistrationWizard({super.key, required this.isFirstRegistration});

  @override
  State<PetRegistrationWizard> createState() => _PetRegistrationWizardState();
}

class _PetRegistrationWizardState extends State<PetRegistrationWizard> {
  int _currentStep = 1;
  String? _petName;
  String? _petBreed;
  int? _petAge;
  File? _petPhoto;

  // Datos opcionales de pasos posteriores
  File? _nosePhoto;
  String? _phone;

  // Si el usuario ya registró su teléfono antes, el paso 4 se omite
  bool _skipPhoneStep = false;

  // Estado de carga al guardar en el Step 5
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkPhoneStatus();
  }

  Future<void> _checkPhoneStatus() async {
    // 1. Rápido: flag local (mismo usuario, misma sesión o sesiones previas)
    final registered = await TokenStorage.hasRegisteredPhone();
    if (registered) {
      if (mounted) setState(() => _skipPhoneStep = true);
      return;
    }

    // 2. Si el flag no existe, consultar el perfil del servidor.
    //    Cubre el caso de logout + login: el teléfono ya está en la BD
    //    aunque el flag local fue borrado por clearAll().
    try {
      final profile = await ProfileService.getMyProfile();
      if (profile.hasPhone) {
        await TokenStorage.markPhoneRegistered(); // cachear para la próxima vez
        if (mounted) setState(() => _skipPhoneStep = true);
      }
    } catch (_) {
      // Si no se puede cargar el perfil no se bloquea el wizard;
      // simplemente se muestra el paso de teléfono.
    }
  }

  // Navegación entre pasos

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  // Handlers de cada paso

  /// Step 1 — datos básicos: Map< String, dynamic> viene del step,
  /// los extrayemos aquí con tipos explícitos.
  void _handleStep1Complete(Map<String, dynamic> data) {
    setState(() {
      _petName  = data['name']  as String;
      _petBreed = data['breed'] as String;
      _petAge   = data['age']   as int;
      _petPhoto = data['photo'] as File;
      _currentStep = 2;
    });
  }

  void _handleStep2Complete() => _goToStep(3);

  void _handleStep3Complete(File? nosePhoto) {
    setState(() {
      _nosePhoto   = nosePhoto;
      // Si ya tiene teléfono registrado, salta directo al resumen
      _currentStep = _skipPhoneStep ? 5 : 4;
    });
  }

  void _handleStep4Complete(String? phone) {
    setState(() {
      _phone       = phone;
      _currentStep = 5;
    });
  }

  Future<void> _handleStep5Complete() async {
    await _savePet();
  }

  Future<void> _savePet() async {
    setState(() => _isSaving = true);

    try {
      final registrationData = PetRegistrationData(
        name:      _petName!,
        breed:     _petBreed!,
        age:       _petAge!,
        photo:     _petPhoto!,
        nosePhoto: _nosePhoto,
        phone:     _phone,
      );

      final userId = await TokenStorage.getUserId();
      if (userId == null) {
        _showError('Sesión expirada. Por favor, vuelve a iniciar sesión.');
        return;
      }

      await PetService.createPet(registrationData, userId);

      // Recordar que el teléfono ya quedó registrado (omite el paso 4 a futuro)
      if (_phone != null) {
        await TokenStorage.markPhoneRegistered();
      }

      if (!mounted) return;

      // Notifica al AuthController que el usuario ya tiene mascotas.
      // En el primer registro (wizard como pantalla raíz), esto hace que
      // el Consumer de main.dart reemplace el wizard por el HomeShell.
      context.read<AuthController>().markHasPets();

      // Si el wizard fue abierto desde otra pantalla (ej. PetsView),
      // simplemente se cierra y vuelve a ella.
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } on PetServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.bodyMd.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.panicRed,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 1) {
          // El botón atrás del sistema retrocede un paso
          // (si venimos del paso 5 y el teléfono se omitió, vuelve al 3)
          final previous = (_currentStep == 5 && _skipPhoneStep)
              ? 3
              : _currentStep - 1;
          _goToStep(previous);
        }
      },
      child: Stack(
        children: [
          _buildCurrentStep(),

          // Overlay de carga al guardar
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                      SizedBox(height: AppTheme.stackSm),
                      Text(
                        'Registrando a ${_petName ?? 'tu mascota'}...',
                        style: AppTheme.bodyMd.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return Step1PetData(
          onComplete: _handleStep1Complete,
          // Solo permite salir del wizard si fue abierto desde otra pantalla
          onBack: Navigator.canPop(context)
              ? () => Navigator.pop(context)
              : null,
        );

      case 2:
        return Step2Explanation(onComplete: _handleStep2Complete);

      case 3:
        return Step3NoseScan(
          onComplete: _handleStep3Complete,
          onBack: () => _goToStep(2),
          petName: _petName ?? 'tu mascota',
        );

      case 4:
        return Step4Phone(onComplete: _handleStep4Complete);

      case 5:
        return Step5Success(
          petName:     _petName     ?? '',
          breed:       _petBreed    ?? '',
          age:         _petAge      ?? 0,
          phoneNumber: _phone,
          onComplete:  _handleStep5Complete,
        );

      default:
        return Scaffold(
          body: Center(
            child: Text(
              'Error: paso desconocido',
              style: AppTheme.bodyMd,
            ),
          ),
        );
    }
  }
}
