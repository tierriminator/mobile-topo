import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var displayChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the Bluetooth plugin
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let registrar = controller.registrar(forPlugin: "BluetoothPlugin")
      BluetoothPlugin.register(with: registrar)

      // Report the physical size of logical pixels, mirroring
      // android/.../DisplayPlugin.kt
      displayChannel = FlutterMethodChannel(
        name: "mobile_topo/display",
        binaryMessenger: controller.engine.binaryMessenger
      )
      displayChannel?.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "logicalPixelsPerMm":
          result(self?.logicalPixelsPerMm())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// Points (Flutter's logical pixels on macOS) per millimetre on the screen
  /// showing the main window, or nil if the display doesn't report its size
  private func logicalPixelsPerMm() -> Double? {
    guard let screen = mainFlutterWindow?.screen ?? NSScreen.main,
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
        as? NSNumber
    else { return nil }
    let sizeMm = CGDisplayScreenSize(CGDirectDisplayID(number.uint32Value))
    guard sizeMm.width > 0 else { return nil }
    return Double(screen.frame.width / sizeMm.width)
  }
}
