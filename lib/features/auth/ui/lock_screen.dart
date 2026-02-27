import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../vault/ui/vault_list_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = LocalAuthentication();
  final _pw = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _tryBiometric() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        setState(() {
          _error = 'Este dispositivo no tiene biometría disponible.';
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para desbloquear el vault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!ok) {
        setState(() => _error = 'No se pudo verificar la biometría.');
      } else {
        setState(() => _error = 'Biometría OK. Introduce tu clave maestra.');
      }
    } catch (e) {
      setState(() => _error = 'Error de biometría.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final master = _pw.text;

      if (master.isEmpty) {
        throw Exception('Introduce tu clave maestra.');
      }

      final service = VaultBootstrapService(SecureStorageService());
      await service.unlockVault(masterPassword: master);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VaultListScreen()),
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
      appBar: AppBar(title: const Text('Desbloquear vault')),
      body: Padding(
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

            const SizedBox(height: 16),
            const Text('O desbloquea con tu clave maestra:'),

            const SizedBox(height: 8),
            TextField(
              controller: _pw,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Clave maestra',
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
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

            const Spacer(),
            FilledButton(
              style: bigButtonStyle,
              onPressed: _busy ? null : _unlock,
              child: _busy
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Desbloquear'),
            ),
          ],
        ),
      ),
    );
  }
}