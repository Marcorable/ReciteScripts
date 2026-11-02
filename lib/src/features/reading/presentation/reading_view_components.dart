part of 'reading_view.dart';

final class _RunningSession extends StatelessWidget {
  const _RunningSession({required this.state});

  final ReadingSessionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.showsRepetition) ...[
          Semantics(
            label:
                '현재 ${state.currentRepetition}회차, 전체 ${state.totalRepetitions}회',
            child: Text(
              '${state.currentRepetition}/${state.totalRepetitions}회',
              key: const Key('reading-repetition-status'),
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.extraLarge),
        ],
        const Text(
          '현재 어절',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: AppSpacing.medium),
        Semantics(
          label: '현재 어절, ${state.currentWord ?? ''}',
          child: Text(
            state.currentWord ?? '',
            key: const Key('reading-current-word'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.extraLarge),
        Text(
          _formatElapsed(state.elapsed),
          key: const Key('reading-elapsed-time'),
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      ],
    );
  }

  static String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

final class _CompletedSession extends StatelessWidget {
  const _CompletedSession({required this.repetitions, required this.onReturn});

  final int repetitions;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('완료', style: TextStyle(fontSize: 34)),
        const SizedBox(height: AppSpacing.medium),
        Text('$repetitions회 낭독했습니다.'),
        const SizedBox(height: AppSpacing.section),
        ConstrainedBox(
          constraints: AppTargets.preferredConstraints,
          child: CupertinoButton.filled(
            onPressed: onReturn,
            child: const Text('목록으로'),
          ),
        ),
      ],
    );
  }
}

final class _ExitedSession extends StatelessWidget {
  const _ExitedSession({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('낭독 종료', style: TextStyle(fontSize: 34)),
        const SizedBox(height: AppSpacing.section),
        ConstrainedBox(
          constraints: AppTargets.preferredConstraints,
          child: CupertinoButton.filled(
            onPressed: onReturn,
            child: const Text('목록으로'),
          ),
        ),
      ],
    );
  }
}
