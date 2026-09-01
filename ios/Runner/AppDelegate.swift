import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       Self.isValidMapsApiKey(mapsApiKey) {
      GMSServices.provideAPIKey(mapsApiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "MapConfiguration"
    ) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "mn.carcare.carcare_customer_mobile/map_configuration",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "isConfigured" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
      result(apiKey.map(Self.isValidMapsApiKey) ?? false)
    }
  }

  private static func isValidMapsApiKey(_ value: String) -> Bool {
    let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return !key.isEmpty && !key.contains("$(")
  }
}
