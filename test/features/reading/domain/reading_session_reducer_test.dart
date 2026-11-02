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

    test('여러 회 반복은 새 generation과 첫 어절로 전환한다', () {
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
      expect(reducer.state.status, ReadingSessionStatus.running);

      final last = reducer.acceptTranscript(
        sessionId: 'session-1',
        generation: 2,
        sequence: 1,
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
  });
}
