import Cocoa
import FlutterMacOS
import IOBluetooth

/// Flutter plugin for Classic Bluetooth SPP on macOS
class BluetoothPlugin: NSObject, FlutterPlugin, IOBluetoothRFCOMMChannelDelegate {
    private var channel: FlutterMethodChannel?
    private var dataChannel: FlutterEventChannel?
    private var stateChannel: FlutterEventChannel?

    private var dataSink: FlutterEventSink?
    private var stateSink: FlutterEventSink?

    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    private var connectedDevice: IOBluetoothDevice?
    private var inquiry: IOBluetoothDeviceInquiry?

    // Standard SPP UUID
    private let sppUUID = IOBluetoothSDPUUID(uuid16: 0x1101)

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BluetoothPlugin()

        instance.channel = FlutterMethodChannel(
            name: "mobile_topo/bluetooth",
            binaryMessenger: registrar.messenger
        )
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)

        instance.dataChannel = FlutterEventChannel(
            name: "mobile_topo/bluetooth/data",
            binaryMessenger: registrar.messenger
        )
        instance.dataChannel?.setStreamHandler(DataStreamHandler(plugin: instance))

        instance.stateChannel = FlutterEventChannel(
            name: "mobile_topo/bluetooth/state",
            binaryMessenger: registrar.messenger
        )
        instance.stateChannel?.setStreamHandler(StateStreamHandler(plugin: instance))
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true) // IOBluetooth is always available on macOS

        case "isPoweredOn":
            // Check if Bluetooth is powered on
            let powered = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
            result(powered)

        case "getPairedDevices":
            result(getPairedDevices())

        case "startDiscovery":
            startDiscovery()
            result(nil)

        case "stopDiscovery":
            stopDiscovery()
            result(nil)

        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            connect(address: address, result: result)

        case "disconnect":
            disconnect()
            result(nil)

        case "send":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
                return
            }
            let success = send(data: data.data)
            result(success)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getPairedDevices() -> [[String: Any]] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        // Return all paired devices - filtering happens in Dart layer
        return devices.compactMap { device -> [String: Any]? in
            guard let name = device.name,
                  let address = device.addressString else {
                return nil
            }

            return [
                "name": name,
                "address": address
            ]
        }
    }

    private func startDiscovery() {
        inquiry?.stop()
        inquiry = IOBluetoothDeviceInquiry(delegate: self)
        inquiry?.updateNewDeviceNames = true
        inquiry?.start()
    }

    private func stopDiscovery() {
        inquiry?.stop()
        inquiry = nil
    }

    private func connect(address: String, result: @escaping FlutterResult) {
        // Clean up existing connection
        disconnect()

        stateSink?("connecting")

        // Find device by address
        guard let device = IOBluetoothDevice(addressString: address) else {
            result(false)
            stateSink?("disconnected")
            return
        }

        // Find SPP service on device
        guard let serviceRecord = findSPPService(device: device) else {
            // Try connecting anyway with default channel
            connectToDevice(device: device, channelID: 1, result: result)
            return
        }

        // Get RFCOMM channel ID from service record
        var channelID: BluetoothRFCOMMChannelID = 0
        if serviceRecord.getRFCOMMChannelID(&channelID) != kIOReturnSuccess {
            channelID = 1 // Default to channel 1
        }

        connectToDevice(device: device, channelID: channelID, result: result)
    }

    private func findSPPService(device: IOBluetoothDevice) -> IOBluetoothSDPServiceRecord? {
        guard let services = device.services as? [IOBluetoothSDPServiceRecord],
              let uuid = sppUUID else {
            return nil
        }

        for service in services {
            if service.hasService(from: [uuid]) {
                return service
            }
        }
        return nil
    }

    private var pendingConnectResult: FlutterResult?

    private func connectToDevice(device: IOBluetoothDevice, channelID: BluetoothRFCOMMChannelID, result: @escaping FlutterResult) {
        var channel: IOBluetoothRFCOMMChannel?
        NSLog("BluetoothPlugin: opening RFCOMM channel \(channelID) to \(device.addressString ?? "unknown")")

        let status = device.openRFCOMMChannelAsync(
            &channel,
            withChannelID: channelID,
            delegate: self
        )

        if status == kIOReturnSuccess {
            self.rfcommChannel = channel
            self.connectedDevice = device
            self.pendingConnectResult = result
            NSLog("BluetoothPlugin: RFCOMM channel opening async...")
            // Result will be returned in rfcommChannelOpenComplete
        } else {
            NSLog("BluetoothPlugin: RFCOMM channel open failed with status \(status)")
            result(false)
            stateSink?("disconnected")
        }
    }

    private func disconnect() {
        rfcommChannel?.close()
        rfcommChannel = nil
        connectedDevice?.closeConnection()
        connectedDevice = nil
        stateSink?("disconnected")
    }

    private func send(data: Data) -> Bool {
        guard let channel = rfcommChannel, channel.isOpen() else {
            NSLog("BluetoothPlugin: send failed - channel not open")
            return false
        }

        var mutableData = data
        let result = mutableData.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> IOReturn in
            guard let baseAddress = bytes.baseAddress else { return kIOReturnError }
            return channel.writeSync(baseAddress, length: UInt16(data.count))
        }

        let success = result == kIOReturnSuccess
        NSLog("BluetoothPlugin: send \(data.count) bytes, result: \(success ? "success" : "failed (\(result))")")
        return success
    }

    // MARK: - IOBluetoothRFCOMMChannelDelegate

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        NSLog("BluetoothPlugin: rfcommChannelOpenComplete, status: \(error)")
        if error == kIOReturnSuccess {
            NSLog("BluetoothPlugin: channel opened successfully, isOpen: \(rfcommChannel?.isOpen() ?? false)")
            pendingConnectResult?(true)
            pendingConnectResult = nil
            stateSink?("connected")
        } else {
            NSLog("BluetoothPlugin: channel open failed with error \(error)")
            pendingConnectResult?(false)
            pendingConnectResult = nil
            stateSink?("disconnected")
        }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        NSLog("BluetoothPlugin: channel closed")
        self.rfcommChannel = nil
        stateSink?("disconnected")
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        NSLog("BluetoothPlugin: received \(dataLength) bytes: \(hexString)")
        if let sink = dataSink {
            sink(FlutterStandardTypedData(bytes: data))
            NSLog("BluetoothPlugin: forwarded to Flutter")
        } else {
            NSLog("BluetoothPlugin: WARNING - dataSink is nil, data not forwarded!")
        }
    }

    // MARK: - Stream Handlers

    class DataStreamHandler: NSObject, FlutterStreamHandler {
        weak var plugin: BluetoothPlugin?

        init(plugin: BluetoothPlugin) {
            self.plugin = plugin
        }

        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin?.dataSink = events
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin?.dataSink = nil
            return nil
        }
    }

    class StateStreamHandler: NSObject, FlutterStreamHandler {
        weak var plugin: BluetoothPlugin?

        init(plugin: BluetoothPlugin) {
            self.plugin = plugin
        }

        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin?.stateSink = events
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin?.stateSink = nil
            return nil
        }
    }
}

// MARK: - IOBluetoothDeviceInquiryDelegate

extension BluetoothPlugin: IOBluetoothDeviceInquiryDelegate {
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let name = device.name, let address = device.addressString else { return }

        // Only report DistoX devices
        if name.hasPrefix("DistoX") || name.hasPrefix("Disto") {
            // Send discovered device through method channel
            channel?.invokeMethod("onDeviceDiscovered", arguments: [
                "name": name,
                "address": address
            ])
        }
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        channel?.invokeMethod("onDiscoveryComplete", arguments: nil)
    }
}
