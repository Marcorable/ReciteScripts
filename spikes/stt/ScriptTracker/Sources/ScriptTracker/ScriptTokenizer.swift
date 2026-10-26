import Foundation

/// 대본의 어절 하나. `units`는 정규화된 비교 단위(자모)다.
public struct ScriptToken: Equatable, Sendable {
    public let index: Int
    public let text: String
    public let units: [Unicode.Scalar]

    public init(index: Int, text: String) {
        self.index = index
        self.text = text
        self.units = TextNormalizer.units(text)
    }
}

/// 대본을 공백 기준 어절로 나눈다. 정규화 후 비어 버리는 어절(문장부호만 있는 것)은 버린다.
public enum ScriptTokenizer {
    public static func tokenize(_ script: String) -> [ScriptToken] {
        var tokens: [ScriptToken] = []
        for word in script.split(whereSeparator: \.isWhitespace) {
            let candidate = ScriptToken(index: tokens.count, text: String(word))
            guard !candidate.units.isEmpty else { continue }
            tokens.append(candidate)
        }
        return tokens
    }
}
