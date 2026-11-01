import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechAdapter: IosSpeechAdapter?
  private var localStorageChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IosSpeechAdapter") {
      let adapter = IosSpeechAdapter(binaryMessenger: registrar.messenger())
      NativeSttHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: adapter)
      speechAdapter = adapter
    }

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "IosLocalStorageBackupExcluder"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "com.marcorable.maltto/local_storage",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "excludeApplicationSupportFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.excludeApplicationSupportFromBackup(result: result)
    }
    localStorageChannel = channel
  }

  private func excludeApplicationSupportFromBackup(result: @escaping FlutterResult) {
    guard var directory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      result(localStorageError())
      return
    }

    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
      result(nil)
    } catch {
      result(localStorageError())
    }
  }

  private func localStorageError() -> FlutterError {
    FlutterError(
      code: "local_storage_preparation_failed",
      message: "로컬 저장소를 준비하지 못했습니다.",
      details: nil
    )
  }
}
