import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;

import 'package:cryptography/cryptography.dart';

import '../security/crypto_service.dart';
import '../security/kdf_service.dart';
import '../security/vault_state.dart';
import '../storage/app_database.dart';
import '../storage/secure_storage_service.dart';
import '../../features/vault/data/vault_repository.dart';
import 'cloud_auth_service.dart';
import 'cloud_id_map_service.dart';
import 'cloud_vault_repository.dart';
import 'uuid_v4.dart';

class CloudSyncService {
  CloudSyncService({
    CloudAuthService? auth,
    CloudVaultRepository? cloudRepo,
    VaultRepository? localRepo,
    AppDatabase? db,
    SecureStorageService? storage,
    CloudIdMapService? idMap,
  })  : _auth = auth ?? const CloudAuthService(),
        _cloudRepo = cloudRepo ?? CloudVaultRepository(),
        _localRepo = localRepo ?? VaultRepository(AppDatabase.instance),
        _db = db ?? AppDatabase.instance,
        _storage = storage ?? SecureStorageService(),
        _idMap = idMap ?? CloudIdMapService(SecureStorageService());

  final CloudAuthService _auth;
  final CloudVaultRepository _cloudRepo;
  final VaultRepository _localRepo;
  final AppDatabase _db;
  final SecureStorageService _storage;
  final CloudIdMapService _idMap;

  final CryptoService _crypto = CryptoService();
  final KdfService _kdf = KdfService();

  static const _kSalt = 'vault_salt_b64';
  static const _kVerifier = 'vault_verifier_b64';
  static const _kCipherDEK = 'vault_cipherDEK_b64';
  static const _kCiphertextKEM = 'vault_ciphertextKEM_b64';
  static const _kPrivateKey = 'vault_privateKey_b64';
  static const _kPublicKey = 'vault_publicKey_b64';

  Future<void> bootstrapCloud({required String masterPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Inicia sesión en Supabase antes de activar la sincronización.');
    }

    final dek = VaultState.instance?.dek;
    if (dek == null) {
      throw Exception('Vault bloqueado. Desbloquéalo antes de activar cloud.');
    }

    final header = await _buildCloudHeader(masterPassword: masterPassword);
    await _cloudRepo.upsertHeader(userId: user.id, header: header);

    await pushAllLocalEntries();
  }

  Future<void> pushAllLocalEntries() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado en Supabase.');
    final dek = VaultState.instance?.dek;
    if (dek == null) throw Exception('Vault bloqueado.');

    final entries = await _localRepo.listEntries();

    final localIds = entries.map((e) => e.id).toSet();
    final mapRaw = await _storage.readString('cloud_id_map_v1');
    final Map<String, dynamic> map = (mapRaw == null || mapRaw.isEmpty)
        ? <String, dynamic>{}
        : (jsonDecode(mapRaw) as Map<String, dynamic>);

    final mappedLocalIds = List<String>.from(map.keys);
    bool mapChanged = false;

    for (final localIdStr in mappedLocalIds) {
      final localId = int.tryParse(localIdStr);
      if (localId == null) continue;

      if (!localIds.contains(localId)) {
        final cloudId = map[localIdStr]?.toString();
        if (cloudId != null && cloudId.isNotEmpty) {
          await _cloudRepo.deleteEntry(entryId: cloudId, userId: user.id);
        }
        map.remove(localIdStr);
        mapChanged = true;
      }
    }

    if (mapChanged) {
      await _storage.writeString('cloud_id_map_v1', jsonEncode(map));
    }

