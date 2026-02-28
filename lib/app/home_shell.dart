import 'package:flutter/material.dart';
import 'package:hackudc_gradiant/features/generator/ui/generator_screen.dart';
import 'package:hackudc_gradiant/features/settings/ui/settings_screen.dart';
import '../features/vault/ui/vault_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          VaultListScreen(),
          GeneratorScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lock),
            label: 'Contraseñas',
          ),
          NavigationDestination(
            icon: Icon(Icons.password),
            label: 'Generador',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}