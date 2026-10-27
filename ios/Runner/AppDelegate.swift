import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechAdapter: IosSpeechAdapter?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IosSpeechAdapter") else {
      return
    }
    let adapter = IosSpeechAdapter(binaryMessenger: registrar.messenger())
    NativeSttHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: adapter)
    speechAdapter = adapter
  }
}
