import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/database/script_service.dart';

final class LocalScriptRepository implements ScriptRepository {
  const LocalScriptRepository(this._service);

  final ScriptService _service;

  @override
  Stream<List<Script>> watchAll() {
    return _service.watchAll().map(
      (rows) => List.unmodifiable(rows.map(_toScript)),
    );
  }

  @override
  Future<List<Script>> getAll() async {
    final rows = await _service.getAll();
    return List.unmodifiable(rows.map(_toScript));
  }

  @override
  Future<Script> create({required String title, required String body}) async {
    final row = await _service.create(title: title, body: body);
    return _toScript(row);
  }

  @override
  Future<void> delete(int id) => _service.delete(id);

  Script _toScript(StoredScript row) {
    return Script(
      id: row.id,
      title: row.title,
      body: row.body,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
