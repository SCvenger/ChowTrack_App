import 'package:flutter/material.dart';

class PetRegistrationWizard extends StatelessWidget {
  const PetRegistrationWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro de Mascota")),
      body: const Center(child: Text("Pantalla de Registro")),
    );
  }
}
