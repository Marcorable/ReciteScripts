import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/database/script_service.dart';

final class LocalScriptRepository implements ScriptRepository {
  const LocalScriptRepository(this._service);

  final ScriptService _service;

  @override
  Stream<List<Script>> watchAll() {
    return _service.watchAll().map(
      (rows) => List.unmodifiable(
        rows.map((row) => Script(id: row.id, title: row.title, body: row.body)),
      ),
    );
  }
}
