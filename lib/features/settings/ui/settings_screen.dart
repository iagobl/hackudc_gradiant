import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _askForMasterPassword({bool validate = true}) async {
    final passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                validate ? 'Validación de Seguridad' : 'Contraseña del Respaldo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    validate
                        ? 'Introduce tu clave maestra para continuar.'
                        : 'Introduce la clave maestra con la que se cifró este archivo.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (validate) {
                      try {
                        await _controller.validateMasterPassword(passwordController.text);
                        if (context.mounted) {
                          Navigator.pop(context, passwordController.text);
                        }
                      } catch (_) {
                        setDialogState(() => dialogError = 'Clave incorrecta');
                      }
                    } else {
                      Navigator.pop(context, passwordController.text);
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

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'vault_backup_$timestamp.vlt';

      final Uint8List bytes = await _controller.getExportBytes(masterPassword: password);

      await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar respaldo de bóveda',
        fileName: fileName,
        bytes: bytes,
        type: FileType.any,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bóveda exportada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importVault() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final Uint8List bytes = result.files.single.bytes!;

      final password = await _askForMasterPassword(validate: false);
      if (password == null) return;

      final count = await _controller.importVault(
        masterPassword: password,
        fileBytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Importación exitosa! $count entradas añadidas.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al importar: Contraseña incorrecta o archivo dañado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeMasterPassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? oldError;
        String? newError;
        String? confirmError;
        String? generalError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Cambiar Clave Maestra',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (generalError != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                generalError!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      'Se requiere al menos 12 caracteres, mayúsculas y símbolos.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: oldController,
                      obscureText: true,
                      onChanged: (_) => setDialogState(() => oldError = null),
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        labelStyle: const TextStyle(fontSize: 14),
                        errorText: oldError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      onChanged: (_) => setDialogState(() => newError = null),
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        labelStyle: const TextStyle(fontSize: 14),
                        errorText: newError,
                        errorMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      onChanged: (_) => setDialogState(() => confirmError = null),
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        labelStyle: const TextStyle(fontSize: 14),
                        errorText: confirmError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    bool isValid = true;
                    setDialogState(() {
                      oldError = null;
                      newError = null;
                      confirmError = null;
                      generalError = null;

                      final newPass = newController.text;

                      if (oldController.text.isEmpty) {
                        oldError = 'Introduce tu contraseña actual';
                        isValid = false;
                      }

                      if (newPass.isEmpty) {
                        newError = 'La contraseña no puede estar vacía';
                        isValid = false;
                      } else {
                        final hasUppercase = newPass.contains(RegExp(r'[A-Z]'));
                        final hasSpecial = newPass.contains(RegExp(r'[^a-zA-Z0-9]'));

                        if (newPass.length < 12 || !hasUppercase || !hasSpecial) {
                          newError =
                          'Debe tener al menos 12 caracteres, contener caracteres especiales y mayúsculas';
                          isValid = false;
                        }
                      }

                      if (newPass != confirmController.text) {
                        confirmError = 'Las contraseñas no coinciden';
                        isValid = false;
                      }
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
      try {
        await _controller.changeMasterPassword(
          oldPassword: oldController.text,
          newPassword: newController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Contraseña maestra actualizada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cambiar contraseña: Clave actual incorrecta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cloudSignInOrUp() async {
    try {
      await showCloudAuthDialog(
        context,
        onSignIn: (email, pass) => _controller.signInCloud(email: email, password: pass),
        onSignUp: (email, pass) => _controller.signUpCloud(email: email, password: pass),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cloudSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?\n\n'
              'La sincronización en cloud se desactivará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _controller.signOutCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión cerrada y cloud desactivado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _onToggleCloud(bool enable) async {
    try {
      if (!enable) {
        await _controller.setCloudEnabled(enabled: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronización en cloud desactivada.')),
        );
        return;
      }

      if (!_controller.cloudSignedIn) {
        await _cloudSignInOrUp();
        if (!_controller.cloudSignedIn) return;
      }

      final master = await _askForMasterPassword(validate: true);
      if (master == null) return;

      await _controller.setCloudEnabled(enabled: true, masterPassword: master);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud activado. Migración inicial completada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _syncNow() async {
    try {
      await _controller.syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronización completada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _importFromCloud() async {
    try {
      final master = await _askForMasterPassword(validate: true);
      if (master == null) return;

      final imported = await _controller.importFromCloud(masterPassword: master);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importadas/actualizadas: $imported entradas.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> showCloudAuthDialog(
      BuildContext context, {
        required Future<void> Function(String email, String password) onSignIn,
        required Future<void> Function(String email, String password) onSignUp,
      }) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final repeatCtrl = TextEditingController();

    bool isSignUp = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final showRepeat = isSignUp;

            return AlertDialog(
              title: Text(isSignUp ? 'Crear cuenta' : 'Iniciar sesión'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                    ),
                    onChanged: (_) {
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                  if (showRepeat) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: repeatCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Repetir contraseña',
                      ),
                      onChanged: (_) {
                        if (errorText != null) setState(() => errorText = null);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() {
                        isSignUp = !isSignUp;
                        errorText = null;
                      }),
                      child: Text(
                        isSignUp
                            ? '¿Ya tienes cuenta? Iniciar sesión'
                            : '¿No tienes cuenta? Crear cuenta',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailCtrl.text.trim();
                    final pass = passCtrl.text;
                    final repeat = repeatCtrl.text;

                    if (email.isEmpty || !email.contains('@')) {
                      setState(() => errorText = 'Introduce un email válido.');
                      return;
                    }
                    if (pass.length < 6) {
                      setState(() => errorText = 'La contraseña debe tener al menos 6 caracteres.');
                      return;
                    }
                    if (isSignUp && pass != repeat) {
                      setState(() => errorText = 'Las contraseñas no coinciden.');
                      return;
                    }

                    try {
                      if (isSignUp) {
                        await onSignUp(email, pass);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cuenta creada.',
                            ),
                          ),
                        );
                      } else {
                        await onSignIn(email, pass);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => errorText = e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: Text(isSignUp ? 'Crear' : 'Entrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getLockText(int seconds) {
    if (seconds == 0) return 'Bloqueo inmediato';
    if (seconds == -1) return 'Nunca';
    if (seconds < 60) return '$seconds segundos';
    return '${seconds ~/ 60} minutos';
  }

  void _showLockTimePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLockOption('Inmediatamente', 0),
            _buildLockOption('30 segundos', 30),
            _buildLockOption('1 minuto', 60),
            _buildLockOption('2 minutos', 120),
            _buildLockOption('5 minutos', 300),
          ],
        ),
      ),
    );
  }

  Widget _buildLockOption(String label, int seconds) {
    return ListTile(
      title: Text(label),
      trailing: _controller.autoLockSeconds == seconds
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        _controller.setAutoLock(seconds);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        title: Text(
          'Configuración',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSectionTitle('Seguridad'),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Cambiar Clave Maestra'),
                subtitle: const Text('Actualiza tu clave de acceso principal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changeMasterPassword,
              ),
              const Divider(indent: 70),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Desbloqueo Biométrico'),
                subtitle: const Text('Usa tu huella o rostro para entrar'),
                value: _controller.biometricsEnabled,
                onChanged: (v) async {
                  try {
                    await _controller.toggleBiometrics(v);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
              ),
              const Divider(indent: 70),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Tiempo de Bloqueo Automático'),
                subtitle: Text(_getLockText(_controller.autoLockSeconds)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _showLockTimePicker,
              ),
              const Divider(),
              _buildSectionTitle('Bóveda'),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Exportar Bóveda'),
                subtitle: const Text('Crea un archivo de respaldo cifrado (.vlt)'),
                onTap: _exportVault,
              ),
              const Divider(indent: 70),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Importar Bóveda'),
                subtitle: const Text('Selecciona un archivo (.vlt) para restaurar'),
                onTap: _importVault,
              ),
              const Divider(),
              _buildSectionTitle('Cloud'),
              ListTile(
                leading: Icon(_controller.cloudEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                title: const Text('Sincronización en Cloud'),
                subtitle: Text(_controller.cloudEnabled
                    ? 'Activada${_controller.cloudSignedIn ? ' • ${_controller.cloudUserEmail ?? ''}' : ''}'
                    : 'Desactivada'),
                trailing: Switch(
                  value: _controller.cloudEnabled,
                  onChanged: (v) async => _onToggleCloud(v),
                ),
              ),
              const Divider(indent: 70),
              ListTile(
                leading: Icon(_controller.cloudSignedIn ? Icons.logout_rounded : Icons.login_rounded),
                title: Text(_controller.cloudSignedIn ? 'Cerrar sesión (Supabase)' : 'Iniciar sesión (Supabase)'),
                subtitle: Text(_controller.cloudSignedIn
                    ? 'Cuenta: ${_controller.cloudUserEmail ?? ''}'
                    : 'Necesario para sincronizar e importar'),
                onTap: _controller.cloudSignedIn ? _cloudSignOut : _cloudSignInOrUp,
              ),
              const Divider(indent: 70),
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Sincronizar ahora'),
                subtitle: const Text('Sube las contraseñas locales al cloud'),
                enabled: _controller.cloudEnabled && _controller.cloudSignedIn,
                onTap: _syncNow,
              ),
              const Divider(indent: 70),
              ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: const Text('Importar desde Cloud'),
                subtitle: const Text('Descarga y fusiona las contraseñas del cloud a local'),
                enabled: _controller.cloudSignedIn,
                onTap: _importFromCloud,
              ),
              const Divider(),
              _buildSectionTitle('Información'),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Versión'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
          if (_controller.loading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}