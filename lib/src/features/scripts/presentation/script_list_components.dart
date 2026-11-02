import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

final class ScriptEmptyState extends StatelessWidget {
  const ScriptEmptyState({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.extraLarge),
        child: Semantics(
          container: true,
          label: '저장된 대본 없음',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('저장된 대본이 없습니다.', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.extraLarge),
              ConstrainedBox(
                constraints: AppTargets.preferredConstraints,
                child: CupertinoButton.filled(
                  onPressed: onAdd,
                  child: const Text('대본 추가'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class ScriptLoadError extends StatelessWidget {
  const ScriptLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.extraLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('대본을 불러오지 못했습니다.', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.extraLarge),
            ConstrainedBox(
              constraints: AppTargets.preferredConstraints,
              child: CupertinoButton.filled(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class ScriptListTile extends StatelessWidget {
  const ScriptListTile({
    required this.script,
    required this.onSelected,
    required this.onDelete,
    super.key,
  });

  final Script script;
  final VoidCallback onSelected;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final separatorHeight = 1 / MediaQuery.devicePixelRatioOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(color: CupertinoColors.systemBackground),
      child: Column(
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: '대본 제목, ${script.title}',
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.large,
                right: AppSpacing.small,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.large,
                      ),
                      alignment: Alignment.centerLeft,
                      onPressed: onSelected,
                      child: Semantics(
                        button: true,
                        label: '대본 ${script.title} 선택',
                        excludeSemantics: true,
                        child: Text(script.title),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  SizedBox.square(
                    dimension: AppTargets.preferred,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onDelete,
                      child: Semantics(
                        button: true,
                        label: '대본 ${script.title} 삭제',
                        excludeSemantics: true,
                        child: const Icon(
                          CupertinoIcons.delete,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: separatorHeight,
            margin: const EdgeInsets.only(left: AppSpacing.large),
            color: CupertinoColors.separator,
          ),
        ],
      ),
    );
  }
}
