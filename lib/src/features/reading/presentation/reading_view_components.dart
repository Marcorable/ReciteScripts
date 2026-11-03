part of 'reading_view.dart';

final class _RunningSession extends StatelessWidget {
  const _RunningSession({
    required this.state,
    required this.reduceMotion,
    required this.onMoveBack,
    required this.onLeave,
  });

  final ReadingSessionState state;
  final bool reduceMotion;
  final Future<void> Function() onMoveBack;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReadingStatus(state: state),
        Expanded(
          child: _ReadingScript(state: state, reduceMotion: reduceMotion),
        ),
        _ReadingControls(
          canMoveBack: (state.currentWordIndex ?? 0) > 0,
          onMoveBack: onMoveBack,
          onLeave: onLeave,
        ),
      ],
    );
  }
}

final class _ReadingStatus extends StatelessWidget {
  const _ReadingStatus({required this.state});

  final ReadingSessionState state;

  @override
  Widget build(BuildContext context) {
    final completedWords = state.currentWordIndex ?? state.totalWords;
    final statusStyle = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.medium,
        AppSpacing.large,
        AppSpacing.small,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.extraLarge,
        runSpacing: AppSpacing.small,
        children: [
          if (state.showsRepetition)
            Semantics(
              label:
                  '현재 ${state.currentRepetition}회차, 전체 ${state.totalRepetitions}회, ${state.totalRepetitions - state.currentRepetition}회 남음',
              excludeSemantics: true,
              child: Text(
                '${state.currentRepetition}/${state.totalRepetitions}회 · '
                '${state.totalRepetitions - state.currentRepetition}회 남음',
                key: const Key('reading-repetition-status'),
                style: statusStyle,
              ),
            ),
          Semantics(
            label: '낭독 진행, 전체 ${state.totalWords}어절 중 $completedWords어절 완료',
            excludeSemantics: true,
            child: Text(
              '$completedWords/${state.totalWords} 어절',
              key: const Key('reading-progress-status'),
              style: statusStyle,
            ),
          ),
          Semantics(
            label: _elapsedSemantics(state.elapsed),
            excludeSemantics: true,
            child: Text(
              _formatElapsed(state.elapsed),
              key: const Key('reading-elapsed-time'),
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ReadingControls extends StatelessWidget {
  const _ReadingControls({
    required this.canMoveBack,
    required this.onMoveBack,
    required this.onLeave,
  });

  final bool canMoveBack;
  final Future<void> Function() onMoveBack;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.small,
        AppSpacing.large,
        AppSpacing.medium,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            enabled: canMoveBack,
            onTap: canMoveBack ? () => unawaited(onMoveBack()) : null,
            label: canMoveBack ? '한 어절 뒤로' : '한 어절 뒤로, 첫 어절에서는 더 이상 이동할 수 없음',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: AppTargets.preferredConstraints,
              child: CupertinoButton(
                key: const Key('reading-move-back-button'),
                padding: EdgeInsets.zero,
                onPressed: canMoveBack ? onMoveBack : null,
                child: const Icon(CupertinoIcons.arrow_uturn_left),
              ),
            ),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.destructiveRed),
              borderRadius: AppRadii.medium,
            ),
            child: Semantics(
              button: true,
              onTap: () => unawaited(onLeave()),
              label: '낭독 나가기',
              hint: '낭독을 종료하고 목록으로 돌아갑니다',
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: AppTargets.preferredConstraints,
                child: CupertinoButton(
                  key: const Key('reading-leave-button'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  onPressed: onLeave,
                  child: const Text(
                    '나가기',
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
