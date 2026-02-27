import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class KdfService {
  static const int iterations = 300000;

  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  Future<SecretKey> deriveKeyFromMasterPassword({
    required String password,
    required List<int> salt,
  }) async {
    final pwBytes = utf8.encode(password);
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(pwBytes),
      nonce: salt, // en esta lib se usa como salt
    );
  }
}