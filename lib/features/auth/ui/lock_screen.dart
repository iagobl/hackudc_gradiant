import 'package:flutter/material.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desbloquear Vault')),
      body: const Center(
        child: Text('Aquí irá biometría + clave alfanumérica'),
      ),
    );
  }
}