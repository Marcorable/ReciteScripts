import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechAdapter: IosSpeechAdapter?
  private var localStorageAdapter: IosLocalStorageAdapter?

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
    let adapter = IosLocalStorageAdapter()
    LocalStorageHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: adapter)
    localStorageAdapter = adapter
  }
}
