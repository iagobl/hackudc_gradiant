import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/security/vault_bootstrap_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/security/vault_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _bootstrap = VaultBootstrapService(SecureStorageService());
  bool _biometricsEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _bootstrap.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _biometricsEnabled = enabled;
        _loading = false;
      });
    }
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
                        final hasSpecial = newPass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                        
                        if (newPass.length < 12 || !hasUppercase || !hasSpecial) {
                          newError = 'Debe tener al menos 12 caracteres, contener caracteres especiales y mayúsculas';
                          isValid = false;
                        }
                      }

                      if (newPass != confirmController.text) {
                        confirmError = 'Las contraseñas no coinciden';
                        isValid = false;
                      }
                    });

                    if (isValid) {
                      Navigator.pop(context, true);
                    }
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
        await _bootstrap.changeMasterPassword(
          oldPassword: oldController.text,
          newPassword: newController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Contraseña maestra actualizada con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al cambiar contraseña: Clave actual incorrecta'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
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
                value: _biometricsEnabled,
                onChanged: _toggleBiometrics,
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
          if (_loading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
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
}
