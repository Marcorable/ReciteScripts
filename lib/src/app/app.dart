import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';

final class MalttoApp extends StatelessWidget {
  const MalttoApp({required this.scriptListViewModel, super.key});

  final ScriptListViewModel scriptListViewModel;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: '말또',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: ScriptListView(viewModel: scriptListViewModel),
    );
  }
}
