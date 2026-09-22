import Testing
@testable import ScriptTracker

struct CursorMatcherTests {
    let script = "오늘 아침에는 창문을 열고 바깥 공기를 천천히 마셨다"

    @Test func exactPrefixAdvancesTokenByToken() {
        let matcher = CursorMatcher(script: script)
        #expect(matcher.match(hypothesis: "오늘", anchor: 0)?.cursor == 1)
        #expect(matcher.match(hypothesis: "오늘 아침에는", anchor: 0)?.cursor == 2)
        #expect(matcher.match(hypothesis: "오늘 아침에는 창문을 열고", anchor: 0)?.cursor == 4)
    }

    @Test func ignoresSpacingDifferences() {
        let matcher = CursorMatcher(script: script)
        // STT가 띄어쓰기를 다르게 해도 자모열은 같다.
        #expect(matcher.match(hypothesis: "오늘아침에는창문을", anchor: 0)?.cursor == 3)
        #expect(matcher.match(hypothesis: "오 늘 아 침 에 는", anchor: 0)?.cursor == 2)
    }

    @Test func toleratesSmallMisrecognition() {
        let matcher = CursorMatcher(script: script)
        // "창문을" → "창문은": 자모 하나 차이.
        let match = matcher.match(hypothesis: "오늘 아침에는 창문은 열고", anchor: 0)
        #expect(match?.cursor == 4)
        #expect((match?.normalizedDistance ?? 1) < 0.1)
    }

    @Test func rejectsUnrelatedSpeech() {
        let matcher = CursorMatcher(script: script)
        #expect(matcher.match(hypothesis: "점심 메뉴는 뭘로 할까", anchor: 0) == nil)
    }

    @Test func rejectsTooShortHypothesis() {
        let matcher = CursorMatcher(script: script)
        // 자모 2개짜리 발화("오")는 잡음일 수 있으니 무시한다.
        #expect(matcher.match(hypothesis: "오", anchor: 0) == nil)
    }

    @Test func onlySearchesAfterAnchor() {
        let matcher = CursorMatcher(script: "가나다 라마바 가나다 라마바 사아자")
        // 앵커 2 이후에서 "가나다 라마바"를 찾으면 인덱스 4까지 읽은 것이다. 처음(0~1)으로 돌아가지 않는다.
        #expect(matcher.match(hypothesis: "가나다 라마바", anchor: 2)?.cursor == 4)
    }

    @Test func returnsNilAtEndOfScript() {
        let matcher = CursorMatcher(script: script)
        #expect(matcher.match(hypothesis: "마셨다", anchor: matcher.tokens.count) == nil)
    }

    @Test func partialLastWordDoesNotOvershoot() {
        let matcher = CursorMatcher(script: script)
        // "창문을"을 반만 말한 상태("창ㅁ")에서는 3번째 어절을 아직 끝낸 것으로 보지 않는 편이 자연스럽다.
        let match = matcher.match(hypothesis: "오늘 아침에는 창", anchor: 0)
        #expect(match?.cursor == 2)
    }

    // MARK: 건너뛰기

    @Test func startsMidScriptWithinSkipWindow() {
        let matcher = CursorMatcher(script: script)
        // 앞 두 어절을 건너뛰고 "창문을 열고"부터 읽기 시작.
        let match = matcher.match(hypothesis: "창문을 열고 바깥", anchor: 0)
        #expect(match?.cursor == 5)
        #expect(match?.skippedTokens == 2)
    }

    @Test func prefersNoSkipOnTie() {
        let matcher = CursorMatcher(script: "가나다 가나다 가나다 라마바")
        let match = matcher.match(hypothesis: "가나다", anchor: 0)
        #expect(match?.cursor == 1)
        #expect(match?.skippedTokens == 0)
    }

    @Test func doesNotSkipBeyondWindow() {
        let matcher = CursorMatcher(script: script, configuration: .init(maxSkipTokens: 2))
        // 5어절 건너뛴 "천천히 마셨다"는 창 밖이라 매칭되지 않는다.
        #expect(matcher.match(hypothesis: "천천히 마셨다", anchor: 0) == nil)
    }

    @Test func skipStillRejectsUnrelatedSpeech() {
        let matcher = CursorMatcher(script: script)
        #expect(matcher.match(hypothesis: "점심 메뉴는 뭘로 할까 고민이다", anchor: 0) == nil)
    }
}
