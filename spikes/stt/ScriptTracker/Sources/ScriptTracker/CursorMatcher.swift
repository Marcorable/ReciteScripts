import Foundation

/// STT 전사 결과를 대본 어절 커서에 정렬한다.
///
/// 설계 원칙 (AGENTS.md 7번 P1):
/// - 커서는 앞으로만 간다.
/// - 전체 대본에서 위치를 검색하지 않는다. 앵커(마지막으로 확정된 위치) 이후 어절과만 비교한다.
/// - 공백 기준이 아니라 자모 스트림 기준으로 정렬한다. 한국어 STT 띄어쓰기는 대본과 다를 수 있기 때문이다.
///
/// 동작:
/// 1. 앵커 이후 대본 어절들을 이어 붙인 자모열 S와, 앵커 이후 발화 자모열 H를 편집거리 DP로 정렬한다.
/// 2. DP 마지막 행에서 각 어절 경계 e에 대해 `distance(H, S[..<e])`를 한 번에 얻는다.
/// 3. 정규화 거리(= 거리 / max(|H|, |S[..<e]|))가 가장 작은 경계를 고르고, 임계값 이내이면 커서를 그곳으로 옮긴다.
public struct CursorMatcher: Sendable {
    public struct Configuration: Sendable {
        /// 이 값 이하의 정규화 거리만 매칭으로 인정한다. 0 = 완전 일치, 1 = 완전 불일치.
        public var maxNormalizedDistance: Double
        /// 발화 자모열 대비 대본 탐색 범위 배율. 오인식으로 발화가 길어져도 따라잡을 수 있게 여유를 둔다.
        public var lookaheadRatio: Double
        /// 발화 길이와 무관하게 최소한 이만큼의 어절은 탐색한다.
        public var minimumLookaheadTokens: Int
        /// 발화 자모 수가 이보다 적으면 매칭하지 않는다(짧은 잡음으로 커서가 튀는 것을 막는다).
        public var minimumHypothesisUnits: Int
        /// 앵커 이후 이만큼의 어절은 건너뛰고 시작하는 것을 허용한다.
        /// 중간부터 읽거나 한 줄을 빼먹었을 때 커서가 오래 멈추는 것을 막는다(실기기 관찰: 5어절 건너뛰자 14어절 동안 정지).
        public var maxSkipTokens: Int
        /// 건너뛴 매칭은 건너뛰지 않은 매칭보다 이만큼 더 좋아야 채택한다(동률이면 건너뛰지 않는 쪽).
        public var skipPenalty: Double

        public init(
            maxNormalizedDistance: Double = 0.45,
            lookaheadRatio: Double = 1.6,
            minimumLookaheadTokens: Int = 4,
            minimumHypothesisUnits: Int = 3,
            maxSkipTokens: Int = 6,
            skipPenalty: Double = 0.05
        ) {
            self.maxNormalizedDistance = maxNormalizedDistance
            self.lookaheadRatio = lookaheadRatio
            self.minimumLookaheadTokens = minimumLookaheadTokens
            self.minimumHypothesisUnits = minimumHypothesisUnits
            self.maxSkipTokens = maxSkipTokens
            self.skipPenalty = skipPenalty
        }
    }

    public struct Match: Equatable, Sendable {
        /// 매칭된 마지막 어절 다음 인덱스. 즉 `tokens[..<cursor]`를 읽은 것으로 본다.
        public let cursor: Int
        public let normalizedDistance: Double
        /// 앵커에서 건너뛴 어절 수. 0이면 앵커 바로 다음부터 읽은 것이다.
        public let skippedTokens: Int
    }

    public let tokens: [ScriptToken]
    public let configuration: Configuration

    public init(tokens: [ScriptToken], configuration: Configuration = .init()) {
        self.tokens = tokens
        self.configuration = configuration
    }

    public init(script: String, configuration: Configuration = .init()) {
        self.init(tokens: ScriptTokenizer.tokenize(script), configuration: configuration)
    }

    /// `anchor` 이후 어절들에 `hypothesis`를 정렬해 새 커서를 제안한다.
    /// 매칭이 임계값을 넘지 못하면 nil을 돌려주고, 호출자는 커서를 유지한다.
    public func match(hypothesis: String, anchor: Int) -> Match? {
        let hypothesisUnits = TextNormalizer.units(hypothesis)
        guard hypothesisUnits.count >= configuration.minimumHypothesisUnits else { return nil }
        guard anchor < tokens.count else { return nil }

        var best: Match?
        for skipped in 0...configuration.maxSkipTokens {
            let start = anchor + skipped
            guard start < tokens.count else { break }
            guard let candidate = alignFrom(start: start, skipped: skipped, hypothesisUnits: hypothesisUnits) else { continue }
            // 건너뛴 매칭은 페널티를 얹어 비교한다. 같은 품질이면 건너뛰지 않은 쪽이 이긴다.
            let candidateScore = candidate.normalizedDistance + (skipped > 0 ? configuration.skipPenalty : 0)
            let bestScore = best.map { $0.normalizedDistance + ($0.skippedTokens > 0 ? configuration.skipPenalty : 0) }
            if bestScore == nil || candidateScore < bestScore! {
                best = candidate
            }
        }
        guard let best, best.normalizedDistance <= configuration.maxNormalizedDistance else { return nil }
        return best
    }

    /// `start` 어절부터 발화 길이의 lookaheadRatio 배까지 이어 붙여 정렬하고, 가장 좋은 어절 경계를 고른다.
    private func alignFrom(start: Int, skipped: Int, hypothesisUnits: [Unicode.Scalar]) -> Match? {
        let unitBudget = Int(Double(hypothesisUnits.count) * configuration.lookaheadRatio)
        var scriptUnits: [Unicode.Scalar] = []
        var boundaries: [(tokenEnd: Int, unitEnd: Int)] = []
        var index = start
        while index < tokens.count {
            let token = tokens[index]
            let withinBudget = scriptUnits.count + token.units.count <= unitBudget
            let withinMinimum = index - start < configuration.minimumLookaheadTokens
            guard withinBudget || withinMinimum else { break }
            scriptUnits.append(contentsOf: token.units)
            boundaries.append((tokenEnd: index + 1, unitEnd: scriptUnits.count))
            index += 1
        }
        guard !boundaries.isEmpty else { return nil }

        let lastRow = EditDistance.lastRow(source: hypothesisUnits, target: scriptUnits)

        var best: Match?
        for boundary in boundaries {
            let distance = Double(lastRow[boundary.unitEnd])
            let length = Double(max(hypothesisUnits.count, boundary.unitEnd))
            let normalized = distance / length
            if best == nil || normalized < best!.normalizedDistance {
                best = Match(cursor: boundary.tokenEnd, normalizedDistance: normalized, skippedTokens: skipped)
            }
        }
        return best
    }
}

/// 편집거리(Levenshtein) DP. 마지막 행만 돌려준다: `row[j] = distance(source, target[..<j])`.
enum EditDistance {
    static func lastRow(source: [Unicode.Scalar], target: [Unicode.Scalar]) -> [Int] {
        var previous = Array(0...target.count)
        guard !source.isEmpty, !target.isEmpty else {
            return source.isEmpty ? previous : previous.map { _ in source.count }
        }
        var current = [Int](repeating: 0, count: target.count + 1)
        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let cost = source[i - 1] == target[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,          // 삭제
                    current[j - 1] + 1,       // 삽입
                    previous[j - 1] + cost    // 치환
                )
            }
            swap(&previous, &current)
        }
        return previous
    }
}
