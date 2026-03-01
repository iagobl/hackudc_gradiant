import 'package:flutter/material.dart';
import '../core/security/vault_bootstrap_service.dart';
import '../core/security/vault_state.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/ui/lock_screen.dart';
import '../features/auth/ui/setup_screen.dart';
import 'home_shell.dart';

// Llave global para permitir la navegación desde fuera del árbol de widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kryptos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      // LifecycleWatcher envuelve a todo el Navigator
      builder: (context, child) => LifecycleWatcher(child: child!),
      home: const _BootDecider(),
    );
  }
}

class LifecycleWatcher extends StatefulWidget {
  final Widget child;
  const LifecycleWatcher({super.key, required this.child});

  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher> with WidgetsBindingObserver {
  DateTime? _backgroundTime;
  final _storage = SecureStorageService();
  final _bootstrap = VaultBootstrapService(SecureStorageService());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // Guardamos la hora exacta en que la app se minimiza
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime == null) return;

      // Leemos la configuración de timeout guardada
      final timeoutStr = await _storage.readString('settings_auto_lock_seconds');
      final timeoutSeconds = int.tryParse(timeoutStr ?? '0') ?? 0;

      if (timeoutSeconds == -1) {
        _backgroundTime = null;
        return;
      }

      final diff = DateTime.now().difference(_backgroundTime!).inSeconds;
      
      // Si el tiempo en segundo plano supera el límite y el vault está abierto
      if (diff >= timeoutSeconds && VaultState.instance != null) {
        await _bootstrap.lockVault(); // Limpiar DEK de memoria
        
        // Redirigir a LockScreen limpiando todo el stack de navegación
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LockScreen()),
          (route) => false,
        );
      }
      _backgroundTime = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BootDecider extends StatelessWidget {
  const _BootDecider();

  @override
  Widget build(BuildContext context) {
    final bootstrap = VaultBootstrapService(SecureStorageService());
    return FutureBuilder<bool>(
      future: bootstrap.isVaultInitialized(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.data!) return const SetupScreen();
        
        return VaultState.instance != null ? const HomeShell() : const LockScreen();
      },
    );
  }
}
