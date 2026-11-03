import 'cursor_matcher.dart';
import 'reading_progress.dart';
import 'reading_session.dart';

final class ReadingSessionReducer {
  ReadingSessionReducer({
    required String sessionId,
    required String scriptTitle,
    required String script,
    required int totalRepetitions,
  }) : _sessionId = sessionId,
       _scriptTitle = scriptTitle,
       _totalRepetitions = totalRepetitions,
       _progress = ReadingProgress(matcher: CursorMatcher.fromScript(script)) {
    if (sessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', '비어 있을 수 없습니다.');
    }
    if (scriptTitle.trim().isEmpty) {
      throw ArgumentError.value(scriptTitle, 'scriptTitle', '비어 있을 수 없습니다.');
    }
    if (totalRepetitions < 1) {
      throw RangeError.range(totalRepetitions, 1, null, 'totalRepetitions');
    }
    if (_progress.matcher.tokens.isEmpty) {
      throw ArgumentError.value(script, 'script', '읽을 어절이 필요합니다.');
    }
  }

  final String _sessionId;
  final String _scriptTitle;
  final int _totalRepetitions;
  final ReadingProgress _progress;

  ReadingSessionStatus _status = ReadingSessionStatus.running;
  int _currentRepetition = 1;
  int _generation = 1;
  int _lastSequence = -1;
  Duration _elapsed = Duration.zero;

  ReadingSessionState get state {
    final tokens = _progress.matcher.tokens;
    final currentWordIndex = _progress.cursor < tokens.length
        ? _progress.cursor
        : null;
    return ReadingSessionState(
      sessionId: _sessionId,
      scriptTitle: _scriptTitle,
      status: _status,
      currentRepetition: _currentRepetition,
      totalRepetitions: _totalRepetitions,
      currentWordIndex: currentWordIndex,
      currentWord: currentWordIndex == null
          ? null
          : tokens[currentWordIndex].text,
      words: List.unmodifiable(tokens.map((token) => token.text)),
      totalWords: tokens.length,
      elapsed: _elapsed,
      generation: _generation,
    );
  }

  ReadingSessionTransition acceptTranscript({
    required String sessionId,
    required int generation,
    required int sequence,
    required String text,
    required TranscriptKind kind,
  }) {
    if (_status != ReadingSessionStatus.running ||
        sessionId != _sessionId ||
        generation != _generation ||
        sequence <= _lastSequence) {
      return ReadingSessionTransition.ignored;
    }
    _lastSequence = sequence;

    final update = _progress.acceptTranscript(text, kind);
    if (!update.repetitionCompleted) {
      return update.cursorChanged
          ? ReadingSessionTransition.progressed
          : ReadingSessionTransition.ignored;
    }

    if (_currentRepetition == _totalRepetitions) {
      _status = ReadingSessionStatus.completed;
      _generation++;
      return ReadingSessionTransition.sessionCompleted;
    }

    _currentRepetition++;
    _generation++;
    _lastSequence = -1;
    _progress.resetForNextRepetition();
    return ReadingSessionTransition.repetitionCompleted;
  }

  ReadingSessionTransition updateElapsed(Duration elapsed) {
    if (_status != ReadingSessionStatus.running || elapsed <= _elapsed) {
      return ReadingSessionTransition.ignored;
    }
    _elapsed = elapsed;
    return ReadingSessionTransition.progressed;
  }

  ReadingSessionTransition moveBackOneWord() {
    if (_status != ReadingSessionStatus.running) {
      return ReadingSessionTransition.ignored;
    }
    final update = _progress.moveBackOneWord();
    if (!update.cursorChanged) return ReadingSessionTransition.ignored;

    _generation++;
    _lastSequence = -1;
    _progress.beginNewTranscriptSegment();
    return ReadingSessionTransition.movedBack;
  }

  ReadingSessionTransition restartRecognition({
    required String sessionId,
    required int generation,
    required int sequence,
  }) {
    if (_status != ReadingSessionStatus.running ||
        sessionId != _sessionId ||
        generation != _generation ||
        sequence <= _lastSequence) {
      return ReadingSessionTransition.ignored;
    }
    _generation++;
    _lastSequence = -1;
    _progress.beginNewTranscriptSegment();
    return ReadingSessionTransition.recognitionRestarted;
  }

  ReadingSessionTransition exitAfterRecognitionFailure({
    required String sessionId,
    required int generation,
    required int sequence,
  }) {
    if (_status != ReadingSessionStatus.running ||
        sessionId != _sessionId ||
        generation != _generation ||
        sequence <= _lastSequence) {
      return ReadingSessionTransition.ignored;
    }
    return exit();
  }

  ReadingSessionTransition exit() {
    if (_status != ReadingSessionStatus.running) {
      return ReadingSessionTransition.ignored;
    }
    _status = ReadingSessionStatus.exited;
    _generation++;
    return ReadingSessionTransition.exited;
  }
}
