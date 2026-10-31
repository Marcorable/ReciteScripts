import AVFAudio
import Foundation
import Speech
import Synchronization

@MainActor
final class IosSpeechSession {
  typealias EventHandler = @MainActor (NativeSttEvent) async -> Void
  typealias FinishedHandler = @MainActor (IosSpeechSession) -> Void

  let sessionId: String
  let generation: Int64

  private let transcriber: SpeechTranscriber
  private let eventHandler: EventHandler
  private let finishedHandler: FinishedHandler
  private let engine = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var sequence: Int64 = 0
  private var acceptsEvents = true
  private var tapInstalled = false
  private var cleanupTask: Task<Void, Never>?
  private let conversionFailed = ThreadSafeFlag()

  init(
    sessionId: String,
    generation: Int64,
    transcriber: SpeechTranscriber,
    eventHandler: @escaping EventHandler,
    onFinished: @escaping FinishedHandler
  ) {
    self.sessionId = sessionId
    self.generation = generation
    self.transcriber = transcriber
    self.eventHandler = eventHandler
    finishedHandler = onFinished
  }

  func matches(event: NativeSttEvent) -> Bool {
    event.sessionId == sessionId && event.generation == generation
  }

  func start() async throws {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
    try audioSession.setActive(true)

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer
    let inputFormat = engine.inputNode.outputFormat(forBus: 0)
    guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
      throw IosSpeechError.audio
    }
    guard let targetFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
      compatibleWith: [transcriber],
      considering: inputFormat
    ) else {
      throw IosSpeechError.audioFormatMismatch
    }
    try ensureActive()
    try await analyzer.prepareToAnalyze(in: targetFormat)
    try ensureActive()

    let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
    try installTap(inputFormat: inputFormat, targetFormat: targetFormat, continuation: continuation)
    inputContinuation = continuation
    resultsTask = consumeResults()

    try await analyzer.start(inputSequence: inputSequence)
    try ensureActive()
    engine.prepare()
    do {
      try engine.start()
    } catch {
      throw IosSpeechError.audio
    }
    await emit(kind: .ready)
  }

  func cancel(emitEvent: Bool) async {
    if acceptsEvents {
      acceptsEvents = false
      if emitEvent { await emitUnchecked(kind: .cancelled) }
    }
    await cleanUp(finalize: false)
  }

  func fail(code: NativeSttFailureCode, retryable: Bool) async {
    if acceptsEvents {
      acceptsEvents = false
      await emitUnchecked(kind: .failure, failureCode: code, retryable: retryable)
    }
    await cleanUp(finalize: false)
    finishedHandler(self)
  }

  private func consumeResults() -> Task<Void, Never> {
    Task { [weak self, transcriber] in
      do {
        for try await result in transcriber.results {
          guard let self, self.acceptsEvents else { return }
          let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
          guard !text.isEmpty else { continue }
          await self.emit(kind: result.isFinal ? .finalResult : .partial, text: text)
        }
        guard let self, self.acceptsEvents else { return }
        self.acceptsEvents = false
        if self.conversionFailed.value {
          await self.emitUnchecked(
            kind: .failure,
            failureCode: .audioFormatMismatch,
            retryable: false
          )
        } else {
          await self.emitUnchecked(kind: .ended)
        }
        await self.cleanUp(finalize: false)
        self.finishedHandler(self)
      } catch is CancellationError {
        return
      } catch {
        guard let self, self.acceptsEvents else { return }
        self.acceptsEvents = false
        await self.emitUnchecked(kind: .failure, failureCode: .unknown, retryable: true)
        await self.cleanUp(finalize: false)
        self.finishedHandler(self)
      }
    }
  }

  private func installTap(
    inputFormat: AVAudioFormat,
    targetFormat: AVAudioFormat,
    continuation: AsyncStream<AnalyzerInput>.Continuation
  ) throws {
    let converter: AVAudioConverter?
    if inputFormat == targetFormat {
      converter = nil
    } else {
      guard let made = AVAudioConverter(from: inputFormat, to: targetFormat) else {
        throw IosSpeechError.audioFormatMismatch
      }
      converter = made
    }
    let converterBox = AudioConverterBox(converter)
    let conversionFailed = self.conversionFailed
    engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
      if let converter = converterBox.converter {
        guard let converted = Self.convert(buffer, with: converter, to: targetFormat) else {
          conversionFailed.set()
          continuation.finish()
          return
        }
        continuation.yield(AnalyzerInput(buffer: converted))
      } else {
        continuation.yield(AnalyzerInput(buffer: buffer))
      }
    }
    tapInstalled = true
  }

  private func emit(
    kind: NativeSttEventKind,
    text: String? = nil,
    failureCode: NativeSttFailureCode? = nil,
    retryable: Bool? = nil
  ) async {
    guard acceptsEvents else { return }
    await emitUnchecked(
      kind: kind,
      text: text,
      failureCode: failureCode,
      retryable: retryable
    )
  }

  private func emitUnchecked(
    kind: NativeSttEventKind,
    text: String? = nil,
    failureCode: NativeSttFailureCode? = nil,
    retryable: Bool? = nil
  ) async {
    sequence += 1
    await eventHandler(
      NativeSttEvent(
        sessionId: sessionId,
        generation: generation,
        sequence: sequence,
        kind: kind,
        text: text,
        failureCode: failureCode,
        retryable: retryable
      )
    )
  }

  private func cleanUp(finalize: Bool) async {
    if let cleanupTask {
      await cleanupTask.value
      return
    }
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.performCleanUp(finalize: finalize)
    }
    cleanupTask = task
    await task.value
  }

  private func performCleanUp(finalize: Bool) async {
    engine.stop()
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    inputContinuation?.finish()
    inputContinuation = nil
    let task = resultsTask
    resultsTask = nil
    task?.cancel()
    if let analyzer {
      if finalize {
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
      } else {
        await analyzer.cancelAndFinishNow()
      }
    }
    self.analyzer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func ensureActive() throws {
    guard acceptsEvents else { throw CancellationError() }
  }

  private nonisolated static func convert(
    _ buffer: AVAudioPCMBuffer,
    with converter: AVAudioConverter,
    to format: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
    let source = AudioBufferBox(buffer)
    let consumed = Mutex(false)
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, outputStatus in
      let wasConsumed = consumed.withLock { value in
        defer { value = true }
        return value
      }
      if wasConsumed {
        outputStatus.pointee = .noDataNow
        return nil
      }
      outputStatus.pointee = .haveData
      return source.buffer
    }
    guard status != .error, conversionError == nil else { return nil }
    return output
  }
}

private struct AudioBufferBox: @unchecked Sendable {
  let buffer: AVAudioPCMBuffer
  init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}

private struct AudioConverterBox: @unchecked Sendable {
  let converter: AVAudioConverter?
  init(_ converter: AVAudioConverter?) { self.converter = converter }
}

private final class ThreadSafeFlag: Sendable {
  private let storage = Mutex(false)
  var value: Bool { storage.withLock { $0 } }
  func set() { storage.withLock { $0 = true } }
}
