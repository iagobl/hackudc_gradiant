import 'package:flutter/foundation.dart';
import '../../../core/security/crypto_service.dart';

class GeneratorController extends ChangeNotifier {
  GeneratorController() {
  }

  final CryptoService _crypto = CryptoService();

  int _length = 16;
  bool _lower = true;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  bool _avoidAmbiguous = true;
  int _minDigits = 1;
  int _minSymbols = 1;

  String _generated = '';

  int get length => _length;
  bool get lower => _lower;
  bool get upper => _upper;
  bool get digits => _digits;
  bool get symbols => _symbols;
  bool get avoidAmbiguous => _avoidAmbiguous;
  int get minDigits => _minDigits;
  int get minSymbols => _minSymbols;

  String get generated => _generated;

  int get strengthScore => _generated.isEmpty ? 0 : _strengthScore(_generated);
  String get strengthLabel => _strengthLabel(strengthScore);

  static const _lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const _upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digitChars = '0123456789';
  static const _symbolChars = r'!@#$%^&*()-_=+[]{};:,.<>?';

  static const _ambiguous = 'O0Il1';

  void setLength(int value) {
    _length = value;

    while (_minDigits + _minSymbols > _length) {
      if (_minSymbols > 0) {
        _minSymbols--;
      } else if (_minDigits > 0) {
        _minDigits--;
      }
    }

    notifyListeners();
  }

  void setUpper(bool v) {
    _upper = v;
    notifyListeners();
  }

  void setLower(bool v) {
    _lower = v;
    notifyListeners();
  }

  void setDigits(bool v) {
    _digits = v;
    if (!v) _minDigits = 0;
    notifyListeners();
  }

  void setSymbols(bool v) {
    _symbols = v;
    if (!v) _minSymbols = 0;
    notifyListeners();
  }

  void setAvoidAmbiguous(bool v) {
    _avoidAmbiguous = v;
    notifyListeners();
  }

  void decMinDigits() {
    _minDigits = _minDigits > 0 ? _minDigits - 1 : 0;
    notifyListeners();
  }

  void incMinDigits() {
    if (_digits && (_minDigits + _minSymbols < _length)) {
      _minDigits++;
      notifyListeners();
    }
  }

  void decMinSymbols() {
    _minSymbols = _minSymbols > 0 ? _minSymbols - 1 : 0;
    notifyListeners();
  }

  void incMinSymbols() {
    if (_symbols && (_minDigits + _minSymbols < _length)) {
      _minSymbols++;
      notifyListeners();
    }
  }

  void generate() {
    _generated = _generate();
    notifyListeners();
  }

  String _buildAlphabet() {
    var s = '';
    if (_lower) s += _lowerChars;
    if (_upper) s += _upperChars;
    if (_digits) s += _digitChars;
    if (_symbols) s += _symbolChars;

    if (_avoidAmbiguous) {
      s = s.split('').where((c) => !_ambiguous.contains(c)).join();
    }
    return s;
  }

  String _generate() {
    final alphabet = _buildAlphabet();
    if (alphabet.isEmpty) return '';

    final chars = <String>[];

    void addFrom(String source, int count) {
      final filtered = _avoidAmbiguous
          ? source.split('').where((c) => !_ambiguous.contains(c)).join()
          : source;

      for (int i = 0; i < count; i++) {
        if (filtered.isNotEmpty) {
          chars.add(filtered[_crypto.nextInt(filtered.length)]);
        }
      }
    }

    if (_digits) addFrom(_digitChars, _minDigits);
    if (_symbols) addFrom(_symbolChars, _minSymbols);

    while (chars.length < _length) {
      chars.add(alphabet[_crypto.nextInt(alphabet.length)]);
    }

    if (chars.length > _length) {
      chars.removeRange(_length, chars.length);
    }

    for (int i = chars.length - 1; i > 0; i--) {
      int j = _crypto.nextInt(i + 1);
      var temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }

    return chars.join();
  }

  int _strengthScore(String pw) {
    int score = 0;
    if (pw.isEmpty) return 0;
    score += (pw.length >= 8) ? 15 : 0;
    score += (pw.length >= 12) ? 25 : 0;
    score += (pw.length >= 16) ? 25 : 0;
    score += RegExp(r'[a-z]').hasMatch(pw) ? 10 : 0;
    score += RegExp(r'[A-Z]').hasMatch(pw) ? 10 : 0;
    score += RegExp(r'\d').hasMatch(pw) ? 10 : 0;
    score += RegExp(r'[^A-Za-z0-9]').hasMatch(pw) ? 10 : 0;
    if (score > 100) score = 100;
    return score;
  }

  String _strengthLabel(int score) {
    if (score >= 80) return 'Muy fuerte';
    if (score >= 60) return 'Fuerte';
    if (score >= 40) return 'Media';
    return 'Débil';
  }
}