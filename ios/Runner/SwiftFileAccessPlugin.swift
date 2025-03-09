import Flutter
import UIKit

public class SwiftFileAccessPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "file_access", binaryMessenger: registrar.messenger())
    let instance = SwiftFileAccessPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getAppDocumentsPath" {
      let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      result(paths.first?.path)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
