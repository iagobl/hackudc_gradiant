import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../vault/data/vault_repository.dart';
import 'vault_import_export_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    VaultBootstrapService? bootstrap,
    SecureStorageService? storage,
    VaultRepository? repo,
    VaultImportExportService? importExport,
  })  : _storage = storage ?? SecureStorageService(),
        _bootstrap = bootstrap ?? VaultBootstrapService(storage ?? SecureStorageService()),
        _repo = repo ?? VaultRepository(AppDatabase.instance),
        _importExport = importExport ??
            VaultImportExportService(repo ?? VaultRepository(AppDatabase.instance));

  final VaultBootstrapService _bootstrap;
  final SecureStorageService _storage;
  final VaultRepository _repo;
  final VaultImportExportService _importExport;

  static const String kAutoLockKey = 'settings_auto_lock_seconds';

  bool _biometricsEnabled = false;
  bool _loading = true;
  int _autoLockSeconds = 30;

  bool get biometricsEnabled => _biometricsEnabled;
  bool get loading => _loading;
  int get autoLockSeconds => _autoLockSeconds;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final bioEnabled = await _bootstrap.isBiometricsEnabled();
      final lockStr = await _storage.readString(kAutoLockKey);
      final lockVal = int.tryParse(lockStr ?? '30') ?? 30;

      _biometricsEnabled = bioEnabled;
      _autoLockSeconds = lockVal;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setAutoLock(int seconds) async {
    await _storage.writeString(kAutoLockKey, seconds.toString());
    _autoLockSeconds = seconds;
    notifyListeners();
  }

  Future<void> toggleBiometrics(bool value) async {
    _setLoading(true);
    try {
      if (value) {
        await _bootstrap.enableBiometrics();
      } else {
        await _bootstrap.disableBiometrics();
      }
      _biometricsEnabled = value;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> validateMasterPassword(String masterPassword) async {
    await _bootstrap.unlockVault(masterPassword: masterPassword);
  }

  Future<Uint8List> getExportBytes({required String masterPassword}) async {
    return _importExport.getExportBytes(masterPassword: masterPassword);
  }

  Future<int> importVault({
    required String masterPassword,
    required Uint8List fileBytes,
  }) async {
    return _importExport.importVault(
      masterPassword: masterPassword,
      fileBytes: fileBytes,
    );
  }

  Future<void> changeMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _bootstrap.changeMasterPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}