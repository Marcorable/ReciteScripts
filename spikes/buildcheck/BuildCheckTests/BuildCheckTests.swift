import Testing
@testable import BuildCheck

@Test func greetingIsNotEmpty() {
    #expect(BuildInfo.greeting.isEmpty == false)
}

@Test func greetingIsStable() {
    #expect(BuildInfo.greeting == "검증 루프가 동작합니다")
}
