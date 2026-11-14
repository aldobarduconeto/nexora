import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Remove titlebar and extend Flutter to full content view
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    let windowChannel = FlutterMethodChannel(
      name: "nexora/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "minimize":
        self?.miniaturize(nil)
        result(nil)
      case "maximize":
        self?.zoom(nil)
        result(nil)
      case "close":
        self?.close()
        result(nil)
      case "isMaximized":
        result(self?.isZoomed ?? false)
      case "startDragging":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let channel = FlutterMethodChannel(
      name: "nexora/permissions",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "check":
        result(self?.currentPermissions() ?? [:])
      case "request":
        self?.requestPermissions(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func currentPermissions() -> [String: Bool] {
    let camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    return [
      "camera": camera,
      "microphone": microphone,
      "notifications": true,
      "bluetooth": true,
    ]
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .video) { _ in
      AVCaptureDevice.requestAccess(for: .audio) { _ in
        DispatchQueue.main.async {
          result(self.currentPermissions())
        }
      }
    }
  }
}
