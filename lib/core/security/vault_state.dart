import 'package:cryptography/cryptography.dart';

class VaultState {
  VaultState._(this.dek);

  final SecretKey dek;

  static VaultState? _instance;
  static VaultState? get instance => _instance;

  static void set(SecretKey dek) {
    _instance = VaultState._(dek);
  }

  static void clear() {
    _instance = null;
  }

  static bool get isUnlocked => _instance != null;
}