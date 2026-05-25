import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ChowTrack"), centerTitle: true ),
      body: const Center(child: Text("Pantalla del Perfil")),
    );
  }
}
