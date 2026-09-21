import Foundation

/// 낭독 한 회차의 커서 상태. STT 결과(확정/미확정)를 받아 커서를 앞으로만 옮긴다.
///
/// - `anchor`: 마지막으로 확정(final) 결과로 고정한 어절 위치. 이후 발화는 여기서부터 정렬한다.
/// - `cursor`: 화면에 보여줄 위치. 미확정(volatile) 결과로도 앞으로 갈 수 있지만 뒤로는 가지 않는다.
/// - `pendingText`: 앵커 이후 확정된 발화. 미확정 발화는 매번 이 뒤에 붙여서 정렬한다.
public struct ReadingSession: Sendable {
    public private(set) var anchor: Int = 0
    public private(set) var cursor: Int = 0
    public private(set) var pendingText: String = ""
    public private(set) var lastDistance: Double?

    public let matcher: CursorMatcher

    /// 확정 발화가 이만큼 쌓여도 매칭되지 않으면 대본을 벗어난 것으로 보고 버린다.
    /// 그렇지 않으면 정렬 비용이 무한히 커지고, 다시 대본으로 돌아와도 따라잡지 못한다.
    public var pendingTextLimit: Int = 120

    public init(matcher: CursorMatcher) {
        self.matcher = matcher
    }

    public var tokens: [ScriptToken] { matcher.tokens }
    public var isComplete: Bool { cursor >= tokens.count }

    /// 미확정 결과. 커서만 앞으로 당기고 앵커는 그대로 둔다.
    @discardableResult
    public mutating func acceptVolatile(_ text: String) -> Int {
        if let match = matcher.match(hypothesis: pendingText + text, anchor: anchor) {
            lastDistance = match.normalizedDistance
            cursor = max(cursor, match.cursor)
        }
        return cursor
    }

    /// 확정 결과. 매칭되면 앵커를 옮기고 대기 발화를 비운다.
    /// 매칭 실패 시 발화를 대기열에 남겨 다음 확정 결과와 합쳐 다시 시도한다.
    @discardableResult
    public mutating func acceptFinal(_ text: String) -> Int {
        pendingText += text
        if let match = matcher.match(hypothesis: pendingText, anchor: anchor) {
            lastDistance = match.normalizedDistance
            cursor = max(cursor, match.cursor)
            anchor = cursor
            pendingText = ""
        } else if TextNormalizer.units(pendingText).count > pendingTextLimit {
            anchor = cursor
            pendingText = ""
        }
        return cursor
    }

    /// 수동 넘김 폴백. 한 어절 앞으로.
    public mutating func advanceManually() {
        guard cursor < tokens.count else { return }
        cursor += 1
        anchor = cursor
        pendingText = ""
    }

    public mutating func reset() {
        anchor = 0
        cursor = 0
        pendingText = ""
        lastDistance = nil
    }
}
