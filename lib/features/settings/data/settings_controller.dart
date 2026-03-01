import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/cloud/cloud_auth_service.dart';
import '../../../core/cloud/cloud_sync_manager.dart';
import '../../../core/cloud/cloud_sync_service.dart';
import '../../../core/cloud/cloud_sync_settings_service.dart';
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
    CloudSyncSettingsService? cloudSettings,
    CloudAuthService? cloudAuth,
    CloudSyncService? cloudSync,
  })  : _storage = storage ?? SecureStorageService(),
        _bootstrap = bootstrap ?? VaultBootstrapService(storage ?? SecureStorageService()),
        _repo = repo ?? VaultRepository(AppDatabase.instance),
        _importExport = importExport ??
            VaultImportExportService(repo ?? VaultRepository(AppDatabase.instance)),
        _cloudSettings = cloudSettings ?? CloudSyncSettingsService(storage ?? SecureStorageService()),
        _cloudAuth = cloudAuth ?? const CloudAuthService(),
        _cloudSync = cloudSync ??
            CloudSyncService(
              auth: cloudAuth ?? const CloudAuthService(),
              localRepo: repo ?? VaultRepository(AppDatabase.instance),
              db: AppDatabase.instance,
              storage: storage ?? SecureStorageService(),
            );

  final VaultBootstrapService _bootstrap;
  final SecureStorageService _storage;
  final VaultRepository _repo;
  final VaultImportExportService _importExport;

  final CloudSyncSettingsService _cloudSettings;
  final CloudAuthService _cloudAuth;
  final CloudSyncService _cloudSync;

  static const String kAutoLockKey = 'settings_auto_lock_seconds';

  bool _biometricsEnabled = false;
  bool _loading = true;
  int _autoLockSeconds = 30;

  bool _cloudEnabled = false;

  bool get biometricsEnabled => _biometricsEnabled;
  bool get loading => _loading;
  int get autoLockSeconds => _autoLockSeconds;

  bool get cloudEnabled => _cloudEnabled;
  bool get cloudSignedIn => _cloudAuth.isSignedIn;
  String? get cloudUserEmail => _cloudAuth.currentUser?.email;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final bioEnabled = await _bootstrap.isBiometricsEnabled();
      final lockStr = await _storage.readString(kAutoLockKey);
      final lockVal = int.tryParse(lockStr ?? '30') ?? 30;

      final cloudEnabled = await _cloudSettings.isEnabled();

      _biometricsEnabled = bioEnabled;
      _autoLockSeconds = lockVal;
      _cloudEnabled = cloudEnabled;
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
    String? hint,
  }) async {
    await _bootstrap.changeMasterPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      hint: hint,
    );

    if (_cloudEnabled && _cloudAuth.isSignedIn) {
      await _cloudSync.bootstrapCloud(masterPassword: newPassword);
    }
  }

  Future<void> signInCloud({
    required String email,
    required String password,
  }) async {
    await _cloudAuth.signInWithPassword(email: email, password: password);
    notifyListeners();
  }

  Future<void> signUpCloud({
    required String email,
    required String password,
  }) async {
    await _cloudAuth.signUpWithPassword(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOutCloud() async {
    if (_cloudEnabled) {
      await setCloudEnabled(enabled: false);
    }
    await _cloudAuth.signOut();
    notifyListeners();
  }

  Future<void> setCloudEnabled({
    required bool enabled,
    String? masterPassword,
  }) async {
    if (!enabled) {
      await _cloudSettings.setEnabled(false);
      _cloudEnabled = false;

      await CloudSyncManager.instance.stop();

      notifyListeners();
      return;
    }

    if (!_cloudAuth.isSignedIn) {
      throw Exception('Inicia sesión en Supabase primero.');
    }
    if (masterPassword == null || masterPassword.isEmpty) {
      throw Exception('Necesitamos tu clave maestra para activar el cloud.');
    }

    await validateMasterPassword(masterPassword);

    await _cloudSettings.setEnabled(true);
    _cloudEnabled = true;

    await _cloudSync.bootstrapCloud(masterPassword: masterPassword);

    await CloudSyncManager.instance.start();

    notifyListeners();
  }

  Future<int> importFromCloud({required String masterPassword}) async {
    if (!_cloudAuth.isSignedIn) {
      throw Exception('Inicia sesión en Supabase primero.');
    }
    if (masterPassword.isEmpty) {
      throw Exception('Introduce la clave maestra.');
    }
    await validateMasterPassword(masterPassword);

    final count = await _cloudSync.importFromCloud(masterPassword: masterPassword);
    return count;
  }

  Future<void> syncNow() async {
    if (!_cloudAuth.isSignedIn) throw Exception('Inicia sesión en Supabase primero.');
    await _cloudSync.pushAllLocalEntries();
  }
}