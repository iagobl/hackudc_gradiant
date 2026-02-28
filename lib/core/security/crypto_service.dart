import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:liboqs/liboqs.dart';
import 'package:flutter/foundation.dart';

class CryptoService {
  final AesGcm _aes = AesGcm.with256bits();

  Future<SecretKey> generateDEK() async {
    return _aes.newSecretKey();
  }

  Future<SecretBox> encrypt({
    required Uint8List plain,
    required SecretKey key,
  }) async {
    final nonce = _aes.newNonce();
    final secretBox = await _aes.encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    return secretBox;
  }

  Future<Uint8List> decrypt({
    required SecretBox box,
    required SecretKey key,
  }) async {
    final bytes = await _aes.decrypt(box, secretKey: key);
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> encryptWithKEK({
    required Uint8List plain,
    required SecretKey kek,
  }) async {
    final secretBox = await encrypt(
      plain: plain,
      key: kek,
    );
    return secretBox.concatenation();
  }

  Future<Uint8List> decryptWithKEK({
    required Uint8List cipherText,
    required SecretKey kek,
  }) async {
    final secretBox = SecretBox.fromConcatenation(
      cipherText,
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final bytes = await decrypt(box: secretBox, key: kek);
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, Uint8List>> wrapDEKPostQuantum({
    required SecretKey dek,
    required String kemName,
  }) async {
    final dekBytes = Uint8List.fromList(await dek.extractBytes());
    return await compute(_wrapDEKIsolated, {
      'dekBytes': dekBytes,
      'kemName': kemName,
    });
  }

  Future<SecretKey> unwrapDEKPostQuantum({
    required Uint8List cipherDEK,
    required Uint8List ciphertextKEM,
    required Uint8List privateKey,
    required String kemName,
  }) async {
    final resultBytes = await compute(_unwrapDEKIsolated, {
      'cipherDEK': cipherDEK,
      'ciphertextKEM': ciphertextKEM,
      'privateKey': privateKey,
      'kemName': kemName,
    });
    return SecretKey(resultBytes);
  }
}

Map<String, Uint8List> _wrapDEKIsolated(Map<String, dynamic> args) {
  final Uint8List dekBytes = args['dekBytes'];
  final String kemName = args['kemName'];
  
  KEM? kem;
  try {
    kem = KEM.create(kemName);
    if (kem == null) throw Exception('KEM $kemName no soportado por liboqs');
    
    final keyPair = kem.generateKeyPair();
    final encResult = kem.encapsulate(keyPair.publicKey);

    final cipherDEK = Uint8List(dekBytes.length);
    for (int i = 0; i < dekBytes.length; i++) {
      cipherDEK[i] = dekBytes[i] ^ encResult.sharedSecret[i % encResult.sharedSecret.length];
    }

    return {
      'cipherDEK': cipherDEK,
      'ciphertextKEM': encResult.ciphertext,
      'publicKey': keyPair.publicKey,
      'privateKey': keyPair.secretKey,
    };
  } catch (e) {
    rethrow;
  } finally {
    kem?.dispose();
  }
}

Uint8List _unwrapDEKIsolated(Map<String, dynamic> args) {
  final Uint8List cipherDEK = args['cipherDEK'];
  final Uint8List ciphertextKEM = args['ciphertextKEM'];
  final Uint8List privateKey = args['privateKey'];
  final String kemName = args['kemName'];

  KEM? kem;
  try {
    kem = KEM.create(kemName);
    if (kem == null) throw Exception('KEM $kemName no soportado por liboqs');
    
    final sharedSecret = kem.decapsulate(ciphertextKEM, privateKey);

    final dekBytes = Uint8List(cipherDEK.length);
    for (int i = 0; i < cipherDEK.length; i++) {
      dekBytes[i] = cipherDEK[i] ^ sharedSecret[i % sharedSecret.length];
    }
    return dekBytes;
  } catch (e) {
    rethrow;
  } finally {
    kem?.dispose();
  }
}
