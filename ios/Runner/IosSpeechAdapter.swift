import AVFAudio
import Flutter
import Foundation
import Speech
import UIKit

@MainActor
final class IosSpeechAdapter: NSObject, NativeSttHostApi {
  private final class StartReservation {
    let sessionId: String
    let generation: Int64

    init(sessionId: String, generation: Int64) {
      self.sessionId = sessionId
      self.generation = generation
    }
  }

  private let flutterApi: NativeSttFlutterApi
  private var activeSession: IosSpeechSession?
  private var pendingStart: StartReservation?
  private var observers: [NSObjectProtocol] = []

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = NativeSttFlutterApi(binaryMessenger: binaryMessenger)
    super.init()
    observers.append(NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.handleBackgroundTransition()
      }
    })
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        AVAudioSession.InterruptionType(rawValue: rawValue) == .began
      else { return }
      Task { @MainActor in
        await self?.interruptActiveSession()
      }
    })
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.mediaServicesWereResetNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.interruptActiveSession()
      }
    })
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  func checkAvailability(locale: String) async throws -> NativeSttAvailability {
    let locale = Locale(identifier: locale)
    let microphonePermission = Self.microphonePermission()
    let speechPermission = Self.speechPermission()
    let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
    let isSupported = SpeechTranscriber.isAvailable && supportedLocale != nil
    let modelStatus: NativeSttModelStatus
    if let supportedLocale, SpeechTranscriber.isAvailable {
      let transcriber = Self.makeTranscriber(locale: supportedLocale)
      modelStatus = Self.modelStatus(await AssetInventory.status(forModules: [transcriber]))
    } else {
      modelStatus = .unsupported
    }
    return NativeSttAvailability(
      microphonePermission: microphonePermission,
      speechPermission: speechPermission,
      onDeviceAvailable: SpeechTranscriber.isAvailable,
      localeSupported: isSupported,
      modelStatus: modelStatus
    )
  }

  func prepare(locale: String) async throws -> NativeSttPreparation {
    let microphone = await requestMicrophonePermission()
    guard microphone == .granted else {
      return NativeSttPreparation(
        status: microphone == .notDetermined ? .permissionRequired : .permissionDenied,
        failureCode: .permissionDenied
      )
    }
    let speech = await requestSpeechPermission()
    guard speech == .granted else {
      return NativeSttPreparation(
        status: speech == .notDetermined ? .permissionRequired : .permissionDenied,
        failureCode: .permissionDenied
      )
    }
    guard SpeechTranscriber.isAvailable else {
      return NativeSttPreparation(status: .unsupported, failureCode: .onDeviceUnavailable)
    }
    let requestedLocale = Locale(identifier: locale)
    guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale)
    else {
      return NativeSttPreparation(status: .unsupported, failureCode: .localeUnsupported)
    }

    let transcriber = Self.makeTranscriber(locale: supportedLocale)
    switch await AssetInventory.status(forModules: [transcriber]) {
    case .installed:
      return NativeSttPreparation(status: .ready, failureCode: nil)
    case .unsupported:
      return NativeSttPreparation(status: .unsupported, failureCode: .localeUnsupported)
    case .downloading:
      return NativeSttPreparation(status: .modelDownloading, failureCode: nil)
    case .supported:
      return NativeSttPreparation(status: .modelDownloadRequired, failureCode: .modelMissing)
    @unknown default:
      return NativeSttPreparation(status: .unsupported, failureCode: .unknown)
    }
  }

  func requestModelDownload(locale: String) async throws -> NativeSttPreparation {
    guard SpeechTranscriber.isAvailable else {
      return NativeSttPreparation(status: .unsupported, failureCode: .onDeviceUnavailable)
    }
    let requestedLocale = Locale(identifier: locale)
    guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale)
    else {
      return NativeSttPreparation(status: .unsupported, failureCode: .localeUnsupported)
    }
    let transcriber = Self.makeTranscriber(locale: supportedLocale)
    switch await AssetInventory.status(forModules: [transcriber]) {
    case .installed:
      return NativeSttPreparation(status: .ready, failureCode: nil)
    case .downloading:
      return NativeSttPreparation(status: .modelDownloading, failureCode: nil)
    case .unsupported:
      return NativeSttPreparation(status: .unsupported, failureCode: .localeUnsupported)
    case .supported:
      guard let request = try await AssetInventory.assetInstallationRequest(
        supporting: [transcriber]
      ) else {
        return NativeSttPreparation(status: .modelDownloadRequired, failureCode: .modelMissing)
      }
      try await request.downloadAndInstall()
      let installed = await AssetInventory.status(forModules: [transcriber]) == .installed
      return NativeSttPreparation(
        status: installed ? .ready : .modelDownloadRequired,
        failureCode: installed ? nil : .modelMissing
      )
    @unknown default:
      return NativeSttPreparation(status: .unsupported, failureCode: .unknown)
    }
  }

  func start(request: NativeSttStartRequest) async throws {
    guard activeSession == nil, pendingStart == nil else {
      throw PigeonError(code: "busy", message: "An STT session is already active.", details: nil)
    }
    let reservation = StartReservation(
      sessionId: request.sessionId,
      generation: request.generation
    )
    pendingStart = reservation
    defer {
      if pendingStart === reservation { pendingStart = nil }
    }
    guard Self.microphonePermission() == .granted, Self.speechPermission() == .granted else {
      throw PigeonError(code: "permissionDenied", message: "STT permission is not granted.", details: nil)
    }
    guard SpeechTranscriber.isAvailable else {
      throw PigeonError(code: "onDeviceUnavailable", message: "On-device STT is unavailable.", details: nil)
    }
    let requestedLocale = Locale(identifier: request.locale)
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
      try ensurePending(reservation)
      throw PigeonError(code: "localeUnsupported", message: "The locale is unsupported.", details: nil)
    }
    try ensurePending(reservation)
    let transcriber = Self.makeTranscriber(locale: locale)
    guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
      try ensurePending(reservation)
      throw PigeonError(code: "modelMissing", message: "The on-device model is not installed.", details: nil)
    }
    try ensurePending(reservation)

    let session = IosSpeechSession(
      sessionId: request.sessionId,
      generation: request.generation,
      transcriber: transcriber
    ) { [weak self] event in
      guard let self, self.activeSession?.matches(event: event) == true else { return }
      try? await self.flutterApi.onEvent(event: event)
    } onFinished: { [weak self] session in
      guard let self, self.activeSession === session else { return }
      self.activeSession = nil
    }
    activeSession = session
    pendingStart = nil
    do {
      try await session.start()
    } catch {
      await session.cancel(emitEvent: false)
      if activeSession === session { activeSession = nil }
      throw Self.pigeonError(from: error)
    }
  }

  func cancel(sessionId: String) async throws {
    if pendingStart?.sessionId == sessionId { pendingStart = nil }
    guard activeSession?.sessionId == sessionId else { return }
    await cancelActiveSession(emitCancelled: true)
  }

  func dispose() async throws {
    pendingStart = nil
    await cancelActiveSession(emitCancelled: false)
  }

  private func cancelActiveSession(emitCancelled: Bool) async {
    guard let session = activeSession else { return }
    await session.cancel(emitEvent: emitCancelled)
    if activeSession === session { activeSession = nil }
  }

  private func interruptActiveSession() async {
    pendingStart = nil
    guard let session = activeSession else { return }
    await session.fail(code: .interrupted, retryable: true)
    if activeSession === session { activeSession = nil }
  }

  private func handleBackgroundTransition() async {
    pendingStart = nil
    await cancelActiveSession(emitCancelled: true)
  }

  private func ensurePending(_ reservation: StartReservation) throws {
    guard pendingStart === reservation else { throw CancellationError() }
  }

  private static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
    SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults, .fastResults],
      attributeOptions: []
    )
  }

  private static func microphonePermission() -> NativeSttPermission {
    switch AVAudioApplication.shared.recordPermission {
    case .undetermined: .notDetermined
    case .granted: .granted
    case .denied: .denied
    @unknown default: .restricted
    }
  }

  private static func speechPermission() -> NativeSttPermission {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .notDetermined: .notDetermined
    case .authorized: .granted
    case .denied: .denied
    case .restricted: .restricted
    @unknown default: .restricted
    }
  }

  private func requestMicrophonePermission() async -> NativeSttPermission {
    if Self.microphonePermission() != .notDetermined { return Self.microphonePermission() }
    _ = await AVAudioApplication.requestRecordPermission()
    return Self.microphonePermission()
  }

  private func requestSpeechPermission() async -> NativeSttPermission {
    if Self.speechPermission() != .notDetermined { return Self.speechPermission() }
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
    }
    return Self.speechPermission()
  }

  private static func modelStatus(_ status: AssetInventory.Status) -> NativeSttModelStatus {
    switch status {
    case .installed: .installed
    case .supported: .supported
    case .downloading: .downloading
    case .unsupported: .unsupported
    @unknown default: .missing
    }
  }

  private static func pigeonError(from error: Error) -> PigeonError {
    if let error = error as? PigeonError { return error }
    if let error = error as? IosSpeechError {
      return PigeonError(code: error.code, message: error.message, details: nil)
    }
    if error is CancellationError {
      return PigeonError(code: "cancelled", message: "The STT start was cancelled.", details: nil)
    }
    return PigeonError(code: "unknown", message: "The STT session failed.", details: nil)
  }
}

enum IosSpeechError: Error {
  case audioFormatMismatch
  case audio

  var code: String {
    switch self {
    case .audioFormatMismatch: "audioFormatMismatch"
    case .audio: "audio"
    }
  }

  var message: String {
    switch self {
    case .audioFormatMismatch: "The microphone format cannot be converted for SpeechAnalyzer."
    case .audio: "The audio input could not be started."
    }
  }
}
