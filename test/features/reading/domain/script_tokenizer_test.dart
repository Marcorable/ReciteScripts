import 'package:maltto/src/features/reading/domain/script_tokenizer.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptTokenizer', () {
    test('모든 공백으로 어절을 나누고 문장부호 전용 조각은 버린다', () {
      final tokens = ScriptTokenizer.tokenize('첫째 줄\n둘째\t줄 — 😀 셋째');

      expect(tokens.map((token) => token.text), ['첫째', '줄', '둘째', '줄', '셋째']);
      expect(tokens.map((token) => token.index), [0, 1, 2, 3, 4]);
    });

    test('UTF-16 원문 범위로 표시 텍스트를 그대로 복원한다', () {
      const script = '  맑은 날,\n천천히 읽는다.';
      final tokens = ScriptTokenizer.tokenize(script);

      expect(tokens.map((token) => token.text), ['맑은', '날,', '천천히', '읽는다.']);
      for (final token in tokens) {
        expect(script.substring(token.start, token.end), token.text);
      }
    });
  });
}
