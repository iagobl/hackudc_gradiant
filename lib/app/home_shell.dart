import 'package:flutter/material.dart';
import 'package:hackudc_gradiant/features/generator/ui/generator_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/vault/ui/vault_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  static const Color _accentBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Theme(
      data: theme.copyWith(
        colorScheme: cs.copyWith(
          primary: _accentBlue,
          secondary: _accentBlue,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: _accentBlue.withOpacity(0.16),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? _accentBlue : cs.onSurfaceVariant,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _accentBlue : cs.onSurfaceVariant,
            );
          }),
        ),
      ),
      child: Scaffold(
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
      ),
    );
  }
}