import 'text_normalizer.dart';

/// [start]와 [end]는 원문 String의 UTF-16 오프셋이며 [end]는 범위 밖이다.
final class ScriptToken {
  const ScriptToken({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
    required this.units,
  });

  final int index;
  final String text;
  final int start;
  final int end;
  final List<int> units;
}

abstract final class ScriptTokenizer {
  static final RegExp _word = RegExp(r'\S+', unicode: true);

  /// 모든 공백을 경계로 나누고, 표시용 원문과 원문 범위를 보존한다.
  /// 정규화 뒤 비교 단위가 없는 문장부호 전용 조각은 제외한다.
  static List<ScriptToken> tokenize(String script) {
    final tokens = <ScriptToken>[];
    for (final match in _word.allMatches(script)) {
      final text = match.group(0)!;
      final units = TextNormalizer.units(text);
      if (units.isEmpty) continue;
      tokens.add(
        ScriptToken(
          index: tokens.length,
          text: text,
          start: match.start,
          end: match.end,
          units: units,
        ),
      );
    }
    return List.unmodifiable(tokens);
  }
}
