import 'package:flutter/foundation.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/security/pwned_passwords_service.dart';

class SetupController extends ChangeNotifier {
  SetupController({
    VaultBootstrapService? service,
    PwnedPasswordsService? pwnedService,
  })  : _service = service ?? VaultBootstrapService(SecureStorageService()),
        _pwnedService = pwnedService ?? PwnedPasswordsService();

  final VaultBootstrapService _service;
  final PwnedPasswordsService _pwnedService;

  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  bool isStrong(String s) {
    if (s.length < 12) return false;
    final hasLower = RegExp(r'[a-z]').hasMatch(s);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(s);
    return hasLower && hasUpper && hasDigit && hasSymbol;
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> createVault({
    required String password1,
    required String password2,
  }) async {
    _error = null;
    _setBusy(true);

    try {
      final a = password1;
      final b = password2;

      if (a != b) {
        throw Exception('Las claves no coinciden.');
      }
      if (!isStrong(a)) {
        throw Exception(
          'Clave débil. Mínimo 12 caracteres e incluye mayúscula, minúscula, número y símbolo.',
        );
      }

      final pwnCount = await _pwnedService.getPwnCount(a);
      if (pwnCount > 0) {
        throw Exception(
          'Esta contraseña es insegura, aparece en filtraciones. Por favor, elige otra.',
        );
      }

      await _service.createVault(masterPassword: a);

      try {
        final available = await _service.isBiometricsAvailable();
        if (available) {
          await _service.enableBiometrics();
        }
      } catch (_) {
      }

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  @override
  void dispose() {
    _pwnedService.dispose();
    super.dispose();
  }
}
