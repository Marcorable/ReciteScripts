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
  const _ExitedSession({required this.failure, required this.onReturn});

  final ReadingSessionFailure? failure;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.extraLarge),
        child: Semantics(
          liveRegion: failure != null,
          container: true,
          label: failure == null
              ? '낭독 종료'
              : '음성 인식 오류, ${_failureMessage(failure!)}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                failure == null ? '낭독 종료' : '음성 인식을 계속할 수 없습니다',
                key: const Key('reading-exited-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34),
              ),
              if (failure case final failure?) ...[
                const SizedBox(height: AppSpacing.medium),
                Text(
                  _failureMessage(failure),
                  key: const Key('reading-exited-reason'),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              ConstrainedBox(
                constraints: AppTargets.preferredConstraints,
                child: CupertinoButton.filled(
                  key: const Key('reading-exited-return-button'),
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

  String _failureMessage(ReadingSessionFailure failure) => switch (failure) {
    ReadingSessionFailure.permissionDenied =>
      '마이크 또는 음성 인식 권한이 꺼졌습니다. 설정에서 권한을 확인해 주세요.',
    ReadingSessionFailure.modelUnavailable =>
      '온디바이스 한국어 음성 모델을 사용할 수 없습니다. 준비 상태를 다시 확인해 주세요.',
    ReadingSessionFailure.unsupported => '이 기기에서 온디바이스 한국어 음성 인식을 사용할 수 없습니다.',
    ReadingSessionFailure.audioUnavailable =>
      '다른 앱의 마이크 사용이나 오디오 충돌이 감지되었습니다. 방해가 끝난 뒤 다시 시도해 주세요.',
    ReadingSessionFailure.interrupted =>
      '전화나 다른 오디오 작업으로 음성 인식이 중단되었습니다. 방해가 끝난 뒤 다시 시도해 주세요.',
    ReadingSessionFailure.unknown => '일시적인 음성 인식 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
  };
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
