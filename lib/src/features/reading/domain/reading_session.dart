enum ReadingSessionStatus { running, completed, exited }

final class ReadingSessionState {
  const ReadingSessionState({
    required this.sessionId,
    required this.scriptTitle,
    required this.status,
    required this.currentRepetition,
    required this.totalRepetitions,
    required this.currentWordIndex,
    required this.currentWord,
    required this.totalWords,
    required this.elapsed,
    required this.generation,
  });

  final String sessionId;
  final String scriptTitle;
  final ReadingSessionStatus status;
  final int currentRepetition;
  final int totalRepetitions;
  final int? currentWordIndex;
  final String? currentWord;
  final int totalWords;
  final Duration elapsed;

  /// 현재 STT 작업만 이 값을 사용한다. 회차 경계와 종료에서 즉시 증가한다.
  final int generation;

  bool get showsRepetition => totalRepetitions > 1;
}

enum ReadingSessionTransition {
  ignored,
  progressed,
  recognitionRestarted,
  repetitionCompleted,
  sessionCompleted,
  exited,
}
