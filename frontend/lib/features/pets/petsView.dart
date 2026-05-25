import 'package:flutter/material.dart';

class PetsView extends StatelessWidget {
  const PetsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ChowTrack"), centerTitle: true ),
      body: const Center(child: Text("Pantalla de Mascotas")),
    );
  }
}
