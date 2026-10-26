import Testing
@testable import ScriptTracker

// 테스트 문장은 모두 직접 쓴 더미다 (AGENTS.md 3번).
struct TextNormalizerTests {
    @Test func removesWhitespaceAndPunctuation() {
        #expect(TextNormalizer.normalize("안녕, 세상아! (반가워)") == TextNormalizer.normalize("안녕세상아반가워"))
    }

    @Test func decomposesHangulIntoJamo() {
        // "가"는 ㄱ + ㅏ 두 자모, "각"은 ㄱ + ㅏ + ㄱ 세 자모.
        #expect(TextNormalizer.units("가").count == 2)
        #expect(TextNormalizer.units("각").count == 3)
    }

    @Test func lowercasesLatin() {
        #expect(TextNormalizer.normalize("ABC") == "abc")
    }

    @Test func keepsDigits() {
        #expect(TextNormalizer.normalize("3번째 줄") == "3번째줄".decomposedStringWithCanonicalMapping)
    }
}
