import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/generator_controller.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  late final GeneratorController _c;

  @override
  void initState() {
    super.initState();
    _c = GeneratorController();
    _c.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_c.generated.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _c.generated));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = _c.strengthScore;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Generar contraseña',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _c.generated.isEmpty ? 'Pulsa "Generar"' : _c.generated,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _c.generated.isEmpty ? null : _copy,
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
                        Text(_c.strengthLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Longitud: ${_c.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _c.length.toDouble(),
                      min: 8,
                      max: 64,
                      divisions: 56,
                      label: '${_c.length}',
                      onChanged: (v) => _c.setLength(v.round()),
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      value: _c.upper,
                      onChanged: _c.setUpper,
                      title: const Text('Incluir mayúsculas'),
                    ),
                    SwitchListTile(
                      value: _c.lower,
                      onChanged: _c.setLower,
                      title: const Text('Incluir minúsculas'),
                    ),
                    SwitchListTile(
                      value: _c.digits,
                      onChanged: _c.setDigits,
                      title: const Text('Incluir números'),
                    ),
                    SwitchListTile(
                      value: _c.symbols,
                      onChanged: _c.setSymbols,
                      title: const Text('Incluir símbolos'),
                    ),
                    SwitchListTile(
                      value: _c.avoidAmbiguous,
                      onChanged: _c.setAvoidAmbiguous,
                      title: const Text('Evitar caracteres confusos'),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Requisitos mínimos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    _MinSelector(
                      label: 'Mínimo números',
                      value: _c.minDigits,
                      enabled: _c.digits,
                      onMinus: _c.decMinDigits,
                      onPlus: _c.incMinDigits,
                    ),

                    _MinSelector(
                      label: 'Mínimo símbolos',
                      value: _c.minSymbols,
                      enabled: _c.symbols,
                      onMinus: _c.decMinSymbols,
                      onPlus: _c.incMinSymbols,
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _c.generate,
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
    this.enabled = true,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: enabled ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: enabled ? onPlus : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}