import 'package:maltto/src/features/scripts/model/script.dart';

abstract interface class ScriptRepository {
  Stream<List<Script>> watchAll();

  Future<List<Script>> getAll();

  Future<Script> create({required String title, required String body});

  Future<void> delete(int id);
}
