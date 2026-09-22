import AVFAudio
import CoreMedia
import Foundation
import Speech
import Synchronization

/// 파이프라인이 내보내는 이벤트. UI는 이것만 보고 상태를 갱신한다.
enum PipelineEvent: Sendable {
    case status(String)
    case audioFormat(input: String, analyzer: String, converted: Bool)
    case result(text: String, isFinal: Bool, start: Double, end: Double, audioFed: Double)
    case failed(String)
    case finished
}

/// 마이크 → AVAudioConverter → SpeechAnalyzer(SpeechTranscriber, ko-KR) 파이프라인.
///
/// 알려진 함정(AGENTS.md 7번 P1): `AVAudioEngine` 입력 포맷과 `bestAvailableAudioFormat`이 다르면
/// 에러 없이 전사가 0건이다. iOS 27의 `AnalyzerInputConverter`는 iOS 26 타깃에서 못 쓰므로 직접 변환한다.
actor SpeechPipeline {
    struct Options: Sendable {
        var locale = Locale(identifier: "ko-KR")
        var fastResults = false
        /// `SpeechTranscriber`가 기기에서 불가하거나 비교를 원할 때 `DictationTranscriber`(받아쓰기 모델)를 쓴다.
        var preferDictation = false
        /// 대본 어절을 `AnalysisContext.contextualStrings`로 넘겨 인식 편향을 준다.
        var contextualWords: [String] = []
    }

    private let options: Options
    private let events: AsyncStream<PipelineEvent>.Continuation
    private let engine = AVAudioEngine()
    /// 지금까지 분석기에 넣은 오디오 길이(초). 결과의 `range.end`와 비교해 지연을 잰다.
    private let audioFed = AudioClock()
    private var running: RunningState?

    private struct RunningState {
        let analyzer: SpeechAnalyzer
        let input: AsyncStream<AnalyzerInput>.Continuation
        let resultsTask: Task<Void, Never>
    }

    init(options: Options, events: AsyncStream<PipelineEvent>.Continuation) {
        self.options = options
        self.events = events
    }

    // MARK: - 지원·모델 확인

    static func localeReport(for locale: Locale) async -> String {
        var lines: [String] = []
        if SpeechTranscriber.isAvailable {
            let supported = await SpeechTranscriber.supportedLocales.map(\.identifier).sorted()
            let installed = await SpeechTranscriber.installedLocales.map(\.identifier)
            let equivalent = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
            lines.append("SpeechTranscriber: \(locale.identifier) \(equivalent == nil ? "미지원" : "지원") · 설치 \(installed.contains { $0.hasPrefix("ko") } ? "예" : "아니오") · 로케일 \(supported.count)개")
        } else {
            lines.append("SpeechTranscriber: 이 기기에서 사용 불가 → DictationTranscriber 폴백")
        }
        let dictationSupported = await DictationTranscriber.supportedLocales.map(\.identifier).sorted()
        let dictationInstalled = await DictationTranscriber.installedLocales.map(\.identifier)
        let dictationEquivalent = await DictationTranscriber.supportedLocale(equivalentTo: locale)
        lines.append("DictationTranscriber: \(locale.identifier) \(dictationEquivalent == nil ? "미지원" : "지원") · 설치 \(dictationInstalled.contains { $0.hasPrefix("ko") } ? "예" : "아니오") · 로케일 \(dictationSupported.count)개")
        return lines.joined(separator: "\n")
    }

    // MARK: - 시작·정지

    func start() async throws {
        guard await requestMicrophonePermission() else {
            throw PipelineError.microphoneDenied
        }

        let module = try await makeModule()
        try await ensureAssets(for: module.speechModule)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [])
        try session.setActive(true)

        let analyzer = SpeechAnalyzer(modules: [module.speechModule])
        if !options.contextualWords.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings = [.general: options.contextualWords]
            try await analyzer.setContext(context)
        }

        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [module.speechModule], considering: inputFormat
        )
        let targetFormat = analyzerFormat ?? inputFormat
        let needsConversion = !(inputFormat == targetFormat)
        events.yield(.audioFormat(
            input: Self.describe(inputFormat),
            analyzer: analyzerFormat.map(Self.describe) ?? "nil (입력 포맷 그대로 사용)",
            converted: needsConversion
        ))

        events.yield(.status("모델 준비 중(prepareToAnalyze)…"))
        try await analyzer.prepareToAnalyze(in: targetFormat)

        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try installTap(inputFormat: inputFormat, targetFormat: targetFormat, into: inputBuilder)

        let resultsTask = module.consumeResults(events: events, audioFed: audioFed)
        running = RunningState(analyzer: analyzer, input: inputBuilder, resultsTask: resultsTask)

        try await analyzer.start(inputSequence: inputSequence)
        engine.prepare()
        try engine.start()
        events.yield(.status("듣는 중"))
    }

    func stop() async {
        guard let running else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        running.input.finish()
        do {
            try await running.analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            events.yield(.failed("종료 오류: \(error)"))
        }
        self.running = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        events.yield(.status("정지됨"))
    }

    // MARK: - 내부

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// 기기 지원 여부에 따라 모듈을 고른다. 두 모듈은 Result 타입이 달라 enum으로 감싼다.
    private func makeModule() async throws -> TranscriberModule {
        var reporting: Set<SpeechTranscriber.ReportingOption> = [.volatileResults]
        if options.fastResults { reporting.insert(.fastResults) }

        if SpeechTranscriber.isAvailable, !options.preferDictation {
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: options.locale) else {
                throw PipelineError.unsupportedLocale(options.locale.identifier)
            }
            events.yield(.status("모듈: SpeechTranscriber(\(locale.identifier))"))
            return .modern(SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: reporting,
                attributeOptions: [.audioTimeRange]
            ))
        }

        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: options.locale) else {
            throw PipelineError.unsupportedLocale(options.locale.identifier)
        }
        events.yield(.status("모듈: DictationTranscriber(\(locale.identifier))\(SpeechTranscriber.isAvailable ? "" : " — SpeechTranscriber 불가 기기")"))
        return .dictation(DictationTranscriber(
            locale: locale,
            contentHints: [],
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        ))
    }

    private func ensureAssets(for transcriber: any SpeechModule) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])
        events.yield(.status("모델 상태: \(status)"))
        switch status {
        case .installed:
            return
        case .unsupported:
            throw PipelineError.unsupportedLocale(options.locale.identifier)
        case .supported, .downloading:
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                return
            }
            events.yield(.status("모델 내려받는 중… (\(Int(request.progress.fractionCompleted * 100))%)"))
            try await request.downloadAndInstall()
            events.yield(.status("모델 설치 완료"))
        @unknown default:
            return
        }
    }

    /// 입력 탭. 오디오 스레드에서 호출되므로 self를 잡지 않고 필요한 것만 캡처한다.
    private func installTap(
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        into builder: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let converter: AVAudioConverter?
        if inputFormat == targetFormat {
            converter = nil
        } else {
            guard let made = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw PipelineError.converterUnavailable
            }
            converter = made
        }
        let audioFed = self.audioFed
        let events = self.events

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { @Sendable buffer, _ in
            let output: AVAudioPCMBuffer
            if let converter {
                guard let converted = Self.convert(buffer, with: converter, to: targetFormat) else {
                    events.yield(.failed("오디오 변환 실패"))
                    return
                }
                output = converted
            } else {
                output = buffer
            }
            audioFed.add(Double(output.frameLength) / targetFormat.sampleRate)
            builder.yield(AnalyzerInput(buffer: output))
        }
    }

    private static func convert(
        _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        let source = UnsafeBufferBox(buffer: buffer)
        let consumed = Mutex(false)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            let alreadyConsumed = consumed.withLock { flag in
                defer { flag = true }
                return flag
            }
            if alreadyConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            return source.buffer
        }
        guard status != .error, error == nil else { return nil }
        return output
    }

    private static func describe(_ format: AVAudioFormat) -> String {
        let common: String
        switch format.commonFormat {
        case .pcmFormatFloat32: common = "Float32"
        case .pcmFormatFloat64: common = "Float64"
        case .pcmFormatInt16: common = "Int16"
        case .pcmFormatInt32: common = "Int32"
        default: common = "other"
        }
        return "\(Int(format.sampleRate))Hz \(format.channelCount)ch \(common)\(format.isInterleaved ? " interleaved" : "")"
    }
}

