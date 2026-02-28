import 'package:flutter/material.dart';
import '../../../core/storage/app_database.dart';
import '../data/vault_repository.dart';
import 'vault_add_screen.dart';
import 'vault_detail_screen.dart';

enum _VaultSort { az, za }

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  late final AppDatabase _db;
  late final VaultRepository _repo;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _VaultSort _sort = _VaultSort.az;

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _repo = VaultRepository(_db);

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VaultAddScreen(repo: _repo)),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _db.close();
    super.dispose();
  }

  List<VaultEntry> _applyQueryAndSort(List<VaultEntry> entries) {
    final q = _query.toLowerCase();

    var list = entries.where((e) {
      if (q.isEmpty) return true;
      final t = e.title.toLowerCase();
      final u = (e.username ?? '').toLowerCase();
      return t.contains(q) || u.contains(q);
    }).toList();

    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (_sort == _VaultSort.za) list = list.reversed.toList();

    return list;
  }

  Color get _accent => const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Theme(
      data: theme.copyWith(
        colorScheme: cs.copyWith(
          primary: _accent,
          secondary: _accent,
        ),
      ),
      child: Builder(
        builder: (context) {
          final t = Theme.of(context);
          final c = t.colorScheme;

          return Scaffold(
            body: StreamBuilder<List<VaultEntry>>(
              stream: _repo.watchEntries(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final entries = snap.data!;
                if (entries.isEmpty) {
                  return _EmptyVault(onAdd: _openAdd, accent: _accent);
                }

                final filtered = _applyQueryAndSort(entries);

                return SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 66,
                        backgroundColor: c.surface,
                        surfaceTintColor: c.surface,
                        elevation: 0,
                        title: Text(
                          'Mis contraseñas',
                          style: t.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        actions: [
                          PopupMenuButton<_VaultSort>(
                            tooltip: 'Ordenar',
                            initialValue: _sort,
                            onSelected: (v) => setState(() => _sort = v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _VaultSort.az,
                                child: Text('Ordenar: A → Z'),
                              ),
                              PopupMenuItem(
                                value: _VaultSort.za,
                                child: Text('Ordenar: Z → A'),
                              ),
                            ],
                            icon: const Icon(Icons.sort),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: SearchBar(
                            controller: _searchCtrl,
                            leading: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(Icons.search, color: c.primary),
                            ),
                            hintText: 'Buscar por título o usuario…',
                            hintStyle: WidgetStateProperty.all(
                              TextStyle(color: c.onSurfaceVariant),
                            ),
                            elevation: WidgetStateProperty.all(2),
                            backgroundColor: WidgetStateProperty.all(c.surface),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            trailing: [
                              if (_query.isNotEmpty)
                                IconButton(
                                  tooltip: 'Limpiar',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _searchCtrl.clear(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: Row(
                            children: [
                              Text(
                                '${filtered.length} ${filtered.length == 1 ? 'elemento' : 'elementos'}',
                                style: t.textTheme.labelLarge?.copyWith(
                                  color: c.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (_query.isNotEmpty)
                                Text(
                                  'Filtrado',
                                  style: t.textTheme.labelLarge?.copyWith(
                                    color: c.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final e = filtered[i];
                            final title = e.title.trim().isEmpty ? 'Sin título' : e.title.trim();
                            final user =
                            (e.username == null || e.username!.trim().isEmpty)
                                ? 'Sin usuario'
                                : e.username!.trim();
                            final initial = title[0].toUpperCase();

                            return _VaultCard(
                              accent: c.primary,
                              title: title,
                              subtitle: user,
                              initial: initial,
                              alert: e.breached,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VaultDetailScreen(repo: _repo, entry: e),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            ),
          );
        },
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.alert,
    required this.onTap,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final String initial;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final border = cs.outlineVariant.withOpacity(0.35);
    final statusColor = alert ? cs.error : accent;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withOpacity(0.12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withOpacity(0.20),
                    ),
                  ),
                  child: Icon(
                    alert ? Icons.warning_amber_rounded : Icons.lock_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                ),

                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.onAdd, required this.accent});

  final VoidCallback onAdd;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: accent.withOpacity(0.12),
                    ),
                    child: Icon(Icons.lock_rounded, size: 34, color: accent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu vault está vacío',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Añade tu primera contraseña para empezar.\nPodrás buscar y abrir cada entrada con un toque.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}