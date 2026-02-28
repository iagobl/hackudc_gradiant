import 'dart:async';

import '../security/vault_state.dart';
import '../storage/app_database.dart';
import '../../features/vault/data/vault_repository.dart';
import 'cloud_sync_service.dart';
import 'cloud_sync_settings_service.dart';
import '../storage/secure_storage_service.dart';

class CloudSyncManager {
  CloudSyncManager._();

  static final CloudSyncManager instance = CloudSyncManager._();

  StreamSubscription? _sub;
  Timer? _debounce;

  final _settings = CloudSyncSettingsService(SecureStorageService());
  final _sync = CloudSyncService(
    localRepo: VaultRepository(AppDatabase.instance),
    db: AppDatabase.instance,
    storage: SecureStorageService(),
  );

  bool get running => _sub != null;

  Future<void> start() async {
    if (_sub != null) return;

    _sub = VaultRepository(AppDatabase.instance).watchEntries().listen((_) async {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), () async {
        final enabled = await _settings.isEnabled();
        if (!enabled) return;
        if (!VaultState.isUnlocked) return;

        try {
          await _sync.pushAllLocalEntries();
        } catch (_) {
        }
      });
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
  }
}
