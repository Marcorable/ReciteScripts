import 'package:flutter/widgets.dart';
import 'package:maltto/src/app/app.dart';
import 'package:maltto/src/features/scripts/data/local_script_repository.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';
import 'package:maltto/src/infrastructure/database/in_memory_script_service.dart';

Widget createApp() {
  final scriptService = InMemoryScriptService();
  final scriptRepository = LocalScriptRepository(scriptService);
  final scriptListViewModel = ScriptListViewModel(scriptRepository);

  return MalttoApp(scriptListViewModel: scriptListViewModel);
}
