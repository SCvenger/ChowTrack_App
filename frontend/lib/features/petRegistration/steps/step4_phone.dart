import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/app_validators.dart';
import '../widgets/progress_indicator.dart';

class Step4Phone extends StatefulWidget {
  final Function(String?) onComplete;
  final VoidCallback onBack;

  /// Teléfono ya ingresado ("+591 71234567") al volver desde el resumen.
  final String? initialPhone;

  const Step4Phone({
    super.key,
    required this.onComplete,
    required this.onBack,
    this.initialPhone,
  });

  @override
  State<Step4Phone> createState() => _Step4PhoneState();
}

class _Step4PhoneState extends State<Step4Phone> {
  final _formKey = GlobalKey<FormState>();
  late final _phoneController = TextEditingController(
    text: widget.initialPhone?.replaceFirst('+591 ', ''),
  );

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim().isNotEmpty
          ? '+591 ${_phoneController.text.trim()}'
          : null;

      widget.onComplete(phone);
    }
  }

  void _skipPhone() {
    widget.onComplete(null);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const ProgressIndicatorr(currentStep: 4),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.marginMobile,
            vertical: 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  '¿Cómo te contactamos?',
                  style: AppTheme.headlineMd,
                ),

                SizedBox(height: AppTheme.stackSm),

                // Descripción
                Text(
                  'Necesitamos tu número para contactarte si alguien encuentra a tu mascota.',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.outline,
                    height: 1.6,
                  ),
                ),

                SizedBox(height: AppTheme.stackMd),

                // Input teléfono
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '71234567',
                    prefixText: '+591 ',
                  ),
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitForm(),
                  style: AppTheme.bodyMd,
                  validator: AppValidators.phoneBolivia,
                ),

                SizedBox(height: AppTheme.stackSm),

                // Nota
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Usaremos este número solo para contactarte sobre tu mascota.',
                        style: AppTheme.labelSm.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppTheme.stackLg),

                // Botones
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitForm,
                    child: Text('Continuar', style: AppTheme.labelLg.copyWith(color: Colors.white)),
                  ),
                ),

                SizedBox(height: AppTheme.stackSm),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _skipPhone,
                    child: Text('Agregarlo después', style: AppTheme.labelLg),
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