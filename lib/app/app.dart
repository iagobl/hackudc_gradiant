import 'package:flutter/material.dart';
import '../core/security/vault_bootstrap_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/ui/lock_screen.dart';
import '../features/auth/ui/setup_screen.dart';

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HackUDC Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const _BootDecider(),
    );
  }
}

class _BootDecider extends StatefulWidget {
  const _BootDecider();

  @override
  State<_BootDecider> createState() => _BootDeciderState();
}

class _BootDeciderState extends State<_BootDecider> with WidgetsBindingObserver {
  late final VaultBootstrapService _bootstrap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap = VaultBootstrapService(SecureStorageService());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _bootstrap.lockVault();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrap.isVaultInitialized(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final initialized = snap.data!;
        return initialized ? const LockScreen() : const SetupScreen();
      },
    );
  }
}