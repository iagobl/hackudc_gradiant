import 'package:flutter/material.dart';

import '../../../core/storage/app_database.dart';
import '../data/vault_list_controller.dart';
import '../data/vault_repository.dart';

import 'vault_add_screen.dart';
import 'vault_detail_screen.dart';

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  static const Color _accentBlue = Color(0xFF2563EB);

  late final VaultRepository _repo;
  late final VaultListController _controller;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _repo = VaultRepository(AppDatabase.instance);

    _controller = VaultListController(repo: _repo);

    _searchCtrl.addListener(() => _controller.setQuery(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VaultAddScreen(repo: _repo)),
    );
  }

  Future<void> _openDetail(VaultEntry e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaultDetailScreen(repo: _repo, entry: e),
      ),
    );
  }

  String _sortLabel(VaultSortMode mode) {
    switch (mode) {
      case VaultSortMode.newestFirst:
        return 'Recientes primero';
      case VaultSortMode.oldestFirst:
        return 'Antiguas primero';
      case VaultSortMode.az:
        return 'A–Z';
      case VaultSortMode.za:
        return 'Z–A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final localTheme = theme.copyWith(
      colorScheme: cs.copyWith(primary: _accentBlue, secondary: _accentBlue),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          elevation: 0,
          title: Text(
            'Mis contraseñas',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return PopupMenuButton<VaultSortMode>(
                  tooltip: 'Ordenar',
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: (mode) => setState(() => _controller.setSortMode(mode)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: VaultSortMode.newestFirst,
                      child: _buildSortItem(
                        context,
                        'Recientes primero',
                        VaultSortMode.newestFirst,
                      ),
                    ),
                    PopupMenuItem(
                      value: VaultSortMode.oldestFirst,
                      child: _buildSortItem(
                        context,
                        'Antiguas primero',
                        VaultSortMode.oldestFirst,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: VaultSortMode.az,
                      child: _buildSortItem(
                        context,
                        'A–Z',
                        VaultSortMode.az,
                      ),
                    ),
                    PopupMenuItem(
                      value: VaultSortMode.za,
                      child: _buildSortItem(
                        context,
                        'Z–A',
                        VaultSortMode.za,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 6),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAdd,
          icon: const Icon(Icons.add),
          label: const Text('Añadir'),
        ),

        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchBar(
                controller: _searchCtrl,
                accent: _accentBlue,
              ),
              const SizedBox(height: 12),

              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final label = _sortLabel(_controller.sortMode);

                  return Row(
                    children: [
                      StreamBuilder<List<VaultEntry>>(
                        stream: _controller.stream,
                        builder: (context, snap) {
                          final count = (snap.data ?? const []).length;
                          return Text(
                            '$count elementos',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<List<VaultEntry>>(
                  stream: _controller.stream,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const [];

                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          _controller.query.isEmpty
                              ? 'Aún no tienes contraseñas guardadas.'
                              : 'No se encontraron resultados.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 110),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final e = items[i];
                        final initial = (e.title.isNotEmpty ? e.title[0] : '?').toUpperCase();

                        final isLocked = e.requireMasterPassword;
                        final isPwned = (e.pwnedCount ?? 0) > 0;

                        return _EntryCard(
                          accent: _accentBlue,
                          title: e.title,
                          subtitle: e.username ?? '',
                          initial: initial,
                          isLocked: isLocked,
                          isPwned: isPwned,
                          onTap: () => _openDetail(e),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortItem(
      BuildContext context,
      String label,
      VaultSortMode mode,
      ) {
    final selected = _controller.sortMode == mode;

    return Row(
      children: [
        Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          size: 18,
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.accent,
  });

  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Buscar por título o usuario...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => controller.clear(),
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              tooltip: 'Limpiar',
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.isLocked,
    required this.isPwned,
    required this.onTap,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final String initial;
  final bool isLocked;
  final bool isPwned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final statusIcon = isPwned
        ? Icons.warning_rounded
        : (isLocked ? Icons.lock_rounded : Icons.lock_open_rounded);

    final statusColor = isPwned ? Colors.redAccent : accent;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? '—' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withOpacity(0.18)),
                ),
                child: Icon(statusIcon, color: statusColor),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}