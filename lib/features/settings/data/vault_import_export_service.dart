import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../../../core/security/crypto_service.dart';
import '../../../core/security/kdf_service.dart';
import '../../../core/security/vault_state.dart';
import '../../vault/data/vault_repository.dart';

class VaultImportExportService {
  VaultImportExportService(this._repo);

  final VaultRepository _repo;
  final _crypto = CryptoService();
  final _kdf = KdfService();

  Future<Uint8List> getExportBytes({
    required String masterPassword,
  }) async {
    final dek = VaultState.instance?.dek;
    if (dek == null) throw Exception('Vault bloqueado');

    final entries = await _repo.listEntries();
    final List<Map<String, dynamic>> exportData = [];

    for (final e in entries) {
      final plainPassword = await _repo.decryptPassword(e.id, dek);
      exportData.add({
        'title': e.title,
        'username': e.username,
        'password': plainPassword,
        'url': e.url,
        'requireMasterPassword': e.requireMasterPassword,
      });
    }

    final jsonBytes = utf8.encode(jsonEncode(exportData));

    final salt = Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    final backupKek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);

    final encryptedBundle = await _crypto.encryptWithKEK(
      plain: Uint8List.fromList(jsonBytes),
      kek: backupKek,
    );

    final builder = BytesBuilder();
    builder.add(salt);
    builder.add(encryptedBundle);

    return builder.toBytes();
  }

  Future<int> importVault({
    required String masterPassword,
    required Uint8List fileBytes,
  }) async {
    final dek = VaultState.instance?.dek;
    if (dek == null) throw Exception('Vault bloqueado');

    try {
      final salt = fileBytes.sublist(0, 16);
      final bundle = fileBytes.sublist(16);

      final backupKek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);

      final decryptedBytes = await _crypto.decryptWithKEK(
        cipherText: bundle,
        kek: backupKek,
      );

      final List<dynamic> importedList = jsonDecode(utf8.decode(decryptedBytes));
      int importedCount = 0;

      for (final item in importedList) {
        await _repo.addEntry(
          title: item['title'],
          username: item['username'] ?? '',
          password: item['password'],
          url: item['url'],
          requireMasterPassword: item['requireMasterPassword'] ?? false,
          dek: dek,
        );
        importedCount++;
      }

      return importedCount;
    } catch (e) {
      throw Exception('Error al importar: Contraseña incorrecta o archivo dañado');
    }
  }
}
