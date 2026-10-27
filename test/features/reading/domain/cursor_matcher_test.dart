import 'package:maltto/src/features/reading/domain/cursor_matcher.dart';
import 'package:test/test.dart';

void main() {
  const script = '오늘 아침에는 창문을 열고 바깥 공기를 천천히 마셨다';

  group('CursorMatcher', () {
    test('정확한 발화를 어절 경계까지 매칭한다', () {
      final matcher = CursorMatcher.fromScript(script);

      expect(matcher.match(hypothesis: '오늘', anchor: 0)?.cursor, 1);
      expect(matcher.match(hypothesis: '오늘 아침에는', anchor: 0)?.cursor, 2);
      expect(matcher.match(hypothesis: '오늘 아침에는 창문을 열고', anchor: 0)?.cursor, 4);
    });

    test('띄어쓰기 차이와 작은 한국어 오인식을 허용한다', () {
      final matcher = CursorMatcher.fromScript(script);

      expect(matcher.match(hypothesis: '오늘아침에는창문을', anchor: 0)?.cursor, 3);
      final mistaken = matcher.match(hypothesis: '오늘 아침에는 창문은 열고', anchor: 0);
      expect(mistaken?.cursor, 4);
      expect(mistaken!.normalizedDistance, lessThan(0.1));
    });

    test('마지막 어절 일부만 발화하면 앞 경계를 유지한다', () {
      final matcher = CursorMatcher.fromScript(script);

      expect(matcher.match(hypothesis: '오늘 아침에는 창', anchor: 0)?.cursor, 2);
    });

    test('무관한 발화와 너무 짧은 발화를 거부한다', () {
      final matcher = CursorMatcher.fromScript(script);

      expect(matcher.match(hypothesis: '점심 메뉴를 고른다', anchor: 0), isNull);
      expect(matcher.match(hypothesis: '오', anchor: 0), isNull);
    });

    test('현재 앵커 이후에서만 반복 어절을 찾는다', () {
      final matcher = CursorMatcher.fromScript('가나다 라마바 가나다 라마바 사아자');

      expect(matcher.match(hypothesis: '가나다 라마바', anchor: 2)?.cursor, 4);
    });

    test('정책의 제한 범위 안에서만 중간 시작을 허용한다', () {
      final matcher = CursorMatcher.fromScript(
        script,
        policy: const MatchingPolicy(maxSkipTokens: 2),
      );

      final within = matcher.match(hypothesis: '창문을 열고 바깥', anchor: 0);
      expect(within?.cursor, 5);
      expect(within?.skippedTokens, 2);
      expect(matcher.match(hypothesis: '천천히 마셨다', anchor: 0), isNull);
    });

    test('반복 어절의 동률에서는 건너뛰지 않는다', () {
      final matcher = CursorMatcher.fromScript('가나다 가나다 가나다 라마바');

      expect(matcher.match(hypothesis: '가나다', anchor: 0)?.skippedTokens, 0);
    });
  });
}
