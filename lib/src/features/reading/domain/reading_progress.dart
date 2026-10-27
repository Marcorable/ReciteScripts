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

  int anchor = 0;
  int cursor = 0;
  String _pendingFinalText = '';

  String get pendingFinalText => _pendingFinalText;
  bool get isComplete =>
      matcher.tokens.isNotEmpty && cursor == matcher.tokens.length;

  ReadingProgressUpdate acceptTranscript(String text, TranscriptKind kind) {
    final previous = cursor;
    if (isComplete) return _update(previous);

    if (kind == TranscriptKind.finalResult) {
      _pendingFinalText += text;
      final match = matcher.match(
        hypothesis: _pendingFinalText,
        anchor: anchor,
      );
      if (match != null) {
        cursor = _furthest(cursor, match.cursor);
        anchor = cursor;
        _pendingFinalText = '';
      } else if (TextNormalizer.units(_pendingFinalText).length >
          pendingFinalUnitLimit) {
        anchor = cursor;
        _pendingFinalText = '';
      }
    } else {
      final match = matcher.match(
        hypothesis: _pendingFinalText + text,
        anchor: anchor,
      );
      if (match != null) cursor = _furthest(cursor, match.cursor);
    }
    return _update(previous);
  }

  /// 사용자의 명시적인 한 어절 뒤로 명령만 커서를 감소시킨다.
  ReadingProgressUpdate moveBackOneWord() {
    final previous = cursor;
    if (cursor > 0) cursor--;
    anchor = cursor;
    _pendingFinalText = '';
    return _update(previous);
  }

  /// 상위 반복 세션이 generation을 교체한 뒤 호출할 반복 경계 계약이다.
  void resetForNextRepetition() {
    anchor = 0;
    cursor = 0;
    _pendingFinalText = '';
  }

  ReadingProgressUpdate _update(int previous) => ReadingProgressUpdate(
    previousCursor: previous,
    cursor: cursor,
    repetitionCompleted: previous < matcher.tokens.length && isComplete,
  );

  static int _furthest(int current, int candidate) =>
      current > candidate ? current : candidate;
}
