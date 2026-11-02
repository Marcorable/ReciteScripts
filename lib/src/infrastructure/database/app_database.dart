import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:maltto/src/infrastructure/database/generated/local_storage_api.g.dart';
import 'package:maltto/src/infrastructure/database/migrations/schema_migration.dart';
import 'package:maltto/src/infrastructure/database/tables/scripts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ScriptRows])
final class AppDatabase extends _$AppDatabase {
  static final _localStorageApi = LocalStorageHostApi();

  AppDatabase(super.executor);

  factory AppDatabase.open() {
    return AppDatabase(
      LazyDatabase(() async {
        final directory = await getApplicationSupportDirectory();
        if (Platform.isIOS) {
          await _localStorageApi.excludeApplicationSupportFromBackup();
        }
        final databaseFile = File(path.join(directory.path, 'maltto.sqlite'));
        return NativeDatabase.createInBackground(databaseFile);
      }),
    );
  }

  factory AppDatabase.openAt(File databaseFile) {
    return AppDatabase(NativeDatabase.createInBackground(databaseFile));
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) =>
        migrateSchema(migrator, from: from, to: to),
  );
}
