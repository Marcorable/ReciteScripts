enum ReadingSessionStatus { running, awaitingNextRepetition, completed, exited }

enum ReadingSessionFailure {
  permissionDenied,
  modelUnavailable,
  unsupported,
  audioUnavailable,
  interrupted,
  unknown,
}

final class ReadingSessionState {
  const ReadingSessionState({
    required this.sessionId,
    required this.scriptTitle,
    required this.status,
    required this.currentRepetition,
    required this.totalRepetitions,
    required this.currentWordIndex,
    required this.currentWord,
    required this.words,
    required this.totalWords,
    required this.elapsed,
    required this.generation,
    this.failure,
  });

  final String sessionId;
  final String scriptTitle;
  final ReadingSessionStatus status;
  final int currentRepetition;
  final int totalRepetitions;
  final int? currentWordIndex;
  final String? currentWord;
  final List<String> words;
  final int totalWords;
  final Duration elapsed;
  final ReadingSessionFailure? failure;

  /// 현재 STT 작업만 이 값을 사용한다. 회차 경계와 종료에서 즉시 증가한다.
  final int generation;

  bool get showsRepetition => totalRepetitions > 1;
}

enum ReadingSessionTransition {
  ignored,
  progressed,
  movedBack,
  nextRepetitionStarted,
  recognitionRestarted,
  repetitionCompleted,
  sessionCompleted,
  exited,
}
