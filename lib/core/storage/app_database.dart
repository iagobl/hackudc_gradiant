import 'package:drift/drift.dart';
import 'database_connection.dart';

part 'app_database.g.dart';

class VaultEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();
  TextColumn get username => text().nullable()();
  TextColumn get url => text().nullable()();

  BlobColumn get passwordCipher => blob()();
  BlobColumn get passwordNonce => blob()();
  BlobColumn get passwordMac => blob()();

  BoolColumn get requireMasterPassword => boolean().withDefault(const Constant(false))();

  BoolColumn get breached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastBreachCheck => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get pwnedCount => integer().nullable()();
  DateTimeColumn get lastPwnedCheck => dateTime().nullable()();
}

@DriftDatabase(tables: [VaultEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(vaultEntries, vaultEntries.pwnedCount);
        await m.addColumn(vaultEntries, vaultEntries.lastPwnedCheck);
      }
      if (from < 3) {
        await m.addColumn(vaultEntries, vaultEntries.passwordMac);
      }
      if (from < 4) {
        await m.addColumn(vaultEntries, vaultEntries.requireMasterPassword);
      }
    },
  );
}
