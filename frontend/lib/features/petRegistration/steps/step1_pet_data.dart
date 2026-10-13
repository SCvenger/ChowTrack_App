import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../core/app_theme.dart';
import '../../../core/utils/app_validators.dart';
import '../../../shared/widgets/photo_picker_widget.dart';
import '../widgets/breed_dropdown.dart';
import '../widgets/progress_indicator.dart';

class Step1PetData extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  /// Cierra el wizard. Es null en el primer registro (no hay a dónde volver).
  final VoidCallback? onBack;

  /// Datos ya ingresados: al volver desde el paso 2 el formulario se
  /// rellena en vez de empezar de cero.
  final String? initialName;
  final String? initialBreed;
  final int? initialAge;
  final File? initialPhoto;

  const Step1PetData({
    super.key,
    required this.onComplete,
    this.onBack,
    this.initialName,
    this.initialBreed,
    this.initialAge,
    this.initialPhoto,
  });

  @override
  State<Step1PetData> createState() => _Step1PetDataState();
}

class _Step1PetDataState extends State<Step1PetData> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _ageController = TextEditingController(
    text: widget.initialAge?.toString(),
  );

  late String? _selectedBreed = widget.initialBreed;
  late File? _selectedPhoto = widget.initialPhoto;

  // El error de foto se muestra junto al picker (no en un snackbar suelto),
  // y solo después del primer intento de continuar.
  bool _showPhotoError = false;

  void _submitForm() {
    final formOk = _formKey.currentState!.validate();
    setState(() => _showPhotoError = _selectedPhoto == null);

    if (formOk && _selectedPhoto != null) {
      FocusScope.of(context).unfocus();
      widget.onComplete({
        'name': _nameController.text.trim(),
        'breed': _selectedBreed,
        'age': int.parse(_ageController.text.trim()),
        'photo': _selectedPhoto,
      });
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
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onBack != null
            ? IconButton(
                tooltip: 'Cancelar registro',
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const ProgressIndicatorr(currentStep: 1),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.marginMobile,
          vertical: AppTheme.gutter,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título
              Semantics(
                header: true,
                child: Text(
                  'Crea el perfil de tu\nmejor amigo',
                  textAlign: TextAlign.center,
                  style: AppTheme.headlineLg,
                ),
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Esta información nos ayudará a personalizar su experiencia de rastreo.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(color: AppColors.outline),
              ),

              const SizedBox(height: AppTheme.stackMd),

              // Photo picker
              PhotoPickerWidget(
                label: 'Foto del cuerpo (no de la nariz)',
                initialPhoto: _selectedPhoto,
                hasError: _showPhotoError,
                onPhotoSelected: (photo) {
                  setState(() {
                    _selectedPhoto = photo;
                    if (photo != null) _showPhotoError = false;
                  });
                },
              ),

              if (_showPhotoError && _selectedPhoto == null) ...[
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Agrega una foto para que puedan reconocerla',
                    style: AppTheme.labelSm.copyWith(color: errorColor),
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.stackMd),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Max, Luna...',
                ),
                style: AppTheme.bodyMd,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: AppValidators.petName,
              ),

              const SizedBox(height: AppTheme.gutter),

              // Raza
              BreedField(
                initialBreed: _selectedBreed,
                onBreedSelected: (breed) {
                  setState(() => _selectedBreed = breed);
                },
              ),

              const SizedBox(height: AppTheme.gutter),

              // Edad — solo dígitos (antes aceptaba "-", "." y ",")
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Edad (años)',
                  hintText: 'Ej. 3',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: AppTheme.bodyMd,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitForm(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: AppValidators.petAge,
              ),

              const SizedBox(height: AppTheme.stackLg),

              // Botón siguiente
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitForm,
                  child: Text(
                    'Siguiente',
                    style: AppTheme.labelLg.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
