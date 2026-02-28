import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/vault_repository.dart';

class VaultDetailScreen extends StatefulWidget {
  const VaultDetailScreen({
    super.key,
    required this.repo,
    required this.entry,
  });

  final VaultRepository repo;
  final VaultEntry entry;

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  bool _revealed = false;
  bool _loadingPw = false;
  String? _password; // solo en memoria
  String? _error;

  Timer? _clipboardTimer;

  Future<void> _loadPasswordIfNeeded() async {
    if (_password != null) return;
    setState(() {
      _loadingPw = true;
      _error = null;
    });
    try {
      final pw = await widget.repo.decryptPassword(widget.entry.id);
      if (!mounted) return;
      setState(() => _password = pw);
    } catch (_) {
      setState(() => _error = 'No se pudo descifrar la contraseña.');
    } finally {
      if (mounted) setState(() => _loadingPw = false);
    }
  }

  Future<void> _toggleReveal() async {
    if (!_revealed) {
      await _loadPasswordIfNeeded();
      if (_password == null) return;
    }
    setState(() => _revealed = !_revealed);
  }

  Future<void> _copyToClipboard() async {
    await _loadPasswordIfNeeded();
    final pw = _password;
    if (pw == null) return;

    await Clipboard.setData(ClipboardData(text: pw));

    // Borrado automático del portapapeles a los 30s
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () async {
      final current = await Clipboard.getData('text/plain');
      if (current?.text == pw) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiada. Se borrará del portapapeles en 30s.')),
    );
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    // Limpieza defensiva
    _password = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoRow(label: 'Usuario', value: e.username ?? ''),
            const SizedBox(height: 12),
            if (e.url != null && e.url!.isNotEmpty) _InfoRow(label: 'URL', value: e.url!),
            const SizedBox(height: 20),

            const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _loadingPw
                        ? const Text('Cargando...')
                        : Text(
                      _revealed ? (_password ?? '') : '••••••••••••',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: _revealed ? 'Ocultar' : 'Ver',
                    onPressed: _toggleReveal,
                    icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            const Spacer(),

            FilledButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar contraseña'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}