    for (final e in entries) {
      final existing = await _idMap.getCloudIdForLocal(e.id);
      final cloudId = existing ?? uuidV4();

      if (existing == null) {
        await _idMap.setCloudIdForLocal(e.id, cloudId);
      }

      final encrypted = await _encryptEntryForCloud(entry: e, dek: dek);

      await _cloudRepo.upsertEntry(
        userId: user.id,
        entryId: cloudId,
        entry: {
          ...encrypted,
          'updated_at': e.updatedAt.toUtc().toIso8601String(),
        },
      );
    }
  }

  Future<int> importFromCloud({required String masterPassword}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado en Supabase.');

    final dek = await _restoreDekFromCloud(userId: user.id, masterPassword: masterPassword);

    final rows = await _cloudRepo.listEntries(userId: user.id);

    int imported = 0;

    for (final row in rows) {
      final entryId = row['entry_id'] as String;
      final cloudUpdatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');

      final plain = await _decryptEntryFromCloud(row: row, dek: dek);

      imported += await _upsertLocalFromCloud(
        cloudEntryId: entryId,
        data: plain,
        cloudUpdatedAt: cloudUpdatedAt,
      );
    }

    return imported;
  }

  Future<Map<String, dynamic>> _buildCloudHeader({required String masterPassword}) async {
    final saltStr = await _storage.readString(_kSalt);
    final verifierStr = await _storage.readString(_kVerifier);
    final cipherDEKStr = await _storage.readString(_kCipherDEK);
    final ciphertextKEMStr = await _storage.readString(_kCiphertextKEM);
    final privateKeyStr = await _storage.readString(_kPrivateKey);
    final publicKeyStr = await _storage.readString(_kPublicKey);

    if (saltStr == null ||
        verifierStr == null ||
        cipherDEKStr == null ||
        ciphertextKEMStr == null ||
        privateKeyStr == null) {
      throw Exception('Vault no inicializado.');
    }

    final salt = base64Decode(saltStr);
    final kek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);

    final privateKeyBytes = base64Decode(privateKeyStr);
    final privateKeyEnc = await _crypto.encryptWithKEK(plain: privateKeyBytes, kek: kek);

    return {
      'salt_b64': saltStr,
      'verifier_b64': verifierStr,
      'cipher_dek_b64': cipherDEKStr,
      'ciphertext_kem_b64': ciphertextKEMStr,
      'private_key_enc_b64': base64Encode(privateKeyEnc),
      'public_key_b64': publicKeyStr,
      'version': 1,
    };
  }

  Future<SecretKey> _restoreDekFromCloud({
    required String userId,
    required String masterPassword,
  }) async {
    final header = await _cloudRepo.getHeader(userId: userId);
    if (header == null) {
      throw Exception('No hay vault en cloud para esta cuenta.');
    }

    final salt = base64Decode(header['salt_b64'] as String);
    final verifier = base64Decode(header['verifier_b64'] as String);
    final cipherDEKWithKEK = base64Decode(header['cipher_dek_b64'] as String);
    final ciphertextKEM = base64Decode(header['ciphertext_kem_b64'] as String);
    final privateKeyEnc = base64Decode(header['private_key_enc_b64'] as String);

    final kek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);

    try {
      final decryptedVerifier = await _crypto.decryptWithKEK(cipherText: verifier, kek: kek);
      final verifierStr = utf8.decode(decryptedVerifier);
      if (verifierStr != 'VAULT_VERIFIER_TOKEN') {
        throw Exception('Clave incorrecta');
      }
    } catch (_) {
      throw Exception('Clave maestra incorrecta.');
    }

    final privateKey = await _crypto.decryptWithKEK(cipherText: privateKeyEnc, kek: kek);

    final wrappedDEK = await _crypto.decryptWithKEK(cipherText: cipherDEKWithKEK, kek: kek);

    final dek = await _crypto.unwrapDEKPostQuantum(
      cipherDEK: wrappedDEK,
      ciphertextKEM: ciphertextKEM,
      privateKey: Uint8List.fromList(privateKey),
      kemName: 'ML-KEM-768',
    );

    return dek;
  }

  Future<Map<String, dynamic>> _encryptEntryForCloud({
    required VaultEntry entry,
    required SecretKey dek,
  }) async {

    final payload = <String, dynamic>{
      'local_id': entry.id,
      'title': entry.title,
      'username': entry.username,
      'url': entry.url,
      'requireMasterPassword': entry.requireMasterPassword,
      'breached': entry.breached,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
      'passwordCipher_b64': base64Encode(entry.passwordCipher),
      'passwordNonce_b64': base64Encode(entry.passwordNonce),
      'passwordMac_b64': base64Encode(entry.passwordMac),
      'pwnedCount': entry.pwnedCount,
      'lastPwnedCheck': entry.lastPwnedCheck?.toUtc().toIso8601String(),
      'lastBreachCheck': entry.lastBreachCheck?.toUtc().toIso8601String(),
    };

    final plain = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final box = await _crypto.encrypt(plain: plain, key: dek);

    return {
      'blob_cipher_b64': base64Encode(box.cipherText),
      'blob_nonce_b64': base64Encode(box.nonce),
      'blob_mac_b64': base64Encode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _decryptEntryFromCloud({
    required Map<String, dynamic> row,
    required SecretKey dek,
  }) async {
    final cipher = base64Decode(row['blob_cipher_b64'] as String);
    final nonce = base64Decode(row['blob_nonce_b64'] as String);
    final mac = base64Decode(row['blob_mac_b64'] as String);

    final box = SecretBox(
      cipher,
      nonce: nonce,
      mac: Mac(mac),
    );

    final plainBytes = await _crypto.decrypt(box: box, key: dek);
    return jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
  }

  Future<int> _upsertLocalFromCloud({
    required String cloudEntryId,
    required Map<String, dynamic> data,
    required DateTime? cloudUpdatedAt,
  }) async {

    final mapRaw = await _storage.readString('cloud_id_map_v1');
    final map = (mapRaw == null || mapRaw.isEmpty)
        ? <String, dynamic>{}
        : (jsonDecode(mapRaw) as Map<String, dynamic>);

    int? localId;
    for (final entry in map.entries) {
      if (entry.value.toString() == cloudEntryId) {
        localId = int.tryParse(entry.key);
        break;
      }
    }

    final title = (data['title'] ?? '').toString();
    final username = (data['username'] as String?) ?? '';
    final url = data['url'] as String?;

    final passwordCipher = base64Decode(data['passwordCipher_b64'] as String);
    final passwordNonce = base64Decode(data['passwordNonce_b64'] as String);
    final passwordMac = base64Decode(data['passwordMac_b64'] as String);

    final requireMaster = (data['requireMasterPassword'] as bool?) ?? false;
    final breached = (data['breached'] as bool?) ?? false;

    if (localId == null) {
      final insertedId = await _db.into(_db.vaultEntries).insert(
        VaultEntriesCompanion.insert(
          title: title,
          username: Value(username.isEmpty ? null : username),
          url: Value(url),
          passwordCipher: Uint8List.fromList(passwordCipher),
          passwordNonce: Uint8List.fromList(passwordNonce),
          passwordMac: Uint8List.fromList(passwordMac),
          requireMasterPassword: Value(requireMaster),
          breached: Value(breached),
          pwnedCount: Value(data['pwnedCount'] as int?),
          lastPwnedCheck: Value(_parseDate(data['lastPwnedCheck'])),
          lastBreachCheck: Value(_parseDate(data['lastBreachCheck'])),
          createdAt: Value(_parseDate(data['createdAt']) ?? DateTime.now()),
          updatedAt: Value(_parseDate(data['updatedAt']) ?? DateTime.now()),
        ),
      );
      await _idMap.setCloudIdForLocal(insertedId, cloudEntryId);
      return 1;
    }

    final localRow = await (_db.select(_db.vaultEntries)..where((t) => t.id.equals(localId!))).getSingleOrNull();
    if (localRow == null) {
      final insertedId = await _db.into(_db.vaultEntries).insert(
        VaultEntriesCompanion.insert(
          title: title,
          username: Value(username.isEmpty ? null : username),
          url: Value(url),
          passwordCipher: Uint8List.fromList(passwordCipher),
          passwordNonce: Uint8List.fromList(passwordNonce),
          passwordMac: Uint8List.fromList(passwordMac),
          requireMasterPassword: Value(requireMaster),
          breached: Value(breached),
        ),
      );
      await _idMap.setCloudIdForLocal(insertedId, cloudEntryId);
      return 1;
    }

    final localUpdated = localRow.updatedAt;
    if (cloudUpdatedAt != null && cloudUpdatedAt.isAfter(localUpdated.toUtc())) {
      await (_db.update(_db.vaultEntries)..where((t) => t.id.equals(localId!))).write(
        VaultEntriesCompanion(
          title: Value(title),
          username: Value(username.isEmpty ? null : username),
          url: Value(url),
          passwordCipher: Value(Uint8List.fromList(passwordCipher)),
          passwordNonce: Value(Uint8List.fromList(passwordNonce)),
          passwordMac: Value(Uint8List.fromList(passwordMac)),
          requireMasterPassword: Value(requireMaster),
          breached: Value(breached),
          pwnedCount: Value(data['pwnedCount'] as int?),
          lastPwnedCheck: Value(_parseDate(data['lastPwnedCheck'])),
          lastBreachCheck: Value(_parseDate(data['lastBreachCheck'])),
          updatedAt: Value(_parseDate(data['updatedAt']) ?? DateTime.now()),
        ),
      );
      return 1;
    }

    return 0;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
