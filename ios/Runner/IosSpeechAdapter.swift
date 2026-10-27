import AVFAudio
import Flutter
import Foundation
import Speech
import UIKit

@MainActor
final class IosSpeechAdapter: NSObject, NativeSttHostApi {
  private let flutterApi: NativeSttFlutterApi
  private var activeSession: IosSpeechSession?
  private var backgroundObserver: NSObjectProtocol?

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = NativeSttFlutterApi(binaryMessenger: binaryMessenger)
    super.init()
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.cancelActiveSession(emitCancelled: true)
      }
    }
  }

  deinit {
    if let backgroundObserver {
      NotificationCenter.default.removeObserver(backgroundObserver)
    }
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
    guard activeSession == nil else {
      throw PigeonError(code: "busy", message: "An STT session is already active.", details: nil)
    }
    guard Self.microphonePermission() == .granted, Self.speechPermission() == .granted else {
      throw PigeonError(code: "permissionDenied", message: "STT permission is not granted.", details: nil)
    }
    guard SpeechTranscriber.isAvailable else {
      throw PigeonError(code: "onDeviceUnavailable", message: "On-device STT is unavailable.", details: nil)
    }
    let requestedLocale = Locale(identifier: request.locale)
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
      throw PigeonError(code: "localeUnsupported", message: "The locale is unsupported.", details: nil)
    }
    let transcriber = Self.makeTranscriber(locale: locale)
    guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
      throw PigeonError(code: "modelMissing", message: "The on-device model is not installed.", details: nil)
    }

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
    do {
      try await session.start()
    } catch {
      if activeSession === session { activeSession = nil }
      await session.cancel(emitEvent: false)
      throw Self.pigeonError(from: error)
    }
  }

  func cancel(sessionId: String) async throws {
    guard activeSession?.sessionId == sessionId else { return }
    await cancelActiveSession(emitCancelled: true)
  }

  func dispose() async throws {
    await cancelActiveSession(emitCancelled: false)
  }

  private func cancelActiveSession(emitCancelled: Bool) async {
    guard let session = activeSession else { return }
    await session.cancel(emitEvent: emitCancelled)
    if activeSession === session { activeSession = nil }
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
