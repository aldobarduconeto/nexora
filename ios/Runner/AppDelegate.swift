import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NexoraPermissions") {
      let channel = FlutterMethodChannel(
        name: "nexora/permissions",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "check":
          self?.checkPermissions(result: result)
        case "request":
          self?.requestPermissions(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NexoraNotifications") {
      let notifChannel = FlutterMethodChannel(
        name: "nexora/notifications",
        binaryMessenger: registrar.messenger()
      )
      notifChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "show":
          guard let args = call.arguments as? [String: Any],
                let title = args["title"] as? String,
                let body = args["body"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing", details: nil))
            return
          }
          let id = (args["id"] as? Int).map { String($0) } ?? UUID().uuidString
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = UNNotificationSound.default
          if let payload = args["payload"] as? String {
            content.userInfo = ["payload": payload]
          }
          let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
          UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
              result(error == nil)
            }
          }
        case "clearAll":
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func checkPermissions(result: @escaping FlutterResult) {
    let camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let notifications = settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional
      DispatchQueue.main.async {
        result([
          "camera": camera,
          "microphone": microphone,
          "notifications": notifications,
          "bluetooth": true,
        ])
      }
    }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .video) { _ in
      AVCaptureDevice.requestAccess(for: .audio) { _ in
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
          self.checkPermissions(result: result)
        }
      }
    }
  }
}
