import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> writeString(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> readString(String key) =>
      _storage.read(key: key);

  Future<void> delete(String key) =>
      _storage.delete(key: key);
}