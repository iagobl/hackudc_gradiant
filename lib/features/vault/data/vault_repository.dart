import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../../core/security/crypto_service.dart';
import '../../../core/security/vault_state.dart';
import '../../../core/storage/app_database.dart';
import 'package:drift/drift.dart';
import 'dart:typed_data';

class VaultRepository {
  VaultRepository(this._db);

  final AppDatabase _db;
  final CryptoService _crypto = CryptoService();

  SecretKey _requireVaultKey() {
    final state = VaultState.instance;
    if (state == null) throw StateError('Vault bloqueado.');
    return state.vaultKey;
  }

  Future<List<VaultEntry>> listEntries() async {
    final rows = await (_db.select(_db.vaultEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    return rows
        .map((r) => VaultEntry(
              id: r.id,
              title: r.title,
              username: r.username,
              url: r.url,
              breached: r.breached,
            ))
        .toList();
  }

  Future<void> addEntry({
    required String title,
    required String username,
    required String password,
    String? url,
  }) async {
    final key = _requireVaultKey();

    final plain = utf8.encode(password);
    final enc = await _crypto.encrypt(plain: plain, key: key);

    await _db.into(_db.vaultEntries).insert(
          VaultEntriesCompanion.insert(
            title: title,
            username: Value(username),
            url: Value(url),
            passwordCipher: Uint8List.fromList(enc.cipherText),
            passwordNonce: Uint8List.fromList(enc.nonce),
          ),
        );
  }

  Future<String> decryptPassword(int entryId) async {
    final key = _requireVaultKey();
    final row = await (_db.select(_db.vaultEntries)
          ..where((t) => t.id.equals(entryId)))
        .getSingle();

    final plainBytes = await _crypto.decrypt(
      cipherTextWithTag: row.passwordCipher,
      nonce: row.passwordNonce,
      key: key,
    );

    return utf8.decode(plainBytes);
  }

  Stream<List<VaultEntry>> watchEntries() {
    final query = (_db.select(_db.vaultEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();

    return query.map(
          (rows) => rows
          .map((r) => VaultEntry(
        id: r.id,
        title: r.title,
        username: r.username,
        url: r.url,
        breached: r.breached,
      ))
          .toList(),
    );
  }
}

class VaultEntry {
  final int id;
  final String title;
  final String? username;
  final String? url;
  final bool breached;

  VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.url,
    required this.breached,
  });
}