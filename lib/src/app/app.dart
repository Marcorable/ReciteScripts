import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';

final class MalttoApp extends StatefulWidget {
  const MalttoApp({
    required this.scriptListViewModel,
    required this.createScriptViewModel,
    required this.readingSetupBuilder,
    this.onDispose,
    super.key,
  });

  final ScriptListViewModel scriptListViewModel;
  final ScriptCreateViewModel Function() createScriptViewModel;
  final Widget Function(Script script) readingSetupBuilder;
  final Future<void> Function()? onDispose;

  @override
  State<MalttoApp> createState() => _MalttoAppState();
}

final class _MalttoAppState extends State<MalttoApp> {
  @override
  void dispose() {
    widget.scriptListViewModel.dispose();
    unawaited(widget.onDispose?.call());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: '말또',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: ScriptListView(
        viewModel: widget.scriptListViewModel,
        createScriptViewModel: widget.createScriptViewModel,
        readingSetupBuilder: widget.readingSetupBuilder,
      ),
    );
  }
}
