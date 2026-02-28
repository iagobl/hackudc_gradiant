import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:liboqs/liboqs.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' show sha256;

class CryptoService {
  final AesGcm _aes = AesGcm.with256bits();
  final _rng = Random.secure();

  /// Genera bytes altamente aleatorios mezclando múltiples fuentes de entropía
  /// para evitar la vulnerabilidad de "semilla conocida".
  Uint8List getRandomBytes(int length) {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      // Mezclamos:
      // 1. Random.secure() del SO
      // 2. Microsegundos actuales (ruido temporal de alta resolución)
      // 3. Un contador para asegurar que cada byte sea distinto incluso en el mismo microsegundo
      final timePart = DateTime.now().microsecondsSinceEpoch;
      final osPart = _rng.nextInt(1 << 32);
      
      // Pasamos por SHA-256 para "blanquear" la entropía y eliminar sesgos
      final mixed = sha256.convert(utf8.encode('$timePart-$osPart-$i'));
      
      // Tomamos un byte del hash y lo mezclamos con otro valor del SO
      result[i] = mixed.bytes[0] ^ _rng.nextInt(256);
    }
    return result;
  }

  /// Genera un entero aleatorio entre 0 y max-1 usando entropía endurecida
  int nextInt(int max) {
    if (max <= 0) return 0;
    // Usamos 4 bytes para obtener un entero de 32 bits y aplicamos el módulo
    final bytes = getRandomBytes(4);
    final view = ByteData.sublistView(bytes);
    return view.getUint32(0) % max;
  }

  /// Genera la DEK usando el nuevo generador endurecido
  Future<SecretKey> generateDEK() async {
    final bytes = getRandomBytes(32);
    return SecretKey(bytes);
  }

  /// Cifra datos con AES-GCM
  Future<SecretBox> encrypt({
    required Uint8List plain,
    required SecretKey key,
  }) async {
    final nonce = getRandomBytes(12); // Nonce de 96 bits recomendado para GCM
    final secretBox = await _aes.encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    return secretBox;
  }

  /// Descifra datos con AES-GCM
  Future<Uint8List> decrypt({
    required SecretBox box,
    required SecretKey key,
  }) async {
    final bytes = await _aes.decrypt(box, secretKey: key);
    return Uint8List.fromList(bytes);
  }

  /// Cifra bytes con una KEK (Key Encryption Key) usando AES-GCM
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

  /// Descifra bytes con una KEK (Key Encryption Key) usando AES-GCM
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

  /// ENVOLVER DEK con KEM post-cuántico (Ejecutado en un Isolate para evitar bloqueos)
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

  /// DESENVOLVER DEK con KEM post-cuántico (Ejecutado en un Isolate para evitar bloqueos)
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
