import 'dart:math';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final Cipher _cipher = AesGcm.with256bits();
  final Random _rng = Random.secure();

  List<int> randomBytes(int length) =>
      List<int>.generate(length, (_) => _rng.nextInt(256));

  Future<({List<int> cipherText, List<int> nonce})> encrypt({
    required List<int> plain,
    required SecretKey key,
  }) async {
    final nonce = randomBytes(12);
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    return (cipherText: box.concatenation(), nonce: box.nonce);
  }

  Future<List<int>> decrypt({
    required List<int> cipherTextWithTag,
    required List<int> nonce,
    required SecretKey key,
  }) async {
    final parsed = SecretBox.fromConcatenation(
      cipherTextWithTag,
      nonceLength: 12,
      macLength: 16,
    );
    final box = SecretBox(
      parsed.cipherText,
      nonce: nonce,
      mac: parsed.mac,
    );
    return _cipher.decrypt(box, secretKey: key);
  }
}