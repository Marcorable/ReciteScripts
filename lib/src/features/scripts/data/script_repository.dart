import 'package:maltto/src/features/scripts/model/script.dart';

abstract interface class ScriptRepository {
  Stream<List<Script>> watchAll();
}
