import 'package:flutter/widgets.dart';
import 'package:maltto/src/app/app.dart';
import 'package:maltto/src/features/scripts/data/local_script_repository.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';
import 'package:maltto/src/infrastructure/database/app_database.dart';
import 'package:maltto/src/infrastructure/database/drift_script_service.dart';

Widget createApp() {
  final database = AppDatabase.open();
  final scriptService = DriftScriptService(database);
  final scriptRepository = LocalScriptRepository(scriptService);
  final scriptListViewModel = ScriptListViewModel(scriptRepository);

  return MalttoApp(
    scriptListViewModel: scriptListViewModel,
    createScriptViewModel: () => ScriptCreateViewModel(scriptRepository),
    onDispose: database.close,
  );
}
