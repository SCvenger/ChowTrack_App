// lib/features/petRegistration/wizard.dart
// Container principal del wizard que orquesta todos los pasos

import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/app_theme.dart';
import 'steps/step1_pet_data.dart';
import 'steps/step2_explanation.dart';
import 'steps/step3_nose_scan.dart';
import 'steps/step4_phone.dart';
import 'steps/step5_success.dart';

class PetRegistrationWizard extends StatefulWidget {
  const PetRegistrationWizard({super.key});

  @override
  State<PetRegistrationWizard> createState() => _PetRegistrationWizardState();
}

class _PetRegistrationWizardState extends State<PetRegistrationWizard> {
  int _currentStep = 1;

  // Datos recolectados
  late Map<String, dynamic> _petData;
  File? _nosePhoto;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _petData = {};
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  void _handleStep1Complete(Map<String, dynamic> data) {
    setState(() {
      _petData = data;
      _currentStep = 2;
    });
  }

  void _handleStep2Complete() {
    _goToStep(3);
  }

  void _handleStep3Complete(File? photo) {
    setState(() {
      _nosePhoto = photo;
      _currentStep = 4;
    });
  }

  void _handleStep4Complete(String? phone) {
    setState(() {
      _phoneNumber = phone;
      _currentStep = 5;
    });
  }

  void _handleStep5Complete() {

    _savePetToDatabase();
  }

  void _savePetToDatabase() {
    print('Guardando mascota:');
    print('Nombre: ${_petData['name']}');
    print('Raza: ${_petData['breed']}');
    print('Edad: ${_petData['age']}');
    print('Teléfono: $_phoneNumber');
    print('Foto nasal: ${_nosePhoto?.path}');

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 1) {
          _goToStep(_currentStep - 1);
          return false;
        }
        return true;
      },
      child: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return Step1PetData(onComplete: _handleStep1Complete);

      case 2:
        return Step2Explanation(onComplete: _handleStep2Complete);

      case 3:
        return Step3NoseScan(
          onComplete: _handleStep3Complete,
          petName: _petData['name'] ?? 'tu mascota',
        );

      case 4:
        return Step4Phone(onComplete: _handleStep4Complete);

      case 5:
        return Step5Success(
          petName: _petData['name'] ?? '',
          breed: _petData['breed'] ?? '',
          age: _petData['age'] ?? 0,
          phoneNumber: _phoneNumber,
          onComplete: _handleStep5Complete,
        );

      default:
        return Scaffold(
          body: Center(
            child: Text('Error: paso desconocido'),
          ),
        );
    }
  }
}