import 'package:drift/drift.dart';
import 'database_connection.dart';

part 'app_database.g.dart';

class VaultEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();
  TextColumn get username => text().nullable()();
  TextColumn get url => text().nullable()();

  BlobColumn get passwordCipher => blob()(); // ciphertext+tag
  BlobColumn get passwordNonce => blob()();  // 12 bytes

  BoolColumn get breached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastBreachCheck => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [VaultEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;
}