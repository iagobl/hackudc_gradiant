import '../storage/secure_storage_service.dart';

class CloudSyncSettingsService {
  CloudSyncSettingsService(this._storage);

  final SecureStorageService _storage;

  static const String kCloudSyncEnabledKey = 'settings_cloud_sync_enabled';

  Future<bool> isEnabled() async {
    final v = await _storage.readString(kCloudSyncEnabledKey);
    return v == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.writeString(kCloudSyncEnabledKey, enabled ? 'true' : 'false');
  }
}
