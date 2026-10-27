import 'cursor_matcher.dart';
import 'text_normalizer.dart';

enum TranscriptKind { partial, finalResult }

final class ReadingProgressUpdate {
  const ReadingProgressUpdate({
    required this.previousCursor,
    required this.cursor,
    required this.repetitionCompleted,
  });

  final int previousCursor;
  final int cursor;

  /// 이번 적용으로 마지막 어절에 처음 도달했을 때만 true다.
  final bool repetitionCompleted;

  bool get cursorChanged => previousCursor != cursor;
}

/// 한 반복 안의 전사 진행 상태다. 다음 반복 시작 결정은 상위 세션이 맡는다.
final class ReadingProgress {
  ReadingProgress({required this.matcher, this.pendingFinalUnitLimit = 120})
    : assert(pendingFinalUnitLimit > 0);

  final CursorMatcher matcher;
  final int pendingFinalUnitLimit;

  int _anchor = 0;
  int _cursor = 0;
  String _pendingFinalText = '';
  bool _requiresTranscriptReset = false;

  int get anchor => _anchor;
  int get cursor => _cursor;
  String get pendingFinalText => _pendingFinalText;
  bool get requiresTranscriptReset => _requiresTranscriptReset;
  bool get isComplete =>
      matcher.tokens.isNotEmpty && _cursor == matcher.tokens.length;

  ReadingProgressUpdate acceptTranscript(String text, TranscriptKind kind) {
    final previous = _cursor;
    if (isComplete || _requiresTranscriptReset) return _update(previous);

    if (kind == TranscriptKind.finalResult) {
      final previousPendingText = _pendingFinalText;
      _pendingFinalText += text;
      var match = matcher.match(hypothesis: _pendingFinalText, anchor: _anchor);
      if (match == null && previousPendingText.isNotEmpty) {
        match = matcher.match(hypothesis: text, anchor: _anchor);
      }
      if (match != null) {
        _cursor = _furthest(_cursor, match.cursor);
        _anchor = _cursor;
        _pendingFinalText = '';
      } else if (TextNormalizer.units(_pendingFinalText).length >
          pendingFinalUnitLimit) {
        _anchor = _cursor;
        _pendingFinalText = '';
      }
    } else {
      final hypothesis = _pendingFinalText + text;
      final match = matcher.match(hypothesis: hypothesis, anchor: _anchor);
      final stopsBeforeLastTokenEnds =
          match != null &&
          match.cursor == matcher.tokens.length &&
          TextNormalizer.units(hypothesis).length < match.matchedUnitCount;
      if (match != null && !stopsBeforeLastTokenEnds) {
        _cursor = _furthest(_cursor, match.cursor);
      }
    }
    return _update(previous);
  }

  /// 사용자의 명시적인 한 어절 뒤로 명령만 커서를 감소시킨다.
  /// 호출자는 STT generation을 교체한 뒤 [beginNewTranscriptSegment]를 호출한다.
  ReadingProgressUpdate moveBackOneWord() {
    final previous = _cursor;
    if (_cursor > 0) _cursor--;
    _anchor = _cursor;
    _pendingFinalText = '';
    _requiresTranscriptReset = true;
    return _update(previous);
  }

  /// 후퇴 전에 시작된 늦은 전사 이벤트를 모두 폐기한 뒤 새 구간을 연다.
  void beginNewTranscriptSegment() {
    _pendingFinalText = '';
    _requiresTranscriptReset = false;
  }

  /// 상위 반복 세션이 generation을 교체한 뒤 호출할 반복 경계 계약이다.
  void resetForNextRepetition() {
    _anchor = 0;
    _cursor = 0;
    _pendingFinalText = '';
    _requiresTranscriptReset = false;
  }

  ReadingProgressUpdate _update(int previous) => ReadingProgressUpdate(
    previousCursor: previous,
    cursor: _cursor,
    repetitionCompleted: previous < matcher.tokens.length && isComplete,
  );

  static int _furthest(int current, int candidate) =>
      current > candidate ? current : candidate;
}
