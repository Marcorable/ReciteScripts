part of 'reading_view.dart';

final class _CompletedSession extends StatelessWidget {
  const _CompletedSession({
    required this.repetitions,
    required this.elapsed,
    required this.onReturn,
  });

  final int repetitions;
  final Duration elapsed;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.extraLarge),
        child: Semantics(
          liveRegion: true,
          container: true,
          label: '낭독 완료, $repetitions회 낭독했습니다. ${_elapsedSemantics(elapsed)}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('완료', style: TextStyle(fontSize: 34)),
              const SizedBox(height: AppSpacing.medium),
              Text('$repetitions회 낭독했습니다.'),
              const SizedBox(height: AppSpacing.small),
              Text(
                _formatElapsed(elapsed),
                key: const Key('reading-completed-elapsed-time'),
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: AppSpacing.section),
              ConstrainedBox(
                constraints: AppTargets.preferredConstraints,
                child: CupertinoButton.filled(
                  key: const Key('reading-completed-return-button'),
                  onPressed: onReturn,
                  child: const Text('목록으로'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ExitedSession extends StatelessWidget {
  const _ExitedSession({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.extraLarge),
        child: Column(
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
        ),
      ),
    );
  }
}

String _formatElapsed(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
      : '$minutes:$seconds';
}

String _elapsedSemantics(Duration elapsed) {
  final parts = <String>[];
  if (elapsed.inHours > 0) parts.add('${elapsed.inHours}시간');
  final minutes = elapsed.inMinutes % 60;
  if (minutes > 0) parts.add('$minutes분');
  parts.add('${elapsed.inSeconds % 60}초');
  return '경과 시간, ${parts.join(' ')}';
}
