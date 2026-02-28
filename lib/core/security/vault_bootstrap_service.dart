import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/secure_storage_service.dart';
import 'crypto_service.dart';
import 'kdf_service.dart';
import 'vault_state.dart';
import 'package:biometric_storage/biometric_storage.dart';

class VaultBootstrapService {
  VaultBootstrapService(this._storage);

  final SecureStorageService _storage;
  final CryptoService _crypto = CryptoService();
  final KdfService _kdf = KdfService();

  static const _kSalt = 'vault_salt_b64';
  static const _kVerifier = 'vault_verifier_b64';
  static const _kCipherDEK = 'vault_cipherDEK_b64';
  static const _kCiphertextKEM = 'vault_ciphertextKEM_b64';
  static const _kPrivateKey = 'vault_privateKey_b64';
  static const _kPublicKey = 'vault_publicKey_b64';
  static const _kIters = 'kdf_iters';
  static const _kWrappedVaultKey = 'vault_key_wrapped_b64';
  static const _kWrappedVaultKeyNonce = 'vault_key_wrapped_nonce_b64';
  static const _kBioVaultKey = 'bio_vault_key_b64';

  Future<bool> isBiometricsAvailable() async {
    final can = await BiometricStorage().canAuthenticate();
    return can == CanAuthenticateResponse.success;
  }

  static const _verifierSecret = 'VAULT_VERIFIER_TOKEN';

  Future<void> enableBiometrics() async {
    final key = VaultState.key;
    if (key == null) {
      throw StateError('Vault debe estar desbloqueado para activar biometría');
    }

    final bytes = await key.extractBytes();
    final b64 = base64Encode(bytes);

    final storage = await BiometricStorage().getStorage(
      _kBioVaultKey,
      options:  StorageFileInitOptions(
        authenticationRequired: true,
      ),
    );

    await storage.write(b64);
  }

  Future<void> unlockVaultWithBiometrics() async {
    final storage = await BiometricStorage().getStorage(
      _kBioVaultKey,
      options:  StorageFileInitOptions(
        authenticationRequired: true,
      ),
    );

    final b64 = await storage.read();
    if (b64 == null) {
      throw StateError('Biometría no configurada');
    }

    final bytes = base64Decode(b64);
    VaultState.set(SecretKey(bytes));
  }

  Future<bool> isBiometricsEnabled() async {
    final storage = await BiometricStorage().getStorage(
      _kBioVaultKey,
      options: StorageFileInitOptions(authenticationRequired: true),
    );
    final v = await storage.read();
    return v != null;
  }

  Future<void> createVault({required String masterPassword}) async {
    final salt = Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    final kek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);
    final dek = await _crypto.generateDEK();
    final pqcResult = await _crypto.wrapDEKPostQuantum(
      dek: dek,
      kemName: 'ML-KEM-768',
    );

    final cipherDEKWithKEK = await _crypto.encryptWithKEK(
      plain: pqcResult['cipherDEK']!,
      kek: kek,
    );

    final verifier = await _crypto.encryptWithKEK(
      plain: Uint8List.fromList(utf8.encode(_verifierSecret)),
      kek: kek,
    );

    await _storage.writeString(_kSalt, base64Encode(salt));
    await _storage.writeString(_kVerifier, base64Encode(verifier));
    await _storage.writeString(_kCipherDEK, base64Encode(cipherDEKWithKEK));
    await _storage.writeString(_kCiphertextKEM, base64Encode(pqcResult['ciphertextKEM']!));
    await _storage.writeString(_kPrivateKey, base64Encode(pqcResult['privateKey']!));
    await _storage.writeString(_kPublicKey, base64Encode(pqcResult['publicKey']!));

    VaultState.set(dek);
  }

  Future<void> unlockVault({required String masterPassword}) async {
    final saltStr = await _storage.readString(_kSalt);
    final verifierStr = await _storage.readString(_kVerifier);
    final cipherDEKStr = await _storage.readString(_kCipherDEK);
    final ciphertextKEMStr = await _storage.readString(_kCiphertextKEM);
    final privateKeyStr = await _storage.readString(_kPrivateKey);

    if (saltStr == null || verifierStr == null || cipherDEKStr == null ||
        ciphertextKEMStr == null || privateKeyStr == null) {
      throw Exception('Vault not initialized or data missing');
    }

    final salt = base64Decode(saltStr);
    final verifier = base64Decode(verifierStr);
    final cipherDEKWithKEK = base64Decode(cipherDEKStr);
    final ciphertextKEM = base64Decode(ciphertextKEMStr);
    final privateKey = base64Decode(privateKeyStr);

    final kek = await _kdf.deriveKEK(masterPassword: masterPassword, salt: salt);

    try {
      final decryptedVerifier = await _crypto.decryptWithKEK(
        cipherText: verifier,
        kek: kek,
      );
      if (utf8.decode(decryptedVerifier) != _verifierSecret) {
        throw Exception('Clave incorrecta');
      }
    } catch (e) {
      throw Exception('Clave incorrecta o error de integridad');
    }

    final wrappedDEK = await _crypto.decryptWithKEK(
      cipherText: cipherDEKWithKEK,
      kek: kek,
    );

    final dek = await _crypto.unwrapDEKPostQuantum(
      cipherDEK: wrappedDEK,
      ciphertextKEM: ciphertextKEM,
      privateKey: privateKey,
      kemName: 'ML-KEM-768',
    );

    VaultState.set(dek);
  }

  Future<void> lockVault() async {
    VaultState.clear();
  }

  Future<bool> isVaultInitialized() async {
    final salt = await _storage.readString(_kSalt);
    final verifier = await _storage.readString(_kVerifier);
    final cipherDEK = await _storage.readString(_kCipherDEK);
    final ciphertextKEM = await _storage.readString(_kCiphertextKEM);
    final privKey = await _storage.readString(_kPrivateKey);

    return salt != null &&
           verifier != null &&
           cipherDEK != null &&
           ciphertextKEM != null &&
           privKey != null;
  }
}
