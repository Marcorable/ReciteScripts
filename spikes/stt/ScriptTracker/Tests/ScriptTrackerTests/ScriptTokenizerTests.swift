import Testing
@testable import ScriptTracker

struct ScriptTokenizerTests {
    @Test func splitsOnAnyWhitespace() {
        let tokens = ScriptTokenizer.tokenize("첫째 줄\n둘째\t줄  셋째")
        #expect(tokens.map(\.text) == ["첫째", "줄", "둘째", "줄", "셋째"])
        #expect(tokens.map(\.index) == [0, 1, 2, 3, 4])
    }

    @Test func dropsPunctuationOnlyTokens() {
        let tokens = ScriptTokenizer.tokenize("하나 — 둘 ... 셋")
        #expect(tokens.map(\.text) == ["하나", "둘", "셋"])
    }

    @Test func keepsOriginalTextForDisplay() {
        let tokens = ScriptTokenizer.tokenize("읽었다.")
        #expect(tokens.first?.text == "읽었다.")
    }
}
