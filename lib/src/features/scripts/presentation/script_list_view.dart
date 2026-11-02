import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_components.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_navigation_actions.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

final class ScriptListView extends StatefulWidget {
  const ScriptListView({
    required this.viewModel,
    required this.createScriptViewModel,
    super.key,
  });

  final ScriptListViewModel viewModel;
  final ScriptCreateViewModel Function() createScriptViewModel;

  @override
  State<ScriptListView> createState() => _ScriptListViewState();
}

final class _ScriptListViewState extends State<ScriptListView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  Future<void> _openCreateView() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) =>
            ScriptCreateView(viewModel: widget.createScriptViewModel()),
      ),
    );
  }

  Future<void> _confirmDelete(Script script) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('대본을 삭제할까요?'),
        content: Text('“${script.title}” 대본을 기기에서 삭제합니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await widget.viewModel.deleteScript(script.id);
    if (!deleted && mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('삭제하지 못했습니다'),
          content: const Text('대본은 그대로 유지됩니다. 다시 시도해 주세요.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final addButton = ScriptNavigationButton(
      key: const Key('script-list-add-button'),
      semanticLabel: '새 대본 추가',
      onPressed: _openCreateView,
      child: const Text('추가'),
    );
    final expandedActions = usesExpandedNavigationActions;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, child) {
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('대본'),
                trailing: expandedActions ? null : addButton,
                bottom: expandedActions
                    ? ScriptNavigationActionBar(trailing: addButton)
                    : null,
                bottomMode: expandedActions
                    ? NavigationBarBottomMode.always
                    : null,
              ),
              if (widget.viewModel.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (widget.viewModel.hasLoadError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ScriptLoadError(onRetry: widget.viewModel.retry),
                )
              else if (widget.viewModel.scripts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ScriptEmptyState(onAdd: _openCreateView),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.large,
                  ),
                  sliver: SliverList.builder(
                    itemCount: widget.viewModel.scripts.length,
                    itemBuilder: (context, index) {
                      final script = widget.viewModel.scripts[index];
                      return ScriptListTile(
                        script: script,
                        onDelete: () => _confirmDelete(script),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
