import Testing
@testable import ScriptTracker

struct ReadingSessionTests {
    let script = "오늘 아침에는 창문을 열고 바깥 공기를 천천히 마셨다"

    @Test func volatileMovesCursorButNotAnchor() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptVolatile("오늘 아침에는")
        #expect(session.cursor == 2)
        #expect(session.anchor == 0)
    }

    @Test func finalMovesAnchorAndClearsPending() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptVolatile("오늘 아침")
        session.acceptFinal("오늘 아침에는 창문을")
        #expect(session.cursor == 3)
        #expect(session.anchor == 3)
        #expect(session.pendingText.isEmpty)
    }

    @Test func cursorNeverGoesBackward() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptVolatile("오늘 아침에는 창문을 열고")
        #expect(session.cursor == 4)
        // 미확정 결과가 짧아져도(모델이 다시 생각해도) 커서는 뒤로 가지 않는다.
        session.acceptVolatile("오늘 아침")
        #expect(session.cursor == 4)
    }

    @Test func consecutiveFinalsContinueFromAnchor() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptFinal("오늘 아침에는")
        session.acceptFinal("창문을 열고")
        session.acceptFinal("바깥 공기를")
        #expect(session.cursor == 6)
    }

    @Test func unmatchedFinalIsRetriedWithNextFinal() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        // 첫 조각은 너무 짧아 무시되고, 다음 조각과 합치면 매칭된다.
        session.acceptFinal("오")
        #expect(session.cursor == 0)
        #expect(session.pendingText == "오")
        session.acceptFinal("늘 아침에는")
        #expect(session.cursor == 2)
    }

    @Test func offScriptSpeechIsDroppedAfterLimit() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.pendingTextLimit = 10
        session.acceptFinal("전혀 다른 이야기를 길게 합니다")
        #expect(session.pendingText.isEmpty)
        #expect(session.cursor == 0)
        // 다시 대본으로 돌아오면 따라잡는다.
        session.acceptFinal("오늘 아침에는")
        #expect(session.cursor == 2)
    }

    @Test func manualAdvanceAndReset() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.advanceManually()
        session.advanceManually()
        #expect(session.cursor == 2)
        #expect(session.anchor == 2)
        session.reset()
        #expect(session.cursor == 0)
    }

    @Test func completesAtEnd() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptFinal(script)
        #expect(session.isComplete)
    }

    @Test func repeatedReadingStartsFreshAfterReset() {
        var session = ReadingSession(matcher: CursorMatcher(script: script))
        session.acceptFinal(script)
        session.reset()
        session.acceptFinal("오늘 아침에는")
        #expect(session.cursor == 2)
    }
}
