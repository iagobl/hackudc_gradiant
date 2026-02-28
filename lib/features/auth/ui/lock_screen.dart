import 'package:flutter/material.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../app/home_shell.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pw = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  late final VaultBootstrapService _service =
  VaultBootstrapService(SecureStorageService());

  Future<void> _showCenterMessage({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final service = VaultBootstrapService(SecureStorageService());

      // ✅ UNA sola operación biométrica (read)
      await service.unlockVaultWithBiometrics();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
      );
    } on StateError catch (e) {
      setState(() => _error = '${e.message}. Desbloquea una vez con la clave maestra para activarla.');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithMaster() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final master = _pw.text;
      if (master.isEmpty) {
        throw Exception('Introduce tu clave maestra.');
      }

      await _service.unlockVault(masterPassword: master);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
      );
    } catch (_) {
      setState(() => _error = 'Clave incorrecta o vault dañado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bigButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Desbloquear vault')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Para acceder a tus contraseñas, confirma tu identidad.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    FilledButton.icon(
                      style: bigButtonStyle,
                      onPressed: _busy ? null : _tryBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Usar huella / biometría'),
                    ),

                    const SizedBox(height: 20),
                    const Text('O desbloquea con tu clave maestra:'),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _pw,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _unlockWithMaster(),
                      decoration: InputDecoration(
                        labelText: 'Clave maestra',
                        suffixIcon: IconButton(
                          onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: bigButtonStyle,
                  onPressed: _busy ? null : _unlockWithMaster,
                  child: _busy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Desbloquear'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}