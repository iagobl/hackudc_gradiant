import 'package:cryptography/cryptography.dart';

class VaultState {
  VaultState._(this.vaultKey);

  final SecretKey vaultKey;

  static VaultState? _instance;

  static VaultState? get instance => _instance;

  static void set(SecretKey key) {
    _instance = VaultState._(key);
  }

  static void clear() {
    _instance = null;
  }
}