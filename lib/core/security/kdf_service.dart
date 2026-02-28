import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class KdfService {
  static final Argon2id _argon2 = Argon2id(
    memory: 32768,
    iterations: 3,
    parallelism: 1,
    hashLength: 32,
  );

  Future<SecretKey> deriveKEK({
    required String masterPassword,
    required Uint8List salt,
  }) async {
    final passwordBytes = utf8.encode(masterPassword.trim());
    
    return _argon2.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: salt,
    );
  }
}