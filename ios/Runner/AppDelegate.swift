import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Фоновая синхронизация: регистрация BGTaskScheduler-задачи
    // (идентификатор совпадает с Dart-стороной и Info.plist).
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.myhealth.bgSync",
      frequency: NSNumber(value: 4 * 60 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Мост к нативному BLE-SDK кольца JCRing X3.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RingBlePlugin") {
      RingBlePlugin.register(with: registrar)
    }
  }
}