/// 기기에 따라 고르는 전사 모듈. `SpeechTranscriber`(iOS 26 신형 모델) 또는 `DictationTranscriber`(받아쓰기 모델, 구형 기기 호환).
enum TranscriberModule {
    case modern(SpeechTranscriber)
    case dictation(DictationTranscriber)

    var speechModule: any SpeechModule {
        switch self {
        case .modern(let module): module
        case .dictation(let module): module
        }
    }

    func consumeResults(events: AsyncStream<PipelineEvent>.Continuation, audioFed: AudioClock) -> Task<Void, Never> {
        Task {
            do {
                switch self {
                case .modern(let module):
                    for try await result in module.results {
                        Self.emit(result.text, result.isFinal, result.range, events, audioFed)
                    }
                case .dictation(let module):
                    for try await result in module.results {
                        Self.emit(result.text, result.isFinal, result.range, events, audioFed)
                    }
                }
                events.yield(.finished)
            } catch {
                events.yield(.failed("결과 스트림 오류: \(error)"))
            }
        }
    }

    private static func emit(
        _ text: AttributedString, _ isFinal: Bool, _ range: CMTimeRange,
        _ events: AsyncStream<PipelineEvent>.Continuation, _ audioFed: AudioClock
    ) {
        events.yield(.result(
            text: String(text.characters),
            isFinal: isFinal,
            start: range.start.seconds,
            end: range.end.seconds,
            audioFed: audioFed.seconds
        ))
    }
}

/// 오디오 스레드가 더하고 결과 태스크가 읽는 카운터. Mutex는 ~Copyable이라 클로저에 잡을 수 있게 클래스로 감싼다.
final class AudioClock: Sendable {
    private let storage = Mutex<Double>(0)
    var seconds: Double { storage.withLock { $0 } }
    func add(_ delta: Double) { storage.withLock { $0 += delta } }
}

/// 변환기 입력 블록이 Sendable을 요구해서 버퍼를 감싼다. 블록은 convert 호출 안에서 동기적으로만 불린다.
private struct UnsafeBufferBox: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

enum PipelineError: LocalizedError {
    case microphoneDenied
    case unsupportedLocale(String)
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "마이크 권한이 거부됨"
        case .unsupportedLocale(let id): "\(id) 로케일을 지원하지 않음"
        case .converterUnavailable: "AVAudioConverter 생성 실패"
        }
    }
}
