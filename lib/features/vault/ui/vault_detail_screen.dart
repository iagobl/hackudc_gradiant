import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/security/vault_state.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/vault_repository.dart';
import '../../../core/security/pwned_passwords_service.dart';
import '../../../core/storage/app_database.dart';

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
  bool _editing = false;
  bool _revealed = false;
  bool _loadingPw = false;
  String? _password;
  String? _error;
  bool _checking = false;

  final _titleController = TextEditingController();
  final _userController = TextEditingController();
  final _urlController = TextEditingController();
  final _passController = TextEditingController();

  Timer? _clipboardTimer;
  late final PwnedPasswordsService _pwned = PwnedPasswordsService();
  final _bootstrap = VaultBootstrapService(SecureStorageService());

  @override
  void initState() {
    super.initState();
    _initControllers(widget.entry);
  }

  void _initControllers(VaultEntry e) {
    _titleController.text = e.title;
    _userController.text = e.username ?? '';
    _urlController.text = e.url ?? '';
    _passController.clear();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _userController.dispose();
    _urlController.dispose();
    _passController.dispose();
    _clipboardTimer?.cancel();
    _pwned.dispose();
    super.dispose();
  }

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar entrada?', style: TextStyle(fontSize: 18)),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authenticated = await _authenticateWithMasterPassword();
      if (authenticated) {
        await widget.repo.deleteEntry(widget.entry.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada eliminada')));
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    final dek = VaultState.instance?.dek;
    if (dek == null) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El título no puede estar vacío')));
      return;
    }

    final authenticated = await _authenticateWithMasterPassword();
    if (!authenticated) return;

    try {
      await widget.repo.updateEntry(
        id: widget.entry.id,
        title: _titleController.text.trim(),
        username: _userController.text.trim(),
        url: _urlController.text.trim(),
        password: _passController.text.isNotEmpty ? _passController.text : null,
        dek: _passController.text.isNotEmpty ? dek : null,
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _password = null;
          _revealed = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _authenticateWithMasterPassword() async {
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? dialogError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Validación de Seguridad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Clave Maestra',
                      labelStyle: const TextStyle(fontSize: 14),
                      errorText: dialogError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () async {
                    try {
                      await _bootstrap.unlockVault(masterPassword: passwordController.text);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      setDialogState(() => dialogError = 'Clave incorrecta');
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<void> _loadPasswordIfNeeded() async {
    if (_password != null) return;
    if (widget.entry.requireMasterPassword) {
      if (!await _authenticateWithMasterPassword()) return;
    }
    setState(() => _loadingPw = true);
    try {
      final dek = VaultState.instance?.dek;
      if (dek == null) throw 'Vault bloqueado';
      final pw = await widget.repo.decryptPassword(widget.entry.id, dek);
      if (mounted) setState(() => _password = pw);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo descifrar');
    } finally {
      if (mounted) setState(() => _loadingPw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VaultEntry>(
      stream: widget.repo.watchEntry(widget.entry.id),
      initialData: widget.entry,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final e = snapshot.data!;
        final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

        return PopScope(
          canPop: !_editing,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (_editing) setState(() => _editing = false);
          },
          child: Scaffold(
            appBar: AppBar(
              title: _editing ? const Text('Editar entrada') : Text(e.title),
              leading: _editing
                  ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _editing = false))
                  : null,
              actions: [
                if (!_editing) ...[
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _deleteEntry),
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () { _initControllers(e); setState(() => _editing = true); }),
                ] else ...[
                  IconButton(icon: const Icon(Icons.check), onPressed: _saveChanges),
                ]
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editing) ...[
                    TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: _userController, decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva Contraseña', helperText: 'Dejar vacío para mantener la actual', border: OutlineInputBorder())),
                  ] else ...[
                    _InfoRow(label: 'Usuario', value: e.username ?? '-'),
                    const SizedBox(height: 12),
                    if (e.url != null && e.url!.isNotEmpty) _InfoRow(label: 'URL', value: e.url!, isLink: true),
                    const Divider(height: 32),
                    const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: _loadingPw ? const Text('Cargando...') : Text(_revealed ? (_password ?? '') : '••••••••••••', style: const TextStyle(fontSize: 16))),
                          IconButton(onPressed: () async { if (!_revealed) await _loadPasswordIfNeeded(); if (_password != null) setState(() => _revealed = !_revealed); }, icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: () async { await _loadPasswordIfNeeded(); if (_password != null) { await Clipboard.setData(ClipboardData(text: _password!)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiada'))); } }, icon: const Icon(Icons.copy), label: const Text('Copiar contraseña')),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _checking ? null : () async { await _loadPasswordIfNeeded(); if (_password == null) return; setState(() => _checking = true); final count = await _pwned.getPwnCount(_password!); await widget.repo.setPwnedResult(entryId: e.id, pwnedCount: count); if (mounted) { setState(() => _checking = false); showDialog(context: context, builder: (_) => AlertDialog(title: Text(count > 0 ? 'Comprometida' : 'Segura'), content: Text(count > 0 ? 'Aparece $count veces en filtraciones.' : 'No se han encontrado filtraciones.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])); } }, icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.security), label: const Text('Comprobar filtración')),
                    const Divider(height: 48),
                    _buildToggleRow(label: 'Requerir Clave Maestra', value: e.requireMasterPassword, onChanged: (val) => widget.repo.updateRequireMasterPassword(e.id, val)),
                    const SizedBox(height: 24),
                    _MetaDataRow(label: 'Creado', value: dateFormat.format(e.createdAt)),
                    const SizedBox(height: 8),
                    _MetaDataRow(label: 'Modificado', value: dateFormat.format(e.updatedAt)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w500)), Switch(value: value, onChanged: onChanged)]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isLink = false});
  final String label; final String value; final bool isLink;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))), Expanded(child: Text(value, style: TextStyle(color: isLink ? Colors.blue : null, decoration: isLink ? TextDecoration.underline : null)))]);
  }
}

class _MetaDataRow extends StatelessWidget {
  const _MetaDataRow({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) {
    return Row(children: [Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)), Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}
