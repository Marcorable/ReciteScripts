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

    test('짧아진 final은 partial 커서가 아닌 확정 경계까지만 앵커를 옮긴다', () {
      final progress = createProgress();
      progress.acceptTranscript('오늘 아침에는 창문을 열고', TranscriptKind.partial);

      progress.acceptTranscript('오늘', TranscriptKind.finalResult);
      expect(progress.cursor, 4);
      expect(progress.anchor, 1);

      progress.acceptTranscript('아침에는 창문을 열고', TranscriptKind.finalResult);
      expect(progress.cursor, 4);
      expect(progress.anchor, 4);
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

    test('불일치 final을 폐기해도 partial 커서를 확정하지 않는다', () {
      final progress = createProgress(pendingFinalUnitLimit: 10);
      progress.acceptTranscript('오늘 아침에는 창문을 열고', TranscriptKind.partial);

      progress.acceptTranscript(
        '전혀 다른 이야기를 길게 합니다',
        TranscriptKind.finalResult,
      );

      expect(progress.cursor, 4);
      expect(progress.anchor, 0);
      expect(progress.pendingFinalText, isEmpty);
    });

    test('불일치 final 누적 뒤 새 final 단독 매칭으로 복귀한다', () {
      final progress = createProgress();
      progress.acceptTranscript(
        '오늘 아침에는 창문을 열고 바깥 공기를 천천히',
        TranscriptKind.finalResult,
      );
      expect(progress.cursor, 7);

      progress.acceptTranscript('점심 메뉴를 고른다', TranscriptKind.finalResult);
      final completed = progress.acceptTranscript(
        '마셨다',
        TranscriptKind.finalResult,
      );

      expect(completed.cursor, 8);
      expect(completed.repetitionCompleted, isTrue);
      expect(progress.pendingFinalText, isEmpty);
    });

    test('명시적인 한 어절 뒤로 명령만 커서를 감소시킨다', () {
      final progress = createProgress();
      progress.acceptTranscript('오늘 아침에는 창문을', TranscriptKind.finalResult);

      final update = progress.moveBackOneWord();

      expect(update.previousCursor, 3);
      expect(update.cursor, 2);
      expect(progress.anchor, 2);
      expect(progress.requiresTranscriptReset, isTrue);
      progress.moveBackOneWord();
      progress.moveBackOneWord();
      final atStart = progress.moveBackOneWord();
      expect(atStart.cursor, 0);
      expect(atStart.cursorChanged, isFalse);
    });

    test('후퇴 전 전사는 무시하고 새 전사 구간에서 추적을 재개한다', () {
      final progress = createProgress();
      progress.acceptTranscript(
        '오늘 아침에는 창문을 열고 바깥 공기를 천천히',
        TranscriptKind.partial,
      );
      progress.moveBackOneWord();

      final stale = progress.acceptTranscript(script, TranscriptKind.partial);
      expect(stale.cursor, 6);
      expect(stale.cursorChanged, isFalse);

      progress.beginNewTranscriptSegment();
      final resumed = progress.acceptTranscript(
        '천천히 마셨다',
        TranscriptKind.finalResult,
      );
      expect(resumed.cursor, 8);
      expect(resumed.repetitionCompleted, isTrue);
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

    test('짧은 단일 어절도 정확히 읽으면 완료한다', () {
      final progress = ReadingProgress(matcher: CursorMatcher.fromScript('나'));

      final completed = progress.acceptTranscript(
        '나',
        TranscriptKind.finalResult,
      );

      expect(completed.cursor, 1);
      expect(completed.repetitionCompleted, isTrue);
      expect(progress.isComplete, isTrue);
    });

    test('마지막 어절의 미완성 partial은 완료하지 않는다', () {
      final progress = ReadingProgress(
        matcher: CursorMatcher.fromScript('마셨다'),
      );

      final partial = progress.acceptTranscript('마셨', TranscriptKind.partial);
      final completed = progress.acceptTranscript(
        '마셨다',
        TranscriptKind.finalResult,
      );

      expect(partial.cursor, 0);
      expect(partial.repetitionCompleted, isFalse);
      expect(completed.cursor, 1);
      expect(completed.repetitionCompleted, isTrue);
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
