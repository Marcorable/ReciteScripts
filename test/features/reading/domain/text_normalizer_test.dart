import 'package:maltto/src/features/reading/domain/text_normalizer.dart';
import 'package:test/test.dart';

void main() {
  group('TextNormalizer', () {
    test('공백과 문장부호를 제거하고 영문 대소문자를 통일한다', () {
      expect(
        TextNormalizer.units('새 문장, ABC!'),
        TextNormalizer.units('새문장abc'),
      );
    });

    test('한글 음절을 자모 단위로 분해한다', () {
      expect(TextNormalizer.units('가'), hasLength(2));
      expect(TextNormalizer.units('각'), hasLength(3));
    });

    test('STT의 아라비아 숫자를 한글 수 읽기로 바꾼다', () {
      expect(TextNormalizer.units('10분'), TextNormalizer.units('십 분'));
      expect(TextNormalizer.units('203번'), TextNormalizer.units('이백삼 번'));
    });
  });
}
