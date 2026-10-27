import 'package:maltto/src/features/reading/domain/cursor_matcher.dart';
import 'package:maltto/src/features/reading/domain/reading_progress.dart';
import 'package:test/test.dart';

void main() {
  const script = '오늘 아침에는 창문을 열고 바깥 공기를 천천히 마셨다';

  ReadingProgress createProgress({int pendingFinalUnitLimit = 120}) {
    return ReadingProgress(
      matcher: CursorMatcher.fromScript(script),
      pendingFinalUnitLimit: pendingFinalUnitLimit,
    );
  }

  group('ReadingProgress', () {
    test('partial은 커서만 진행하고 final은 앵커를 확정한다', () {
      final progress = createProgress();

      progress.acceptTranscript('오늘 아침에는', TranscriptKind.partial);
      expect(progress.cursor, 2);
      expect(progress.anchor, 0);

      progress.acceptTranscript('오늘 아침에는 창문을', TranscriptKind.finalResult);
      expect(progress.cursor, 3);
      expect(progress.anchor, 3);
      expect(progress.pendingFinalText, isEmpty);
    });

    test('partial이 반복되거나 짧게 수정돼도 자동 후퇴하지 않는다', () {
      final progress = createProgress();

      progress.acceptTranscript('오늘 아침에는 창문을 열고', TranscriptKind.partial);
      progress.acceptTranscript('오늘 아침에는 창문을 열고', TranscriptKind.partial);
      progress.acceptTranscript('오늘 아침', TranscriptKind.partial);

      expect(progress.cursor, 4);
      expect(progress.anchor, 0);
    });

    test('연속 final과 합쳐진 짧은 final을 처리한다', () {
      final progress = createProgress();

      progress.acceptTranscript('오', TranscriptKind.finalResult);
      expect(progress.cursor, 0);
      expect(progress.pendingFinalText, '오');
      progress.acceptTranscript('늘 아침에는', TranscriptKind.finalResult);
      progress.acceptTranscript('창문을 열고', TranscriptKind.finalResult);

      expect(progress.cursor, 4);
      expect(progress.anchor, 4);
    });

    test('긴 무관 발화를 버린 뒤 대본으로 복귀한다', () {
      final progress = createProgress(pendingFinalUnitLimit: 10);

      progress.acceptTranscript(
        '전혀 다른 이야기를 길게 합니다',
        TranscriptKind.finalResult,
      );
      expect(progress.cursor, 0);
      expect(progress.pendingFinalText, isEmpty);
      progress.acceptTranscript('오늘 아침에는', TranscriptKind.finalResult);
      expect(progress.cursor, 2);
    });

    test('명시적인 한 어절 뒤로 명령만 커서를 감소시킨다', () {
      final progress = createProgress();
      progress.acceptTranscript('오늘 아침에는 창문을', TranscriptKind.finalResult);

      final update = progress.moveBackOneWord();

      expect(update.previousCursor, 3);
      expect(update.cursor, 2);
      expect(progress.anchor, 2);
      progress.moveBackOneWord();
      progress.moveBackOneWord();
      final atStart = progress.moveBackOneWord();
      expect(atStart.cursor, 0);
      expect(atStart.cursorChanged, isFalse);
    });

    test('마지막 어절 완료 이벤트를 한 번만 만든다', () {
      final progress = createProgress();

      final completed = progress.acceptTranscript(
        script,
        TranscriptKind.partial,
      );
      final duplicate = progress.acceptTranscript(
        script,
        TranscriptKind.finalResult,
      );

      expect(progress.isComplete, isTrue);
      expect(completed.repetitionCompleted, isTrue);
      expect(duplicate.repetitionCompleted, isFalse);
    });

    test('반복 경계에서 전사 상태와 커서를 초기화한다', () {
      final progress = createProgress();
      progress.acceptTranscript(script, TranscriptKind.finalResult);

      progress.resetForNextRepetition();
      final next = progress.acceptTranscript('오늘 아침에는', TranscriptKind.partial);

      expect(next.cursor, 2);
      expect(progress.anchor, 0);
      expect(progress.pendingFinalText, isEmpty);
    });
  });
}
