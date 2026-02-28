import 'package:flutter/material.dart';
import '../../../core/storage/app_database.dart';
import '../data/vault_repository.dart';
import 'vault_add_screen.dart';
import 'vault_detail_screen.dart';

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  late final AppDatabase _db;
  late final VaultRepository _repo;

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _repo = VaultRepository(_db);
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VaultAddScreen(repo: _repo)),
    );
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
      body: StreamBuilder<List<VaultEntry>>(
        stream: _repo.watchEntries(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

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
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VaultDetailScreen(repo: _repo, entry: e),
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
