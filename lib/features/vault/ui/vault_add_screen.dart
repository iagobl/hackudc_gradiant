import 'package:flutter/material.dart';
import '../data/vault_repository.dart';

class VaultAddScreen extends StatefulWidget {
  const VaultAddScreen({super.key, required this.repo});

  final VaultRepository repo;

  @override
  State<VaultAddScreen> createState() => _VaultAddScreenState();
}

class _VaultAddScreenState extends State<VaultAddScreen> {
  final _title = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _url = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_title.text.trim().isEmpty) throw Exception('Introduce un nombre (ej: Google).');
      if (_user.text.trim().isEmpty) throw Exception('Introduce el usuario/email.');
      if (_pass.text.isEmpty) throw Exception('Introduce la contraseña.');

      await widget.repo.addEntry(
        title: _title.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        url: _url.text.trim().isEmpty ? null : _url.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _user.dispose();
    _pass.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bigButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Añadir contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Servicio (ej: Google)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Usuario / Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'URL (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: bigButtonStyle,
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            )
          ],
        ),
      ),
    );
  }
}