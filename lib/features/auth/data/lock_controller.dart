import 'package:flutter/foundation.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';

class LockController extends ChangeNotifier {
  LockController({
    VaultBootstrapService? service,
  }) : _service = service ?? VaultBootstrapService(SecureStorageService());

  final VaultBootstrapService _service;

  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  Future<bool> tryBiometric() async {
    _error = null;
    _setBusy(true);

    try {
      await _service.unlockVaultWithBiometrics();
      return true;
    } on StateError catch (e) {
      _error =
      '${e.message}. Desbloquea una vez con la clave maestra para activarla.';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> unlockWithMaster(String masterPassword) async {
    _error = null;
    _setBusy(true);

    try {
      if (masterPassword.isEmpty) {
        throw Exception('Introduce tu clave maestra.');
      }
      await _service.unlockVault(masterPassword: masterPassword);
      return true;
    } catch (_) {
      _error = 'Clave incorrecta o vault dañado.';
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> getHint() async {
    return await _service.getHint();
  }
}
