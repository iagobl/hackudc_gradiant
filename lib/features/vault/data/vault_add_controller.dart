import 'package:flutter/foundation.dart';

import '../../../core/security/pwned_passwords_service.dart';
import '../../../core/security/vault_state.dart';
import 'vault_repository.dart';

class VaultAddController extends ChangeNotifier {
  VaultAddController({
    required VaultRepository repo,
    PwnedPasswordsService? pwned,
  })  : _repo = repo,
        _pwned = pwned ?? PwnedPasswordsService();

  final VaultRepository _repo;
  final PwnedPasswordsService _pwned;

  bool _busy = false;
  bool _checking = false;
  bool _requireMasterPassword = false;
  int? _pwnedCount;

  bool get busy => _busy;
  bool get checking => _checking;
  bool get requireMasterPassword => _requireMasterPassword;
  int? get pwnedCount => _pwnedCount;

  void disposeController() {
    _pwned.dispose();
  }

  void setRequireMasterPassword(bool v) {
    _requireMasterPassword = v;
    notifyListeners();
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  void _setChecking(bool v) {
    _checking = v;
    notifyListeners();
  }

  Future<int> checkPwned(String password) async {
    if (_busy || _checking) {
      throw Exception('Operación no disponible ahora.');
    }

    _setChecking(true);
    try {
      final pw = password;
      if (pw.isEmpty) {
        throw Exception('Introduce una contraseña primero para comprobarla.');
      }

      final count = await _pwned.getPwnCount(pw);
      _pwnedCount = count;
      notifyListeners();
      return count;
    } finally {
      _setChecking(false);
    }
  }

  Future<void> save({
    required String title,
    required String username,
    required String password,
    required String? url,
  }) async {
    if (_busy) return;

    _setBusy(true);
    try {
      final t = title.trim();
      final u = username.trim();
      final pw = password;
      final finalUrl = (url == null || url.trim().isEmpty) ? null : url.trim();

      if (t.isEmpty) throw Exception('Introduce un nombre (ej: Google).');
      if (u.isEmpty) throw Exception('Introduce el usuario/email.');
      if (pw.isEmpty) throw Exception('Introduce la contraseña.');

      final dek = VaultState.instance?.dek;
      if (dek == null) throw Exception('Vault bloqueado.');

      await _repo.addEntry(
        title: t,
        username: u,
        password: pw,
        url: finalUrl,
        pwnedCount: _pwnedCount,
        dek: dek,
        requireMasterPassword: _requireMasterPassword,
      );
    } finally {
      _setBusy(false);
    }
  }
}