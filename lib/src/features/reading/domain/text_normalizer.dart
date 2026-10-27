/// STT 전사와 대본을 같은 비교 단위로 바꾸는 순수 Dart 정규화기다.
abstract final class TextNormalizer {
  static final RegExp _digitRun = RegExp(r'[0-9]+');

  /// 공백·문장부호·기호를 제거하고 영문은 소문자, 숫자는 한글 읽기로
  /// 바꾼 뒤 한글 음절을 초성·중성·종성 코드 포인트로 분해한다.
  static List<int> units(String text) {
    final expanded = text.replaceAllMapped(
      _digitRun,
      (match) => _readNumber(match.group(0)!),
    );
    final result = <int>[];

    for (final rune in expanded.toLowerCase().runes) {
      if (_isIgnored(rune)) continue;
      if (rune >= 0xac00 && rune <= 0xd7a3) {
        final offset = rune - 0xac00;
        result
          ..add(0x1100 + offset ~/ 588)
          ..add(0x1161 + (offset % 588) ~/ 28);
        final trailing = offset % 28;
        if (trailing != 0) result.add(0x11a7 + trailing);
      } else {
        result.add(rune);
      }
    }
    return List.unmodifiable(result);
  }

  static bool _isIgnored(int rune) {
    return rune <= 0x20 ||
        (rune >= 0x21 && rune <= 0x2f) ||
        (rune >= 0x3a && rune <= 0x40) ||
        (rune >= 0x5b && rune <= 0x60) ||
        (rune >= 0x7b && rune <= 0x7e) ||
        (rune >= 0x20a0 && rune <= 0x20cf) ||
        (rune >= 0x2100 && rune <= 0x2bff) ||
        (rune >= 0x2000 && rune <= 0x206f) ||
        (rune >= 0x3000 && rune <= 0x303f) ||
        (rune >= 0x1f000 && rune <= 0x1faff) ||
        (rune >= 0xff01 && rune <= 0xff0f) ||
        (rune >= 0xff1a && rune <= 0xff20) ||
        (rune >= 0xff3b && rune <= 0xff40) ||
        (rune >= 0xff5b && rune <= 0xff65);
  }

  static String _readNumber(String digits) {
    if (digits.length > 4 || (digits.length > 1 && digits.startsWith('0'))) {
      return digits.split('').map(_digitName).join();
    }

    final value = int.parse(digits);
    if (value == 0) return '영';
    const units = ['', '십', '백', '천'];
    final buffer = StringBuffer();
    var remaining = value;
    for (var position = 3; position >= 0; position--) {
      final divisor = _powerOfTen(position);
      final digit = remaining ~/ divisor;
      remaining %= divisor;
      if (digit == 0) continue;
      if (digit != 1 || position == 0) buffer.write(_digitName('$digit'));
      buffer.write(units[position]);
    }
    return buffer.toString();
  }

  static int _powerOfTen(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  static String _digitName(String digit) => const {
    '0': '영',
    '1': '일',
    '2': '이',
    '3': '삼',
    '4': '사',
    '5': '오',
    '6': '육',
    '7': '칠',
    '8': '팔',
    '9': '구',
  }[digit]!;
}
