import 'package:drift/drift.dart';
import 'package:maltto/src/infrastructure/database/app_database.dart';
import 'package:maltto/src/infrastructure/database/script_service.dart';

final class DriftScriptService implements ScriptService {
  DriftScriptService(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  Stream<List<StoredScript>> watchAll() {
    return (_database.select(_database.scriptRows)..orderBy([
          (row) => OrderingTerm.desc(row.createdAt),
          (row) => OrderingTerm.desc(row.id),
        ]))
        .watch()
        .map((rows) => List.unmodifiable(rows.map(_toStoredScript)));
  }

  @override
  Future<List<StoredScript>> getAll() async {
    final rows =
        await (_database.select(_database.scriptRows)..orderBy([
              (row) => OrderingTerm.desc(row.createdAt),
              (row) => OrderingTerm.desc(row.id),
            ]))
            .get();
    return List.unmodifiable(rows.map(_toStoredScript));
  }

  @override
  Future<StoredScript> create({
    required String title,
    required String body,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('The script title must not be blank.');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError('The script body must not be blank.');
    }
    final timestamp = _now().toUtc();
    final id = await _database
        .into(_database.scriptRows)
        .insert(
          ScriptRowsCompanion.insert(
            title: title,
            body: body,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    final row = await (_database.select(
      _database.scriptRows,
    )..where((candidate) => candidate.id.equals(id))).getSingle();
    return _toStoredScript(row);
  }

  @override
  Future<void> delete(int id) async {
    await (_database.delete(
      _database.scriptRows,
    )..where((row) => row.id.equals(id))).go();
  }

  StoredScript _toStoredScript(ScriptRow row) {
    return StoredScript(
      id: row.id,
      title: row.title,
      body: row.body,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
