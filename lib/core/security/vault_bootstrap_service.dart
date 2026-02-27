import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../storage/secure_storage_service.dart';
import 'crypto_service.dart';
import 'kdf_service.dart';
import 'vault_state.dart';

class VaultBootstrapService {
  VaultBootstrapService(this._storage);

  final SecureStorageService _storage;
  final CryptoService _crypto = CryptoService();
  final KdfService _kdf = KdfService();

  static const _kSalt = 'kdf_salt_b64';
  static const _kIters = 'kdf_iters';
  static const _kWrappedVaultKey = 'vault_key_wrapped_b64';
  static const _kWrappedVaultKeyNonce = 'vault_key_wrapped_nonce_b64';

  Future<bool> isVaultInitialized() async {
    final salt = await _storage.readString(_kSalt);
    final wrapped = await _storage.readString(_kWrappedVaultKey);
    final nonce = await _storage.readString(_kWrappedVaultKeyNonce);
    return salt != null && wrapped != null && nonce != null;
  }

  /// Crea el vault:
  /// - salt aleatorio
  /// - deriva pinKey con PBKDF2(masterPassword, salt)
  /// - genera vaultKey aleatoria (32 bytes)
  /// - envuelve vaultKey con AES-GCM usando pinKey
  /// - guarda en Keystore (secure storage)
  Future<void> createVault({required String masterPassword}) async {
    final salt = _crypto.randomBytes(16);

    final pinKey = await _kdf.deriveKeyFromMasterPassword(
      password: masterPassword,
      salt: salt,
    );

    final vaultKeyBytes = _crypto.randomBytes(32);
    final wrapped = await _crypto.encrypt(plain: vaultKeyBytes, key: pinKey);

    await _storage.writeString(_kSalt, base64Encode(salt));
    await _storage.writeString(_kIters, KdfService.iterations.toString());
    await _storage.writeString(_kWrappedVaultKey, base64Encode(wrapped.cipherText));
    await _storage.writeString(_kWrappedVaultKeyNonce, base64Encode(wrapped.nonce));

    // Guardamos la vaultKey en memoria para sesión actual (ya desbloqueado)
    VaultState.set(SecretKey(vaultKeyBytes));
  }

  /// Desbloquear vault con masterPassword (lo usaremos en LockScreen luego)
  Future<void> unlockVault({required String masterPassword}) async {
    final saltB64 = await _storage.readString(_kSalt);
    final wrappedB64 = await _storage.readString(_kWrappedVaultKey);
    final nonceB64 = await _storage.readString(_kWrappedVaultKeyNonce);

    if (saltB64 == null || wrappedB64 == null || nonceB64 == null) {
      throw StateError('Vault no inicializado');
    }

    final salt = base64Decode(saltB64);
    final wrapped = base64Decode(wrappedB64);
    final nonce = base64Decode(nonceB64);

    final pinKey = await _kdf.deriveKeyFromMasterPassword(
      password: masterPassword,
      salt: salt,
    );

    final vaultKeyBytes = await _crypto.decrypt(
      cipherTextWithTag: wrapped,
      nonce: nonce,
      key: pinKey,
    );

    VaultState.set(SecretKey(vaultKeyBytes));
  }

  Future<void> lockVault() async {
    VaultState.clear();
  }
}