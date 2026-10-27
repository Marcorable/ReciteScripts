import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';

final class ScriptListView extends StatefulWidget {
  const ScriptListView({required this.viewModel, super.key});

  final ScriptListViewModel viewModel;

  @override
  State<ScriptListView> createState() => _ScriptListViewState();
}

final class _ScriptListViewState extends State<ScriptListView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('대본')),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, child) {
            if (widget.viewModel.scripts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Semantics(
                    label: '저장된 대본 없음',
                    child: const Text(
                      '저장된 대본이 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: widget.viewModel.scripts.length,
              itemBuilder: (context, index) {
                final script = widget.viewModel.scripts[index];
                return Semantics(
                  label: '${script.title}, 낭독 설정 열기',
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(script.title),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
