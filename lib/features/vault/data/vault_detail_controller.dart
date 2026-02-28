import 'package:flutter/foundation.dart';

import '../../../core/security/pwned_passwords_service.dart';
import '../../../core/security/vault_state.dart';
import '../data/vault_repository.dart';
import '../../../core/storage/app_database.dart';

class VaultDetailController extends ChangeNotifier {
  VaultDetailController({
    required VaultRepository repo,
    PwnedPasswordsService? pwned,
  })  : _repo = repo,
        _pwned = pwned ?? PwnedPasswordsService();

  final VaultRepository _repo;
  final PwnedPasswordsService _pwned;

  bool _editing = false;
  bool _revealed = false;
  bool _loadingPw = false;
  bool _checking = false;
  bool _saving = false;

  String? _password;
  String? _error;

  bool get editing => _editing;
  bool get revealed => _revealed;
  bool get loadingPw => _loadingPw;
  bool get checking => _checking;
  bool get saving => _saving;

  String? get password => _password;
  String? get error => _error;

  void disposeController() {
    _pwned.dispose();
  }

  void setEditing(bool v) {
    _editing = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetPasswordView() {
    _password = null;
    _revealed = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> loadPasswordIfNeeded(
      VaultEntry e, {
        required Future<bool> Function() authenticateIfNeeded,
      }) async {
    if (_password != null) return true;

    if (e.requireMasterPassword) {
      final ok = await authenticateIfNeeded();
      if (!ok) return false;
    }

    _loadingPw = true;
    _error = null;
    notifyListeners();

    try {
      final dek = VaultState.instance?.dek;
      if (dek == null) throw 'Vault bloqueado';

      final pw = await _repo.decryptPassword(e.id, dek);
      _password = pw;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo descifrar';
      notifyListeners();
      return false;
    } finally {
      _loadingPw = false;
      notifyListeners();
    }
  }

  Future<void> toggleReveal(
      VaultEntry e, {
        required Future<bool> Function() authenticateIfNeeded,
      }) async {
    if (!_revealed) {
      final ok = await loadPasswordIfNeeded(
        e,
        authenticateIfNeeded: authenticateIfNeeded,
      );
      if (!ok || _password == null) return;
    }

    _revealed = !_revealed;
    notifyListeners();
  }

  Future<bool> ensurePasswordForCopy(
      VaultEntry e, {
        required Future<bool> Function() authenticateIfNeeded,
      }) async {
    final ok = await loadPasswordIfNeeded(
      e,
      authenticateIfNeeded: authenticateIfNeeded,
    );
    return ok && _password != null;
  }

  Future<int?> checkPwned(
      VaultEntry e, {
        required Future<bool> Function() authenticateIfNeeded,
      }) async {
    final ok = await loadPasswordIfNeeded(
      e,
      authenticateIfNeeded: authenticateIfNeeded,
    );
    if (!ok || _password == null) return null;

    _checking = true;
    notifyListeners();

    try {
      final count = await _pwned.getPwnCount(_password!);
      await _repo.setPwnedResult(entryId: e.id, pwnedCount: count);
      return count;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<bool> saveChanges(
      VaultEntry current, {
        required String title,
        required String username,
        required String url,
        required String? newPassword,
        required Future<bool> Function() authenticate,
      }) async {
    if (_saving) return false;

    final dek = VaultState.instance?.dek;
    if (dek == null) return false;

    final authenticated = await authenticate();
    if (!authenticated) return false;

    _saving = true;
    notifyListeners();

    try {
      await _repo.updateEntry(
        id: current.id,
        title: title,
        username: username,
        url: url,
        password: newPassword,
        dek: newPassword != null ? dek : null,
      );

      _editing = false;
      _password = null;
      _revealed = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry(
      VaultEntry e, {
        required Future<bool> Function() authenticate,
      }) async {
    final authenticated = await authenticate();
    if (!authenticated) return false;

    await _repo.deleteEntry(e.id);
    return true;
  }

  Future<bool> setRequireMasterPassword(
      VaultEntry e,
      bool value, {
        required Future<bool> Function() authenticateIfDisabling,
      }) async {
    if (value == false) {
      final ok = await authenticateIfDisabling();
      if (!ok) return false;
      await _repo.updateRequireMasterPassword(e.id, false);
      return true;
    } else {
      await _repo.updateRequireMasterPassword(e.id, true);
      return true;
    }
  }
}