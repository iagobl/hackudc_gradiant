import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'vault.sqlite'));

    return NativeDatabase(file);
  });
}