// swift-tools-version: 6.2
// 스파이크용 순수 로직 패키지. UI·STT에 의존하지 않는다.
import PackageDescription

let package = Package(
    name: "ScriptTracker",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScriptTracker", targets: ["ScriptTracker"]),
    ],
    targets: [
        .target(name: "ScriptTracker"),
        .testTarget(name: "ScriptTrackerTests", dependencies: ["ScriptTracker"]),
    ]
)
