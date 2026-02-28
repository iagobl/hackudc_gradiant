import 'dart:convert';
import 'package:crypto/crypto.dart' show sha1;
import 'package:http/http.dart' as http;
import 'dart:async';

class PwnedPasswordsService {
  static const _base = 'https://api.pwnedpasswords.com/range/';

  final http.Client _client;
  PwnedPasswordsService({http.Client? client}) : _client = client ?? http.Client();

  Future<int> getPwnCount(String password) async {
    final sha1Hex = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final prefix = sha1Hex.substring(0, 5);
    final suffix = sha1Hex.substring(5);

    final uri = Uri.parse('$_base$prefix');

    try {
      final res = await _client
          .get(uri, headers: {
        'User-Agent': 'hackudc-gradiant-vault',
        'Add-Padding': 'true',
      },)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        throw Exception('Error consultando filtraciones (${res.statusCode})');
      }

      final lines = const LineSplitter().convert(res.body);
      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length != 2) continue;
        if (parts[0].trim().toUpperCase() == suffix) {
          return int.tryParse(parts[1].trim()) ?? 0;
        }
      }
      return 0;
    } on TimeoutException {
        throw Exception('Sin respuesta (timeout). ¿El emulador tiene Internet?');
    } on Exception catch (e) {
        throw Exception('Error de red: $e');
    }


  }

  void dispose() => _client.close();
}