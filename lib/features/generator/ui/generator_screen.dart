import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/security/crypto_service.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _crypto = CryptoService();

  int _length = 16;
  bool _lower = true;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  bool _avoidAmbiguous = true;
  int _minDigits = 1;
  int _minSymbols = 1;

  String _generated = '';

  static const _lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const _upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digitChars = '0123456789';
  static const _symbolChars = r'!@#$%^&*()-_=+[]{};:,.<>?';

  static const _ambiguous = 'O0Il1';

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

    final totalMin = _minDigits + _minSymbols;
    final length = _length < totalMin ? totalMin : _length;

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

    while (chars.length < length) {
      chars.add(alphabet[_crypto.nextInt(alphabet.length)]);
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

  Future<void> _copy() async {
    if (_generated.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generated));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = _generated.isEmpty ? 0 : _strengthScore(_generated);

    return Scaffold(
      appBar: AppBar(title: const Text('Generar contraseña')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _generated.isEmpty ? 'Pulsa "Generar"' : _generated,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                          IconButton(
                            onPressed: _generated.isEmpty ? null : _copy,
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copiar',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: score / 100,
                            color: score < 40 ? Colors.red : (score < 70 ? Colors.orange : Colors.green),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_strengthLabel(score), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Longitud: $_length',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _length.toDouble(),
                      min: 8,
                      max: 64,
                      divisions: 56,
                      label: '$_length',
                      onChanged: (v) => setState(() => _length = v.round()),
                    ),

                    const SizedBox(height: 8),

                    SwitchListTile(
                      value: _upper,
                      onChanged: (v) => setState(() => _upper = v),
                      title: const Text('Incluir mayúsculas'),
                    ),
                    SwitchListTile(
                      value: _lower,
                      onChanged: (v) => setState(() => _lower = v),
                      title: const Text('Incluir minúsculas'),
                    ),
                    SwitchListTile(
                      value: _digits,
                      onChanged: (v) => setState(() => _digits = v),
                      title: const Text('Incluir números'),
                    ),
                    SwitchListTile(
                      value: _symbols,
                      onChanged: (v) => setState(() => _symbols = v),
                      title: const Text('Incluir símbolos'),
                    ),
                    SwitchListTile(
                      value: _avoidAmbiguous,
                      onChanged: (v) => setState(() => _avoidAmbiguous = v),
                      title: const Text('Evitar caracteres confusos'),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Requisitos mínimos',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    _MinSelector(
                      label: 'Mínimo números',
                      value: _minDigits,
                      onMinus: () => setState(
                            () => _minDigits = (_minDigits > 0) ? _minDigits - 1 : 0,
                      ),
                      onPlus: () => setState(() => _minDigits++),
                    ),

                    _MinSelector(
                      label: 'Mínimo símbolos',
                      value: _minSymbols,
                      onMinus: () => setState(
                            () => _minSymbols = (_minSymbols > 0) ? _minSymbols - 1 : 0,
                      ),
                      onPlus: () => setState(() => _minSymbols++),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => setState(() => _generated = _generate()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Generar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinSelector extends StatelessWidget {
  const _MinSelector({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(value.toString(), style: const TextStyle(fontSize: 16)),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
