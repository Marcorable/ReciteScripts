import AVFAudio
import CoreMedia
import Foundation
import ScriptTracker
import Speech
import Synchronization

// 사용: Harness <대본 텍스트 파일> <오디오 파일> [--fast] [--hints] [--threshold 0.45] [--no-pace]
// 대본은 직접 쓴 더미여야 한다 (AGENTS.md 3번).

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 2 else {
    print("usage: Harness <script.txt> <audio.aiff> [--fast] [--hints] [--threshold X] [--no-pace]")
    exit(1)
}
let scriptURL = URL(fileURLWithPath: arguments[arguments.startIndex])
let audioURL = URL(fileURLWithPath: arguments[arguments.startIndex + 1])
let useFast = arguments.contains("--fast")
let useHints = arguments.contains("--hints")
let pace = !arguments.contains("--no-pace")
var threshold = 0.45
if let index = arguments.firstIndex(of: "--threshold"), index + 1 < arguments.endIndex {
    threshold = Double(arguments[index + 1]) ?? threshold
}

let script = try String(contentsOf: scriptURL, encoding: .utf8)
var session = ReadingSession(matcher: CursorMatcher(script: script, configuration: .init(maxNormalizedDistance: threshold)))

// 1. 로케일·모델
let useDictation = arguments.contains("--dictation")
let frequentFinalization = arguments.contains("--frequent-final")
let locale = Locale(identifier: "ko-KR")
let modern: SpeechTranscriber?
let dictation: DictationTranscriber?
if useDictation || !SpeechTranscriber.isAvailable {
    guard let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
        print("DictationTranscriber ko-KR 미지원. 지원 로케일: \(await DictationTranscriber.supportedLocales.map(\.identifier))")
        exit(2)
    }
    var reporting: Set<DictationTranscriber.ReportingOption> = [.volatileResults]
    if frequentFinalization { reporting.insert(.frequentFinalization) }
    dictation = DictationTranscriber(locale: supported, contentHints: [], transcriptionOptions: [], reportingOptions: reporting, attributeOptions: [.audioTimeRange])
    modern = nil
    print("모듈 DictationTranscriber(\(supported.identifier)) · SpeechTranscriber.isAvailable=\(SpeechTranscriber.isAvailable) · frequentFinalization=\(frequentFinalization)")
} else {
    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
        print("ko-KR 미지원. 지원 로케일: \(await SpeechTranscriber.supportedLocales.map(\.identifier))")
        exit(2)
    }
    var reporting: Set<SpeechTranscriber.ReportingOption> = [.volatileResults]
    if useFast { reporting.insert(.fastResults) }
    modern = SpeechTranscriber(locale: supported, transcriptionOptions: [], reportingOptions: reporting, attributeOptions: [.audioTimeRange])
    dictation = nil
    print("모듈 SpeechTranscriber(\(supported.identifier))")
}
let transcriber: any SpeechModule = modern.map { $0 as any SpeechModule } ?? dictation!
let status = await AssetInventory.status(forModules: [transcriber])
print("모델 상태 \(status) · fast=\(useFast) hints=\(useHints || hintsAtInit) threshold=\(threshold) pace=\(pace) priority=\(arguments.contains("--priority"))")
if status != .installed, let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    print("모델 내려받는 중…")
    try await request.downloadAndInstall()
    print("모델 설치 완료")
}

// 2. 분석기
let highPriority = arguments.contains("--priority")
let hintsAtInit = arguments.contains("--hints-init")
let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
let hintContext = AnalysisContext()
hintContext.contextualStrings = [.general: Array(Set(session.tokens.map(\.text)))]
let analyzer: SpeechAnalyzer
if hintsAtInit {
    // 초기화 시점에 컨텍스트를 주는 경로. 이 초기화는 분석을 바로 시작한다.
    analyzer = SpeechAnalyzer(inputSequence: inputSequence, modules: [transcriber], options: nil, analysisContext: hintContext)
} else {
    analyzer = SpeechAnalyzer(
        modules: [transcriber],
        options: highPriority ? .init(priority: .userInteractive, modelRetention: .processLifetime) : nil
    )
    if useHints { try await analyzer.setContext(hintContext) }
}
let file = try AVAudioFile(forReading: audioURL)
let fileFormat = file.processingFormat
guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: fileFormat) else {
    print("bestAvailableAudioFormat == nil"); exit(3)
}
print("파일 \(Int(fileFormat.sampleRate))Hz \(fileFormat.channelCount)ch → 분석기 \(Int(analyzerFormat.sampleRate))Hz \(analyzerFormat.channelCount)ch")
try await analyzer.prepareToAnalyze(in: analyzerFormat)

