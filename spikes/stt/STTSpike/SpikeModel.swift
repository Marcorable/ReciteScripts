import Foundation
import Observation
import ScriptTracker

/// 화면 상태. 파이프라인 이벤트를 받아 낭독 세션(커서)과 측정치를 갱신한다.
@MainActor
@Observable
final class SpikeModel {
    struct LogEntry: Identifiable {
        let id = UUID()
        let time: Date
        let message: String
    }

    struct ResultRecord: Identifiable {
        let id = UUID()
        let receivedAt: Date
        let text: String
        let isFinal: Bool
        let audioStart: Double
        let audioEnd: Double
        /// 결과가 도착한 시점까지 분석기에 넣은 오디오(초) − 결과 구간 끝(초). 인식 지연의 근사치.
        let lag: Double
    }

    // 설정
    var script: SampleScript = SampleScript.all[0] { didSet { resetSession() } }
    /// Mac TTS 검증 결과: 끄면 임시 결과가 ~11초 단위로 묶여 온다. 실시간 추적에는 필수 (docs/log/stt-spike.md).
    var useFastResults = true
    var useContextualWords = false
    var maxDistance: Double = 0.45 { didSet { resetSession() } }

    // 상태
    private(set) var session: ReadingSession
    private(set) var isRunning = false
    private(set) var status = "대기"
    private(set) var localeReport = "확인 중…"
    private(set) var formatReport = "—"
    private(set) var finalizedText = ""
    private(set) var volatileText = ""
    private(set) var results: [ResultRecord] = []
    private(set) var log: [LogEntry] = []
    private(set) var startedAt: Date?

    private var pipeline: SpeechPipeline?
    private var eventTask: Task<Void, Never>?

    init() {
        session = ReadingSession(matcher: CursorMatcher(script: SampleScript.all[0].body))
        // 검증용: `-spikeDemoCursor N` 런치 인자로 커서를 옮겨 놓고 스크린샷을 찍는다.
        for _ in 0..<UserDefaults.standard.integer(forKey: "spikeDemoCursor") {
            session.advanceManually()
        }
    }

    // MARK: - 측정치

    var finalCount: Int { results.filter(\.isFinal).count }
    var volatileCount: Int { results.count - finalCount }
    var averageLag: Double? {
        guard !results.isEmpty else { return nil }
        return results.map(\.lag).reduce(0, +) / Double(results.count)
    }
    var maxLag: Double? { results.map(\.lag).max() }
    var lastVolatileLag: Double? { results.last(where: { !$0.isFinal })?.lag }

    // MARK: - 동작

    func checkSupport() async {
        localeReport = await SpeechPipeline.localeReport(for: Locale(identifier: "ko-KR"))
    }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func resetSession() {
        session = ReadingSession(
            matcher: CursorMatcher(
                script: script.body,
                configuration: .init(maxNormalizedDistance: maxDistance)
            )
        )
        finalizedText = ""
        volatileText = ""
        results = []
        log = []
    }

    func advanceManually() {
        session.advanceManually()
        append("수동 넘김 → \(session.cursor)")
    }

    private func start() {
        resetSession()
        let (events, continuation) = AsyncStream.makeStream(of: PipelineEvent.self)
        var options = SpeechPipeline.Options()
        options.fastResults = useFastResults
        if useContextualWords {
            options.contextualWords = Array(Set(session.tokens.map(\.text)))
        }
        let pipeline = SpeechPipeline(options: options, events: continuation)
        self.pipeline = pipeline
        isRunning = true
        startedAt = .now
        append("시작 — fastResults=\(useFastResults) 힌트=\(useContextualWords) 임계값=\(maxDistance)")

        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { break }
                self.handle(event)
            }
        }
        Task {
            do {
                try await pipeline.start()
            } catch {
                append("시작 실패: \(error.localizedDescription)")
                status = "오류: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }

    private func stop() {
        guard let pipeline else { return }
        isRunning = false
        Task {
            await pipeline.stop()
            self.pipeline = nil
        }
    }

    private func handle(_ event: PipelineEvent) {
        switch event {
        case .status(let message):
            status = message
            append(message)
        case .audioFormat(let input, let analyzer, let converted):
            formatReport = "입력 \(input)\n분석기 \(analyzer)\n변환 \(converted ? "필요(AVAudioConverter)" : "불필요")"
            append(formatReport.replacingOccurrences(of: "\n", with: " / "))
        case .result(let text, let isFinal, let start, let end, let fed):
            let record = ResultRecord(
                receivedAt: .now, text: text, isFinal: isFinal,
                audioStart: start, audioEnd: end, lag: fed - end
            )
            results.append(record)
            if isFinal {
                finalizedText += text
                volatileText = ""
                session.acceptFinal(text)
            } else {
                volatileText = text
                session.acceptVolatile(text)
            }
            let distance = session.lastDistance.map { String(format: "%.2f", $0) } ?? "-"
            append(String(
                format: "%@ [%.2f–%.2f] 지연 %.2fs 커서 %d 거리 %@ 「%@」",
                isFinal ? "확정" : "임시", start, end, record.lag, session.cursor, distance, text
            ))
        case .failed(let message):
            status = message
            append(message)
            isRunning = false
        case .finished:
            append("결과 스트림 종료")
        }
    }

    private func append(_ message: String) {
        log.append(LogEntry(time: .now, message: message))
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }

    /// 로그를 텍스트로 뽑아 Marco가 결과를 붙여 넣을 수 있게 한다.
    func exportLog() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let header = """
        대본: \(script.title)
        fastResults: \(useFastResults) / 힌트: \(useContextualWords) / 임계값: \(maxDistance)
        \(localeReport)
        \(formatReport)
        결과 \(results.count)개 (확정 \(finalCount), 임시 \(volatileCount)), 평균 지연 \(averageLag.map { String(format: "%.2fs", $0) } ?? "-"), 최대 \(maxLag.map { String(format: "%.2fs", $0) } ?? "-")
        커서 \(session.cursor)/\(session.tokens.count)

        """
        return header + log.map { "\(formatter.string(from: $0.time)) \($0.message)" }.joined(separator: "\n")
    }
}
