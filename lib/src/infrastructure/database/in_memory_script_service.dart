import 'package:maltto/src/infrastructure/database/script_service.dart';

final class InMemoryScriptService implements ScriptService {
  @override
  Stream<List<StoredScript>> watchAll() => Stream.value(const []);
}
