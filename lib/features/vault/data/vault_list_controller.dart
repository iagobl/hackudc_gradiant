import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import 'vault_repository.dart';

enum VaultSortMode {
  newestFirst,
  oldestFirst,
  az,
  za,
}

class VaultListController extends ChangeNotifier {
  VaultListController({required this.repo}) {
    _sub = repo.watchEntries().listen((items) {
      _raw = items;
      _emit();
    });
  }

  final VaultRepository repo;

  late final StreamSubscription<List<VaultEntry>> _sub;

  final _outCtrl = StreamController<List<VaultEntry>>.broadcast();
  Stream<List<VaultEntry>> get stream => _outCtrl.stream;

  List<VaultEntry> _raw = const [];

  String _query = '';
  String get query => _query;

  VaultSortMode _sortMode = VaultSortMode.newestFirst;
  VaultSortMode get sortMode => _sortMode;

  void setQuery(String q) {
    _query = q.trim();
    _emit();
    notifyListeners();
  }

  void setSortMode(VaultSortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _emit();
    notifyListeners();
  }

  void _emit() {
    final q = _query.toLowerCase();

    List<VaultEntry> filtered;
    if (q.isNotEmpty) {
      filtered = _raw.where((e) {
        final t = e.title.toLowerCase();
        final u = (e.username ?? '').toLowerCase();
        return t.contains(q) || u.contains(q);
      }).toList();
    } else {
      filtered = List<VaultEntry>.from(_raw);
    }

    filtered.sort((a, b) {
      switch (_sortMode) {
        case VaultSortMode.newestFirst:
          return b.createdAt.compareTo(a.createdAt);

        case VaultSortMode.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);

        case VaultSortMode.az:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());

        case VaultSortMode.za:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      }
    });

    _outCtrl.add(filtered);
  }

  @override
  void dispose() {
    _sub.cancel();
    _outCtrl.close();
    super.dispose();
  }
}