import 'package:cryptography/cryptography.dart';

class VaultState {
  VaultState._(this.dek);

  final SecretKey dek;

  static VaultState? _instance;

  static VaultState? get instance => _instance;

  static SecretKey? get key => _instance?.dek;

  static bool get isUnlocked => _instance != null;

  static void set(SecretKey dek) {
    _instance = VaultState._(dek);
  }

  static void clear() {
    _instance = null;
  }
}