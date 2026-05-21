import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/app_theme.dart';
import '../../../core/utils/app_validators.dart';
import '/../../shared/widgets/photo_picker_widget.dart';
import '../widgets/breed_dropdown.dart';

class Step1PetData extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const Step1PetData({
    super.key,
    required this.onComplete,
  });

  @override
  State<Step1PetData> createState() => _Step1PetDataState();
}

class _Step1PetDataState extends State<Step1PetData> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedBreed;
  File? _selectedPhoto;

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedPhoto != null) {
      widget.onComplete({
        'name': _nameController.text.trim(),
        'breed': _selectedBreed,
        'age': int.parse(_ageController.text.trim()),
        'photo': _selectedPhoto,
      });
    } else if (_selectedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, agrega una foto de tu mascota',
            style: AppTheme.bodyMd.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.panicRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Chow-Track', style: AppTheme.headlineMd),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.marginMobile,
          vertical: AppTheme.gutter,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título
              Text(
                'Crea el perfil de tu\nmejor amigo',
                textAlign: TextAlign.center,
                style: AppTheme.headlineLg,
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Esta información nos ayudará a personalizar su experiencia de rastreo.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
              ),

              SizedBox(height: AppTheme.stackMd),

              // Photo picker
              PhotoPickerWidget(
                label: 'Foto del cuerpo (no de la nariz)',
                onPhotoSelected: (photo) {
                  setState(() => _selectedPhoto = photo);
                },
              ),

              SizedBox(height: AppTheme.stackMd),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Max, Luna...',
                ),
                style: AppTheme.bodyMd,
                validator: AppValidators.petName,
              ),

              SizedBox(height: AppTheme.gutter),

              // Raza
              BreedField(
                initialBreed: _selectedBreed,
                onBreedSelected: (breed) {
                  setState(() => _selectedBreed = breed);
                },
              ),

              SizedBox(height: AppTheme.gutter),

              // Edad
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Edad (Años)',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                style: AppTheme.bodyMd,
                validator: AppValidators.petAge,
              ),

              SizedBox(height: AppTheme.stackLg),

              // Botón siguiente
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitForm,
                  child: Text('Siguiente', style: AppTheme.labelLg.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}