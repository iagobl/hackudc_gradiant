import 'package:flutter/material.dart';
import '../../../core/security/vault_state.dart';
import '../data/vault_repository.dart';
import '../../../core/security/pwned_passwords_service.dart';

class VaultAddScreen extends StatefulWidget {
  const VaultAddScreen({super.key, required this.repo});

  final VaultRepository repo;

  @override
  State<VaultAddScreen> createState() => _VaultAddScreenState();
}

class _VaultAddScreenState extends State<VaultAddScreen> {
  final _title = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _url = TextEditingController();

  final _titleFocus = FocusNode();
  final _userFocus = FocusNode();
  final _urlFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  bool _requireMasterPassword = false;

  bool _checking = false;
  int? _pwnedCount;

  late final PwnedPasswordsService _pwned = PwnedPasswordsService();

  Future<void> _showCenterMessage({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPwned() async {
    if (_busy || _checking) return;

    setState(() => _checking = true);
    try {
      final pw = _pass.text;
      if (pw.isEmpty) {
        await _showCenterMessage(
          title: 'Falta la contraseña',
          message: 'Introduce una contraseña primero para comprobarla.',
          isError: true,
        );
        return;
      }

      final count = await _pwned.getPwnCount(pw);
      if (!mounted) return;

      setState(() => _pwnedCount = count);

      await _showCenterMessage(
        title: count > 0 ? 'Contraseña comprometida' : 'Contraseña no encontrada',
        message: count > 0
            ? 'Se ha visto $count veces en filtraciones.\n\nRecomendación: genera una nueva y cámbiala.'
            : 'No aparece en filtraciones conocidas.',
        isError: count > 0,
      );
    } catch (e) {
      await _showCenterMessage(
        title: 'No se pudo comprobar',
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final title = _title.text.trim();
      final user = _user.text.trim();
      final pw = _pass.text;
      final url = _url.text.trim().isEmpty ? null : _url.text.trim();

      if (title.isEmpty) throw Exception('Introduce un nombre (ej: Google).');
      if (user.isEmpty) throw Exception('Introduce el usuario/email.');
      if (pw.isEmpty) throw Exception('Introduce la contraseña.');

      final dek = VaultState.instance?.dek;
      if (dek == null) throw Exception('Vault bloqueado.');

      await widget.repo.addEntry(
        title: title,
        username: user,
        password: pw,
        url: url,
        pwnedCount: _pwnedCount,
        dek: dek,
        requireMasterPassword: _requireMasterPassword,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      await _showCenterMessage(
        title: 'No se pudo guardar',
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _user.dispose();
    _pass.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bigButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Añadir contraseña')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _userFocus.requestFocus(),
                      decoration: const InputDecoration(labelText: 'Servicio (ej: Google)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      focusNode: _userFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _urlFocus.requestFocus(),
                      decoration: const InputDecoration(labelText: 'Usuario / Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _url,
                      focusNode: _urlFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passFocus.requestFocus(),
                      decoration: const InputDecoration(labelText: 'URL (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      focusNode: _passFocus,
                      textInputAction: TextInputAction.done,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        suffixIcon: IconButton(
                          onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Requerir clave maestra para ver'),
                      subtitle: const Text('Se pedirá la contraseña cada vez que intentes revelar esta entrada'),
                      value: _requireMasterPassword,
                      onChanged: (v) => setState(() => _requireMasterPassword = v),
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: _busy || _checking ? null : _checkPwned,
                      icon: _checking
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.security),
                      label: const Text('Comprobar filtración'),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: bigButtonStyle,
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Guardar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}