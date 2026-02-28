import 'dart:convert';

import '../storage/secure_storage_service.dart';

class CloudIdMapService {
  CloudIdMapService(this._storage);

  final SecureStorageService _storage;

  static const String _kMapKey = 'cloud_id_map_v1';

  Future<Map<String, String>> _readMap() async {
    final raw = await _storage.readString(_kMapKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(Map<String, String> map) async {
    await _storage.writeString(_kMapKey, jsonEncode(map));
  }

  Future<String?> getCloudIdForLocal(int localId) async {
    final map = await _readMap();
    return map[localId.toString()];
  }

  Future<void> setCloudIdForLocal(int localId, String cloudId) async {
    final map = await _readMap();
    map[localId.toString()] = cloudId;
    await _writeMap(map);
  }

  Future<void> removeLocal(int localId) async {
    final map = await _readMap();
    map.remove(localId.toString());
    await _writeMap(map);
  }
}
