import Flutter
import UIKit

/// Flutter plugin for Bluetooth on iOS, with the shared `BleCentral`.
///
/// Speaks the channel contract of macos/Runner/BluetoothPlugin.swift, but
/// only over Bluetooth Low Energy: iOS cannot reach Classic SPP devices like
/// the DistoX2 without Apple MFi enrollment, so only the DistoX BLE works
/// here. Connecting to a Classic device fails.
class BluetoothPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var dataChannel: FlutterEventChannel?
    private var stateChannel: FlutterEventChannel?

    private var dataSink: FlutterEventSink?
    private var stateSink: FlutterEventSink?

    private let ble = BleCentral()

    /// Seconds a scan runs
    private let scanDuration: TimeInterval = 10

    /// Seconds to connect, which also finds the DistoX service
    private let connectTimeout: TimeInterval = 10

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BluetoothPlugin()
        let messenger = registrar.messenger()

        instance.channel = FlutterMethodChannel(name: "mobile_topo/bluetooth", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)

        instance.dataChannel = FlutterEventChannel(name: "mobile_topo/bluetooth/data", binaryMessenger: messenger)
        instance.dataChannel?.setStreamHandler(StreamHandler { [weak instance] in instance?.dataSink = $0 })
        instance.stateChannel = FlutterEventChannel(name: "mobile_topo/bluetooth/state", binaryMessenger: messenger)
        instance.stateChannel?.setStreamHandler(StreamHandler { [weak instance] in instance?.stateSink = $0 })

        instance.ble.onDeviceFound = { [weak instance] name, identifier in
            instance?.channel?.invokeMethod("onDeviceDiscovered", arguments: [
                "name": name,
                "address": identifier,
                "ble": true
            ])
        }
        instance.ble.onScanComplete = { [weak instance] in
            instance?.channel?.invokeMethod("onDiscoveryComplete", arguments: nil)
        }
        instance.ble.onData = { [weak instance] data in
            instance?.dataSink?(FlutterStandardTypedData(bytes: data))
        }
        instance.ble.onDisconnected = { [weak instance] in instance?.stateSink?("disconnected") }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            ble.isAvailable { result($0) }

        case "isPoweredOn":
            ble.isPoweredOn { result($0) }

        case "getPairedDevices":
            // BLE devices are not paired; they are found by scanning
            result([[String: Any]]())

        case "startDiscovery":
            ble.startScan(duration: scanDuration)
            result(nil)

        case "stopDiscovery":
            ble.stopScan()
            result(nil)

        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            guard args["ble"] as? Bool == true else {
                NSLog("BluetoothPlugin: Classic Bluetooth is not available on iOS")
                result(false)
                return
            }
            ble.disconnect()
            stateSink?("connecting")
            ble.connect(identifier: address, timeout: connectTimeout) { [weak self] success in
                self?.stateSink?(success ? "connected" : "disconnected")
                result(success)
            }

        case "disconnect":
            ble.disconnect()
            stateSink?("disconnected")
            result(nil)

        case "send":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
                return
            }
            ble.send(data.data) { result($0) }

        default:
            // requestEnable and ensurePermissions: iOS asks for Bluetooth
            // access itself on first use
            result(FlutterMethodNotImplemented)
        }
    }

    private class StreamHandler: NSObject, FlutterStreamHandler {
        private let setSink: (FlutterEventSink?) -> Void

        init(_ setSink: @escaping (FlutterEventSink?) -> Void) {
            self.setSink = setSink
        }

        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            setSink(events)
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            setSink(nil)
            return nil
        }
    }
}
