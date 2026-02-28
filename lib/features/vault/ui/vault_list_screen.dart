import 'package:flutter/material.dart';
import '../../../core/storage/app_database.dart' as db;
import '../data/vault_repository.dart';
import 'vault_add_screen.dart';

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  late final db.AppDatabase _db;
  late final VaultRepository _repo;
  late Future<List<VaultEntry>> _load;

  @override
  void initState() {
    super.initState();
    _db = db.AppDatabase();
    _repo = VaultRepository(_db);
    _load = _repo.listEntries();
  }

  Future<void> _reload() async {
    setState(() => _load = _repo.listEntries());
  }

  Future<void> _openAdd() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VaultAddScreen(repo: _repo)),
    );
    if (created == true) await _reload();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis contraseñas')),
      body: FutureBuilder<List<VaultEntry>>(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'Vault vacío.\nPulsa "Añadir" para crear tu primera contraseña.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(e.username ?? ''),
                trailing: Icon(e.breached ? Icons.warning_amber : Icons.lock),
                onTap: () async {
                  // Demo: mostrar contraseña. Luego lo haremos en pantalla detalle segura.
                  final pw = await _repo.decryptPassword(e.id);
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(e.title),
                      content: Text('Contraseña (demo):\n$pw'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }
}