import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../../core/security/crypto_service.dart';
import '../../../core/storage/app_database.dart';
import 'package:drift/drift.dart';

class VaultRepository {
  VaultRepository(this._db);

  final AppDatabase _db;
  final CryptoService _crypto = CryptoService();

  Future<List<VaultEntry>> listEntries() async {
    final rows = await (_db.select(_db.vaultEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    return rows;
  }

  Future<void> addEntry({
    required String title,
    required String username,
    required String password,
    String? url,
    required SecretKey dek, 
    int? pwnedCount,
    bool requireMasterPassword = false,
  }) async {
    final plain = Uint8List.fromList(utf8.encode(password));
    final enc = await _crypto.encrypt(plain: plain, key: dek);

    await _db.into(_db.vaultEntries).insert(
      VaultEntriesCompanion.insert(
        title: title,
        username: Value(username),
        url: Value(url),
        passwordCipher: Uint8List.fromList(enc.cipherText),
        passwordNonce: Uint8List.fromList(enc.nonce),
        passwordMac: Uint8List.fromList(enc.mac.bytes),
        requireMasterPassword: Value(requireMasterPassword),
        breached: Value((pwnedCount ?? 0) > 0),
        pwnedCount: Value(pwnedCount),
        lastPwnedCheck: Value(pwnedCount == null ? null : DateTime.now()),
      ),
    );
  }

  Future<String> decryptPassword(int entryId, SecretKey dek) async {
    final row = await (_db.select(_db.vaultEntries)
      ..where((t) => t.id.equals(entryId)))
        .getSingle();

    final box = SecretBox(
      row.passwordCipher,
      nonce: row.passwordNonce,
      mac: Mac(row.passwordMac),
    );

    final plainBytes = await _crypto.decrypt(box: box, key: dek);
    return utf8.decode(plainBytes);
  }

  Future<void> setPwnedResult({
    required int entryId,
    required int pwnedCount,
  }) async {
    await (_db.update(_db.vaultEntries)..where((t) => t.id.equals(entryId))).write(
      VaultEntriesCompanion(
        pwnedCount: Value(pwnedCount),
        lastPwnedCheck: Value(DateTime.now()),
        breached: Value(pwnedCount > 0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<VaultEntry>> watchEntries() {
    return (_db.select(_db.vaultEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }
}