// 3. 입력: 파일을 실시간 속도로 흘려 넣는다.
let clock = AudioClock()
let startedAt = Date()
var chunkFrames: AVAudioFrameCount = 4096
if let index = arguments.firstIndex(of: "--chunk"), index + 1 < arguments.endIndex {
    chunkFrames = AVAudioFrameCount(arguments[index + 1]) ?? chunkFrames
}
let verbose = arguments.contains("--verbose")
let feeder = Task {
    let converter = AVAudioConverter(from: fileFormat, to: analyzerFormat)
    let framesPerChunk = chunkFrames
    var chunkIndex = 0
    while file.framePosition < file.length {
        guard let chunk = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: framesPerChunk) else { break }
        try file.read(into: chunk, frameCount: framesPerChunk)
        guard chunk.frameLength > 0 else { break }
        let output: AVAudioPCMBuffer
        if let converter {
            let ratio = analyzerFormat.sampleRate / fileFormat.sampleRate
            let capacity = AVAudioFrameCount((Double(chunk.frameLength) * ratio).rounded(.up)) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { break }
            let box = BufferBox(buffer: chunk)
            let consumed = ConsumedFlag()
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, outStatus in
                if consumed.take() { outStatus.pointee = .noDataNow; return nil }
                outStatus.pointee = .haveData
                return box.buffer
            }
            if let error { print("변환 오류 \(error)"); break }
            output = converted
        } else {
            output = chunk
        }
        let seconds = Double(output.frameLength) / analyzerFormat.sampleRate
        clock.add(seconds)
        inputBuilder.yield(AnalyzerInput(buffer: output))
        chunkIndex += 1
        if verbose, chunkIndex % 20 == 0 {
            print(String(format: "%6.2fs   피딩 %.2fs까지 투입", Date().timeIntervalSince(startedAt), clock.seconds))
        }
        if pace {
            // 벽시계보다 앞서 넣지 않는다.
            let ahead = clock.seconds - Date().timeIntervalSince(startedAt)
            if ahead > 0 { try await Task.sleep(for: .seconds(ahead)) }
        }
    }
    inputBuilder.finish()
}

// 4. 결과
struct Stats {
    var count = 0
    var finals = 0
    var lagSum = 0.0
    var lagMax = 0.0
    var lagCount = 0
}
var stats = Stats()
@MainActor func handle(_ text: AttributedString, _ isFinal: Bool, _ range: CMTimeRange) {
    stats.count += 1
    let plain = String(text.characters)
    let wall = Date().timeIntervalSince(startedAt)
    // 마지막 단어의 audioTimeRange 끝. 피딩이 실시간이므로 (벽시계 − 단어 끝) = 그 단어가 끝난 뒤 결과가 오기까지 걸린 시간.
    let lastWordEnd = text.runs.compactMap { $0.audioTimeRange?.end.seconds }.last
    let wordLag = lastWordEnd.map { wall - $0 }
    if let wordLag { stats.lagSum += wordLag; stats.lagMax = max(stats.lagMax, wordLag); stats.lagCount += 1 }
    if isFinal { stats.finals += 1; session.acceptFinal(plain) } else { session.acceptVolatile(plain) }
    if verbose {
        let runs = text.runs.map { run -> String in
            let r = run.audioTimeRange.map { String(format: "%.2f–%.2f", $0.start.seconds, $0.end.seconds) } ?? "-"
            return "「\(String(text[run.range].characters))」\(r)"
        }
        print("    runs \(runs.count): \(runs.prefix(8).joined(separator: " "))")
    }
    let distance = session.lastDistance.map { String(format: "%.2f", $0) } ?? "-"
    print(String(format: "%6.2fs %@ [%6.2f–%6.2f] 단어끝 %@ 지연 %@ 커서 %3d 거리 %@ 「%@」",
                 wall, isFinal ? "확정" : "임시", range.start.seconds, range.end.seconds,
                 lastWordEnd.map { String(format: "%6.2f", $0) } ?? "     -",
                 wordLag.map { String(format: "%5.2fs", $0) } ?? "    - ",
                 session.cursor, distance, plain))
}
let results = Task {
    if let modern {
        for try await result in modern.results { handle(result.text, result.isFinal, result.range) }
    } else if let dictation {
        for try await result in dictation.results { handle(result.text, result.isFinal, result.range) }
    }
    print("결과 \(stats.count)개(확정 \(stats.finals)) · 단어 지연 평균 \(String(format: "%.2f", stats.lagCount > 0 ? stats.lagSum / Double(stats.lagCount) : 0))s · 최대 \(String(format: "%.2f", stats.lagMax))s · 커서 \(session.cursor)/\(session.tokens.count)")
}

if !hintsAtInit { try await analyzer.start(inputSequence: inputSequence) }
try await feeder.value
try await analyzer.finalizeAndFinishThroughEndOfInput()
try await results.value

final class AudioClock: Sendable {
    private let storage = Mutex<Double>(0)
    var seconds: Double { storage.withLock { $0 } }
    func add(_ delta: Double) { storage.withLock { $0 += delta } }
}
struct BufferBox: @unchecked Sendable { let buffer: AVAudioPCMBuffer }
final class ConsumedFlag: Sendable {
    private let flag = Mutex(false)
    func take() -> Bool {
        flag.withLock { value in
            defer { value = true }
            return value
        }
    }
}
