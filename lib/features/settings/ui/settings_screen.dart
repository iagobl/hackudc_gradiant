import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hackudc_gradiant/core/security/vault_bootstrap_service.dart';
import 'package:hackudc_gradiant/core/storage/secure_storage_service.dart';
import 'package:hackudc_gradiant/core/storage/app_database.dart';
import 'package:hackudc_gradiant/features/vault/data/vault_repository.dart';
import 'package:hackudc_gradiant/features/settings/data/vault_import_export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _bootstrap = VaultBootstrapService(SecureStorageService());
  final _storage = SecureStorageService();
  late final VaultRepository _repo;
  late final VaultImportExportService _importExport;
  
  bool _biometricsEnabled = false;
  bool _loading = true;
  int _autoLockSeconds = 30;

  static const _kAutoLockKey = 'settings_auto_lock_seconds';

  @override
  void initState() {
    super.initState();
    _repo = VaultRepository(AppDatabase.instance);
    _importExport = VaultImportExportService(_repo);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bioEnabled = await _bootstrap.isBiometricsEnabled();
    final lockStr = await _storage.readString(_kAutoLockKey);
    final lockVal = int.tryParse(lockStr ?? '30') ?? 30;

    if (mounted) {
      setState(() {
        _biometricsEnabled = bioEnabled;
        _autoLockSeconds = lockVal;
        _loading = false;
      });
    }
  }

  Future<void> _setAutoLock(int seconds) async {
    await _storage.writeString(_kAutoLockKey, seconds.toString());
    setState(() => _autoLockSeconds = seconds);
  }

  Future<void> _toggleBiometrics(bool value) async {
    setState(() => _loading = true);
    try {
      if (value) {
        await _bootstrap.enableBiometrics();
      } else {
        await _bootstrap.disableBiometrics();
      }
      setState(() {
        _biometricsEnabled = value;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askForMasterPassword() async {
    final passwordController = TextEditingController();
    return await showDialog<String>(
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
                  const Text('Introduce tu clave maestra para continuar.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () async {
                    try {
                      await _bootstrap.unlockVault(masterPassword: passwordController.text);
                      if (context.mounted) Navigator.pop(context, passwordController.text);
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
  }

  Future<void> _exportVault() async {
    final password = await _askForMasterPassword();
    if (password == null) return;

    setState(() => _loading = true);
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'vault_backup_$timestamp.vlt';
      
      final bytes = await _importExport.getExportBytes(masterPassword: password);

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar respaldo de bóveda',
        fileName: fileName,
        bytes: bytes,
        type: FileType.any,
      );

      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Bóveda exportada con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importVault() async {
    final password = await _askForMasterPassword();
    if (password == null) return;

    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final bytes = result.files.single.bytes!;

      final count = await _importExport.importVault(masterPassword: password, fileBytes: bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Importación exitosa! $count entradas añadidas.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMasterPassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? oldError; String? newError; String? confirmError; String? generalError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar Clave Maestra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (generalError != null)
                      Container(
                        padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                        child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(generalError!, style: const TextStyle(color: Colors.red, fontSize: 13)))]),
                      ),
                    const Text('Se requiere al menos 12 caracteres, mayúsculas y símbolos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(controller: oldController, obscureText: true, onChanged: (_) => setDialogState(() => oldError = null), decoration: InputDecoration(labelText: 'Contraseña actual', labelStyle: const TextStyle(fontSize: 14), errorText: oldError, border: const OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: newController, obscureText: true, onChanged: (_) => setDialogState(() => newError = null), decoration: InputDecoration(labelText: 'Nueva contraseña', labelStyle: const TextStyle(fontSize: 14), errorText: newError, errorMaxLines: 3, border: const OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: confirmController, obscureText: true, onChanged: (_) => setDialogState(() => confirmError = null), decoration: InputDecoration(labelText: 'Confirmar contraseña', labelStyle: const TextStyle(fontSize: 14), errorText: confirmError, border: const OutlineInputBorder())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    bool isValid = true;
                    setDialogState(() {
                      oldError = null; newError = null; confirmError = null; generalError = null;
                      final newPass = newController.text;
                      if (oldController.text.isEmpty) { oldError = 'Introduce tu contraseña actual'; isValid = false; }
                      if (newPass.isEmpty) { newError = 'La contraseña no puede estar vacía'; isValid = false; } else {
                        final hasUppercase = newPass.contains(RegExp(r'[A-Z]'));
                        final hasSpecial = newPass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                        if (newPass.length < 12 || !hasUppercase || !hasSpecial) { newError = 'Debe tener al menos 12 caracteres, contener caracteres especiales y mayúsculas'; isValid = false; }
                      }
                      if (newPass != confirmController.text) { confirmError = 'Las contraseñas no coinciden'; isValid = false; }
                    });
                    if (isValid) Navigator.pop(context, true);
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        await _bootstrap.changeMasterPassword(oldPassword: oldController.text, newPassword: newController.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Contraseña maestra actualizada con éxito!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cambiar contraseña: Clave actual incorrecta'), backgroundColor: Colors.red));
      } finally { if (mounted) setState(() => _loading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Configuración',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,)
        )
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSectionTitle('Seguridad'),
              ListTile(leading: const Icon(Icons.password_rounded), title: const Text('Cambiar Clave Maestra'), subtitle: const Text('Actualiza tu clave de acceso principal'), trailing: const Icon(Icons.chevron_right), onTap: _changeMasterPassword),
              const Divider(indent: 70),
              SwitchListTile(secondary: const Icon(Icons.fingerprint_rounded), title: const Text('Desbloqueo Biométrico'), subtitle: const Text('Usa tu huella o rostro para entrar'), value: _biometricsEnabled, onChanged: _toggleBiometrics),
              const Divider(indent: 70),
              ListTile(leading: const Icon(Icons.timer_outlined), title: const Text('Tiempo de Bloqueo Automático'), subtitle: Text(_getLockText(_autoLockSeconds)), trailing: const Icon(Icons.arrow_drop_down), onTap: _showLockTimePicker),
              
              const Divider(),
              _buildSectionTitle('Bóveda'),
              ListTile(leading: const Icon(Icons.upload_file_rounded), title: const Text('Exportar Bóveda'), subtitle: const Text('Crea un archivo de respaldo cifrado (.vlt)'), onTap: _exportVault),
              const Divider(indent: 70),
              ListTile(leading: const Icon(Icons.download_rounded), title: const Text('Importar Bóveda'), subtitle: const Text('Selecciona un archivo (.vlt) para restaurar'), onTap: _importVault),

              const Divider(),
              _buildSectionTitle('Información'),
              const ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('Versión'), subtitle: Text('1.0.0')),
            ],
          ),
          if (_loading) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  String _getLockText(int seconds) {
    if (seconds == 0) return 'Bloqueo inmediato';
    if (seconds == -1) return 'Nunca';
    if (seconds < 60) return '$seconds segundos';
    return '${seconds ~/ 60} minutos';
  }

  void _showLockTimePicker() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildLockOption('Inmediatamente', 0), _buildLockOption('30 segundos', 30), _buildLockOption('1 minuto', 60), _buildLockOption('2 minutos', 120), _buildLockOption('5 minutos', 300),
    ])));
  }

  Widget _buildLockOption(String label, int seconds) {
    return ListTile(title: Text(label), trailing: _autoLockSeconds == seconds ? const Icon(Icons.check, color: Colors.blue) : null, onTap: () { _setAutoLock(seconds); Navigator.pop(context); });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)));
  }
}
