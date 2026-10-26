// swift-tools-version: 6.2
// macOS에서 오디오 파일을 실시간 속도로 SpeechAnalyzer에 넣어 파이프라인과 매칭을 검증하는 도구.
// 실기기 없이도 ko-KR 지원·모델 설치·volatile/final 패턴·커서 추적을 재현한다.
import PackageDescription

let package = Package(
    name: "Harness",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../ScriptTracker"),
    ],
    targets: [
        .executableTarget(name: "Harness", dependencies: ["ScriptTracker"]),
    ]
)
