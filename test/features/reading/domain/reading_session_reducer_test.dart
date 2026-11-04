import 'package:maltto/src/features/reading/domain/reading_progress.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/domain/reading_session_reducer.dart';
import 'package:test/test.dart';

void main() {
  const script = '창문을 열고 천천히 문장을 읽는다';

  ReadingSessionReducer createReducer({int repetitions = 1}) =>
      ReadingSessionReducer(
        sessionId: 'session-1',
        scriptTitle: '낭독 연습',
        script: script,
        totalRepetitions: repetitions,
      );

  group('ReadingSessionReducer', () {
    test('1회 마지막 어절에서 정확히 한 번 완료한다', () {
      final reducer = createReducer();

      final completed = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: script,
        kind: TranscriptKind.partial,
      );
      final duplicateFinal = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 2,
        text: script,
        kind: TranscriptKind.finalResult,
      );

      expect(completed, ReadingSessionTransition.sessionCompleted);
      expect(duplicateFinal, ReadingSessionTransition.ignored);
      expect(reducer.state.status, ReadingSessionStatus.completed);
      expect(reducer.state.generation, 2);
      expect(reducer.state.currentWord, isNull);
    });

    test('여러 회 반복은 새 generation의 대기 상태에서 사용자 결정 후 전환한다', () {
      final reducer = createReducer(repetitions: 2);

      final first = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 4,
        text: script,
        kind: TranscriptKind.finalResult,
      );

      expect(first, ReadingSessionTransition.repetitionCompleted);
      expect(reducer.state.currentRepetition, 2);
      expect(reducer.state.totalRepetitions, 2);
      expect(reducer.state.currentWordIndex, 0);
      expect(reducer.state.currentWord, '창문을');
      expect(reducer.state.generation, 2);
      expect(reducer.state.status, ReadingSessionStatus.awaitingNextRepetition);

      final late = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 2,
        sequence: 1,
        text: script,
        kind: TranscriptKind.finalResult,
      );
      expect(late, ReadingSessionTransition.ignored);
      expect(
        reducer.continueNextRepetition(),
        ReadingSessionTransition.nextRepetitionStarted,
      );
      expect(reducer.state.status, ReadingSessionStatus.running);

      final last = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 2,
        sequence: 2,
        text: script,
        kind: TranscriptKind.finalResult,
      );
      expect(last, ReadingSessionTransition.sessionCompleted);
      expect(reducer.state.status, ReadingSessionStatus.completed);
    });

    test('중복 sequence와 이전 generation 결과를 버린다', () {
      final reducer = createReducer(repetitions: 2);
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 7,
        text: script,
        kind: TranscriptKind.partial,
      );

      final duplicate = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 7,
        text: script,
        kind: TranscriptKind.finalResult,
      );
      final late = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 8,
        text: script,
        kind: TranscriptKind.finalResult,
      );

      expect(duplicate, ReadingSessionTransition.ignored);
      expect(late, ReadingSessionTransition.ignored);
      expect(reducer.state.currentRepetition, 2);
      expect(reducer.state.currentWordIndex, 0);
      expect(reducer.state.status, ReadingSessionStatus.awaitingNextRepetition);
    });

    test('회차 도중 인식 종료는 커서를 유지하고 generation을 교체한다', () {
      final reducer = createReducer();
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: '창문을 열고',
        kind: TranscriptKind.finalResult,
      );
      final cursor = reducer.state.currentWordIndex;

      final restarted = reducer.restartRecognition(
        sessionId: 'session-1',
        generation: 1,
        sequence: 2,
      );
      final late = reducer.restartRecognition(
        sessionId: 'session-1',
        generation: 1,
        sequence: 3,
      );

      expect(restarted, ReadingSessionTransition.recognitionRestarted);
      expect(late, ReadingSessionTransition.ignored);
      expect(reducer.state.status, ReadingSessionStatus.running);
      expect(reducer.state.currentWordIndex, cursor);
      expect(reducer.state.currentRepetition, 1);
      expect(reducer.state.generation, 2);
    });

    test('한 어절 뒤로는 커서 하나와 generation만 교체하고 첫 어절에서 멈춘다', () {
      final reducer = createReducer();
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: '창문을 열고 천천히',
        kind: TranscriptKind.finalResult,
      );

      expect(reducer.moveBackOneWord(), ReadingSessionTransition.movedBack);
      expect(reducer.state.currentWordIndex, 2);
      expect(reducer.state.currentWord, '천천히');
      expect(reducer.state.generation, 2);

      expect(reducer.moveBackOneWord(), ReadingSessionTransition.movedBack);
      expect(reducer.moveBackOneWord(), ReadingSessionTransition.movedBack);
      expect(reducer.state.currentWordIndex, 0);
      final generationAtStart = reducer.state.generation;
      expect(reducer.moveBackOneWord(), ReadingSessionTransition.ignored);
      expect(reducer.state.currentWordIndex, 0);
      expect(reducer.state.generation, generationAtStart);
    });

    test('후퇴 전 generation의 늦은 결과는 무시하고 새 구간에서 진행한다', () {
      final reducer = createReducer();
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: '창문을 열고 천천히',
        kind: TranscriptKind.finalResult,
      );
      reducer.moveBackOneWord();

      final late = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 2,
        text: script,
        kind: TranscriptKind.finalResult,
      );
      final resumed = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 2,
        sequence: 1,
        text: '천천히 문장을 읽는다',
        kind: TranscriptKind.finalResult,
      );

      expect(late, ReadingSessionTransition.ignored);
      expect(resumed, ReadingSessionTransition.sessionCompleted);
      expect(reducer.state.status, ReadingSessionStatus.completed);
    });

    test('partial 진행 후 재시작은 보존된 커서부터 남은 전사를 매칭한다', () {
      const longScript =
          'alpha bravo charlie delta echo foxtrot golf hotel zulu';
      final reducer = ReadingSessionReducer(
        sessionId: 'session-1',
        scriptTitle: '긴 문장 연습',
        script: longScript,
        totalRepetitions: 1,
      );
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: 'alpha bravo charlie delta echo foxtrot golf hotel',
        kind: TranscriptKind.partial,
      );
      expect(reducer.state.currentWordIndex, 8);

      reducer.restartRecognition(
        sessionId: 'session-1',
        generation: 1,
        sequence: 2,
      );
      final completed = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 2,
        sequence: 1,
        text: 'zulu',
        kind: TranscriptKind.finalResult,
      );

      expect(completed, ReadingSessionTransition.sessionCompleted);
      expect(reducer.state.status, ReadingSessionStatus.completed);
    });

    test('현재 generation의 복구 불가 인식 실패는 세션을 종료한다', () {
      final reducer = createReducer();

      final exited = reducer.exitAfterRecognitionFailure(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
      );
      final duplicate = reducer.exitAfterRecognitionFailure(
        sessionId: 'session-1',
        generation: 1,
        sequence: 2,
      );

      expect(exited, ReadingSessionTransition.exited);
      expect(duplicate, ReadingSessionTransition.ignored);
      expect(reducer.state.status, ReadingSessionStatus.exited);
      expect(reducer.state.generation, 2);
    });

    test('나가기는 먼저 종료하고 generation과 이후 상태를 무효화한다', () {
      final reducer = createReducer(repetitions: 3);

      expect(reducer.exit(), ReadingSessionTransition.exited);
      final invalidatedGeneration = reducer.state.generation;
      final late = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: script,
        kind: TranscriptKind.finalResult,
      );
      final elapsed = reducer.updateElapsed(const Duration(seconds: 2));

      expect(reducer.state.status, ReadingSessionStatus.exited);
      expect(invalidatedGeneration, 2);
      expect(late, ReadingSessionTransition.ignored);
      expect(elapsed, ReadingSessionTransition.ignored);
      expect(reducer.state.currentRepetition, 1);
      expect(reducer.exit(), ReadingSessionTransition.ignored);
    });

    test('회차 대기 중 그만하기도 즉시 종료하고 다음 인식을 막는다', () {
      final reducer = createReducer(repetitions: 2);
      reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 1,
        sequence: 1,
        text: script,
        kind: TranscriptKind.finalResult,
      );

      expect(reducer.state.status, ReadingSessionStatus.awaitingNextRepetition);
      expect(reducer.exit(), ReadingSessionTransition.exited);
      expect(reducer.state.status, ReadingSessionStatus.exited);
      expect(
        reducer.continueNextRepetition(),
        ReadingSessionTransition.ignored,
      );
    });
  });
}
