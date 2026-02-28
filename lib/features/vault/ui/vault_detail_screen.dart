import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/app_database.dart'; // ✅ VaultEntry
import '../../../core/security/vault_state.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/security/pwned_passwords_service.dart';
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
  static const Color _accentBlue = Color(0xFF2563EB);

  bool _editing = false;
  bool _revealed = false;
  bool _loadingPw = false;
  bool _checking = false;
  bool _saving = false;

  String? _password;
  String? _error;

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
    super.dispose();
  }

  Widget _block(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest, // gris suave exterior
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _whiteCard(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  InputDecoration _fieldDecoration(
      BuildContext context, {
        required String label,
        Widget? suffix,
        String? helperText,
      }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentBlue, width: 1.6),
      ),
      suffixIcon: suffix,
    );
  }

  Widget _editField(
      BuildContext context, {
        required String label,
        required TextEditingController controller,
        bool obscureText = false,
        String? helperText,
        Widget? suffix,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            helperText: helperText,
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accentBlue, width: 1.6),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _readField({
    required BuildContext context,
    required String label,
    required String value,
    Widget? trailing,
    bool isLink = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? '-' : value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isLink ? _accentBlue : cs.onSurface,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _smallOutlinedButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<bool> _authenticateWithMasterPassword() async {
    final passwordController = TextEditingController();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? dialogError;
        return Theme(
          data: theme.copyWith(
            colorScheme: cs.copyWith(primary: _accentBlue, secondary: _accentBlue),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text(
                  'Validación de Seguridad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                content: TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Clave maestra',
                    errorText: dialogError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await _bootstrap.unlockVault(masterPassword: passwordController.text);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (_) {
                        setDialogState(() => dialogError = 'Clave incorrecta');
                      }
                    },
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteEntry(VaultEntry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar entrada?'),
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

    if (confirm != true) return;

    final authenticated = await _authenticateWithMasterPassword();
    if (!authenticated) return;

    await widget.repo.deleteEntry(e.id);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada eliminada')),
    );
  }

  Future<void> _loadPasswordIfNeeded(VaultEntry e) async {
    if (_password != null) return;
    if (e.requireMasterPassword) {
      if (!await _authenticateWithMasterPassword()) return;
    }

    setState(() {
      _loadingPw = true;
      _error = null;
    });

    try {
      final dek = VaultState.instance?.dek;
      if (dek == null) throw 'Vault bloqueado';

      final pw = await widget.repo.decryptPassword(e.id, dek);
      if (mounted) setState(() => _password = pw);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo descifrar');
    } finally {
      if (mounted) setState(() => _loadingPw = false);
    }
  }

  Future<void> _copyPassword(VaultEntry e) async {
    await _loadPasswordIfNeeded(e);
    if (_password == null) return;

    await Clipboard.setData(ClipboardData(text: _password!));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña copiada')),
    );
  }

  Future<void> _checkPwned(VaultEntry e) async {
    await _loadPasswordIfNeeded(e);
    if (_password == null) return;

    setState(() => _checking = true);
    try {
      final count = await _pwned.getPwnCount(_password!);
      await widget.repo.setPwnedResult(entryId: e.id, pwnedCount: count);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(count > 0 ? 'Contraseña comprometida' : 'Contraseña segura'),
          content: Text(
            count > 0 ? 'Aparece $count veces en filtraciones.' : 'No se han encontrado filtraciones.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _saveChanges(VaultEntry current) async {
    if (_saving) return;

    final dek = VaultState.instance?.dek;
    if (dek == null) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío')),
      );
      return;
    }

    final authenticated = await _authenticateWithMasterPassword();
    if (!authenticated) return;

    setState(() => _saving = true);
    try {
      await widget.repo.updateEntry(
        id: current.id,
        title: _titleController.text.trim(),
        username: _userController.text.trim(),
        url: _urlController.text.trim(),
        password: _passController.text.isNotEmpty ? _passController.text : null,
        dek: _passController.text.isNotEmpty ? dek : null,
      );

      if (!mounted) return;
      setState(() {
        _editing = false;
        _password = null;
        _revealed = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseCs = baseTheme.colorScheme;

    final localTheme = baseTheme.copyWith(
      colorScheme: baseCs.copyWith(primary: _accentBlue, secondary: _accentBlue),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentBlue,
          side: BorderSide(color: _accentBlue.withOpacity(0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentBlue;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentBlue.withOpacity(0.35);
          return null;
        }),
      ),
    );

    return Theme(
      data: localTheme,
      child: StreamBuilder<VaultEntry>(
        stream: widget.repo.watchEntry(widget.entry.id),
        initialData: widget.entry,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

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
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                title: Text(
                  _editing ? 'Editar entrada' : e.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                leading: _editing
                    ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _editing = false),
                )
                    : null,
                actions: [
                  if (!_editing) ...[
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteEntry(e),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        _initControllers(e);
                        setState(() => _editing = true);
                      },
                    ),
                  ],
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_editing) ...[
                      _block(
                        context,
                        child: Column(
                          children: [
                            _editField(
                              context,
                              label: 'Servicio (título)',
                              controller: _titleController,
                            ),
                            const SizedBox(height: 12),
                            _editField(
                              context,
                              label: 'URL (opcional)',
                              controller: _urlController,
                              suffix: Icon(Icons.link_rounded,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _block(
                        context,
                        child: Column(
                          children: [
                            _editField(
                              context,
                              label: 'Usuario / Email',
                              controller: _userController,
                            ),
                            const SizedBox(height: 12),
                            _editField(
                              context,
                              label: 'Nueva contraseña',
                              controller: _passController,
                              obscureText: true,
                              helperText: 'Dejar vacío para mantener la actual',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      FilledButton(
                        onPressed: _saving ? null : () => _saveChanges(e),
                        child: _saving
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Guardar cambios'),
                      ),
                    ] else ...[
                      _block(
                        context,
                        child: Column(
                          children: [
                            _readField(context: context, label: 'Usuario', value: e.username ?? ''),
                            const SizedBox(height: 12),
                            _readField(
                              context: context,
                              label: 'URL',
                              value: e.url ?? '',
                              isLink: (e.url ?? '').isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _block(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _readField(
                              context: context,
                              label: 'Contraseña',
                              value: _loadingPw
                                  ? 'Cargando...'
                                  : (_revealed ? (_password ?? '') : '••••••••••••'),
                              trailing: IconButton(
                                tooltip: _revealed ? 'Ocultar' : 'Mostrar',
                                onPressed: () async {
                                  if (!_revealed) await _loadPasswordIfNeeded(e);
                                  if (_password != null) {
                                    setState(() => _revealed = !_revealed);
                                  }
                                },
                                icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _smallOutlinedButton(
                                  onPressed: _loadingPw ? null : () => _copyPassword(e),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: 'Copiar',
                                ),
                                const SizedBox(width: 10),
                                _smallOutlinedButton(
                                  onPressed: (_checking || _loadingPw) ? null : () => _checkPwned(e),
                                  icon: _checking
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.security_rounded, size: 18),
                                  label: 'Filtración',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 48),

                      _whiteCard(
                        context,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Requerir clave maestra',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Switch(
                              value: e.requireMasterPassword,
                              onChanged: (val) =>
                                  widget.repo.updateRequireMasterPassword(e.id, val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      _whiteCard(
                        context,
                        child: Column(
                          children: [
                            _MetaLine(label: 'Creado', value: dateFormat.format(e.createdAt)),
                            const SizedBox(height: 8),
                            _MetaLine(label: 'Modificado', value: dateFormat.format(e.updatedAt)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Text(
          '$label:',
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}