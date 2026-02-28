import 'package:flutter/material.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../vault/ui/vault_list_screen.dart';
import '../../../app/home_shell.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  bool _isStrong(String s) {
    if (s.length < 12) return false;
    final hasLower = RegExp(r'[a-z]').hasMatch(s);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(s);
    return hasLower && hasUpper && hasDigit && hasSymbol;
  }

  Future<void> _create() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final a = _pw1.text;
      final b = _pw2.text;

      if (a != b) {
        throw Exception('Las claves no coinciden.');
      }
      if (!_isStrong(a)) {
        throw Exception(
          'Clave débil. Mínimo 12 caracteres e incluye mayúscula, minúscula, número y símbolo.',
        );
      }

      final service = VaultBootstrapService(SecureStorageService());
      await service.createVault(masterPassword: a);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Vault')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Crea una clave maestra (alfanumérica) para cifrar el vault en este dispositivo.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clave maestra',
                helperText:
                'Mín. 12 chars, mayúscula, minúscula, número y símbolo.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repetir clave maestra',
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Crear vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}