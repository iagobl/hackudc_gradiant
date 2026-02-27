import 'package:flutter/material.dart';

class VaultListScreen extends StatelessWidget {
  const VaultListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis contraseñas')),
      body: const Center(
        child: Text(
          'Vault vacío.\nPulsa + para añadir tu primera contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Próximo paso: pantalla de crear entrada
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }
}