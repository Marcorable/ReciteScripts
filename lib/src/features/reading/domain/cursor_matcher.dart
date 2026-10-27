import 'script_tokenizer.dart';
import 'text_normalizer.dart';

final class MatchingPolicy {
  const MatchingPolicy({
    this.maxNormalizedDistance = 0.45,
    this.lookaheadRatio = 1.6,
    this.minimumLookaheadTokens = 4,
    this.minimumHypothesisUnits = 3,
    this.maxSkipTokens = 6,
    this.skipPenalty = 0.05,
  }) : assert(maxNormalizedDistance >= 0 && maxNormalizedDistance <= 1),
       assert(lookaheadRatio > 0),
       assert(minimumLookaheadTokens > 0),
       assert(minimumHypothesisUnits > 0),
       assert(maxSkipTokens >= 0),
       assert(skipPenalty >= 0);

  final double maxNormalizedDistance;
  final double lookaheadRatio;
  final int minimumLookaheadTokens;
  final int minimumHypothesisUnits;
  final int maxSkipTokens;
  final double skipPenalty;
}

final class CursorMatch {
  const CursorMatch({
    required this.cursor,
    required this.normalizedDistance,
    required this.skippedTokens,
    required this.matchedUnitCount,
  });

  final int cursor;
  final double normalizedDistance;
  final int skippedTokens;
  final int matchedUnitCount;
}

/// 현재 확정 앵커 이후의 제한된 구간만 자모 편집거리로 비교한다.
final class CursorMatcher {
  CursorMatcher({
    required List<ScriptToken> tokens,
    this.policy = const MatchingPolicy(),
  }) : tokens = List.unmodifiable(tokens);

  factory CursorMatcher.fromScript(
    String script, {
    MatchingPolicy policy = const MatchingPolicy(),
  }) => CursorMatcher(tokens: ScriptTokenizer.tokenize(script), policy: policy);

  final List<ScriptToken> tokens;
  final MatchingPolicy policy;

  CursorMatch? match({required String hypothesis, required int anchor}) {
    final hypothesisUnits = TextNormalizer.units(hypothesis);
    if (anchor < 0 || anchor >= tokens.length) {
      return null;
    }
    if (hypothesisUnits.length < policy.minimumHypothesisUnits) {
      final currentUnits = tokens[anchor].units;
      return _unitsEqual(hypothesisUnits, currentUnits)
          ? CursorMatch(
              cursor: anchor + 1,
              normalizedDistance: 0,
              skippedTokens: 0,
              matchedUnitCount: currentUnits.length,
            )
          : null;
    }

    CursorMatch? best;
    for (var skipped = 0; skipped <= policy.maxSkipTokens; skipped++) {
      final start = anchor + skipped;
      if (start >= tokens.length) break;
      final candidate = _alignFrom(start, skipped, hypothesisUnits);
      final candidateScore =
          candidate.normalizedDistance +
          (skipped == 0 ? 0 : policy.skipPenalty);
      final bestScore = best == null
          ? double.infinity
          : best.normalizedDistance +
                (best.skippedTokens == 0 ? 0 : policy.skipPenalty);
      if (candidateScore < bestScore) best = candidate;
    }

    return best != null &&
            best.normalizedDistance <= policy.maxNormalizedDistance
        ? best
        : null;
  }

  CursorMatch _alignFrom(int start, int skipped, List<int> hypothesis) {
    final unitBudget = (hypothesis.length * policy.lookaheadRatio).floor();
    final scriptUnits = <int>[];
    final boundaries = <({int cursor, int unitEnd})>[];
    for (var index = start; index < tokens.length; index++) {
      final units = tokens[index].units;
      final withinBudget = scriptUnits.length + units.length <= unitBudget;
      final withinMinimum = index - start < policy.minimumLookaheadTokens;
      if (!withinBudget && !withinMinimum) break;
      scriptUnits.addAll(units);
      boundaries.add((cursor: index + 1, unitEnd: scriptUnits.length));
    }

    final distances = _lastEditDistanceRow(hypothesis, scriptUnits);
    CursorMatch? best;
    for (final boundary in boundaries) {
      final distance = distances[boundary.unitEnd];
      final normalized =
          distance /
          (hypothesis.length > boundary.unitEnd
              ? hypothesis.length
              : boundary.unitEnd);
      if (best == null || normalized < best.normalizedDistance) {
        best = CursorMatch(
          cursor: boundary.cursor,
          normalizedDistance: normalized,
          skippedTokens: skipped,
          matchedUnitCount: boundary.unitEnd,
        );
      }
    }
    return best!;
  }

  static List<int> _lastEditDistanceRow(List<int> source, List<int> target) {
    var previous = List<int>.generate(target.length + 1, (index) => index);
    var current = List<int>.filled(target.length + 1, 0);
    for (var sourceIndex = 1; sourceIndex <= source.length; sourceIndex++) {
      current[0] = sourceIndex;
      for (var targetIndex = 1; targetIndex <= target.length; targetIndex++) {
        final substitution = source[sourceIndex - 1] == target[targetIndex - 1]
            ? 0
            : 1;
        current[targetIndex] = _minimum(
          previous[targetIndex] + 1,
          current[targetIndex - 1] + 1,
          previous[targetIndex - 1] + substitution,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous;
  }

  static int _minimum(int first, int second, int third) {
    final pair = first < second ? first : second;
    return pair < third ? pair : third;
  }

  static bool _unitsEqual(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
