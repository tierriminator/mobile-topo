import CoreBluetooth
import Foundation

/// Bluetooth Low Energy link to a DistoX BLE, shared by the macOS and iOS
/// Bluetooth plugins.
///
/// The DistoX BLE (`docs/distox6/Disto xble comm protocol.pdf`) has one
/// service with a characteristic to write commands to and one notifying
/// the packets it sends. This only moves bytes; the Dart side
/// (`lib/services/distox_framing.dart`) knows what they mean.
///
/// Devices are told apart by the identifier CoreBluetooth gives them, which
/// stands in for the Bluetooth address. Everything runs on the main queue,
/// where Flutter calls the plugins.
final class BleCentral: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let writeUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let notifyUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    /// A DistoX found while scanning, with its name and identifier
    var onDeviceFound: ((String, String) -> Void)?

    /// The scan ended after its duration
    var onScanComplete: (() -> Void)?

    /// One notification of the connected device
    var onData: ((Data) -> Void)?

    /// The connected device went away
    var onDisconnected: (() -> Void)?

    /// Created on first use, as that asks the user for Bluetooth access
    private var createdManager: CBCentralManager?
    private var manager: CBCentralManager {
        if let manager = createdManager { return manager }
        let manager = CBCentralManager(delegate: self, queue: .main)
        createdManager = manager
        return manager
    }

    /// Waiting for the manager to know whether Bluetooth is on
    private var stateWaiters: [(CBManagerState) -> Void] = []

    /// Devices seen while scanning, so that they can be connected to
    private var seen: [UUID: CBPeripheral] = [:]
    private var reported: Set<UUID> = []
    private var scanEnd: DispatchWorkItem?

    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var pendingConnect: ((Bool) -> Void)?
    private var connectTimeout: DispatchWorkItem?

    /// Completions of writes waiting for the device's response, in order
    private var pendingWrites: [(Bool) -> Void] = []

    var isConnected: Bool { peripheral != nil && pendingConnect == nil }

    // MARK: - Adapter state

    /// The manager's state once it is known
    func state(_ completion: @escaping (CBManagerState) -> Void) {
        let current = manager.state
        if current == .unknown || current == .resetting {
            stateWaiters.append(completion)
        } else {
            completion(current)
        }
    }

    func isAvailable(_ completion: @escaping (Bool) -> Void) {
        state { completion($0 != .unsupported) }
    }

    func isPoweredOn(_ completion: @escaping (Bool) -> Void) {
        state { completion($0 == .poweredOn) }
    }

    // MARK: - Scanning

    /// Scan for DistoX devices for [duration] seconds
    func startScan(duration: TimeInterval) {
        state { [weak self] state in
            guard let self = self else { return }
            guard state == .poweredOn else {
                self.onScanComplete?()
                return
            }
            self.stopScan()
            self.reported.removeAll()
            self.manager.scanForPeripherals(withServices: nil, options: nil)

            let end = DispatchWorkItem { [weak self] in
                self?.stopScan()
                self?.onScanComplete?()
            }
            self.scanEnd = end
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: end)
        }
    }

    func stopScan() {
        scanEnd?.cancel()
        scanEnd = nil
        if let manager = createdManager, manager.state == .poweredOn, manager.isScanning {
            manager.stopScan()
        }
    }

    // MARK: - Connection

    /// Connect to the device with [identifier], subscribing to its packets
    func connect(identifier: String, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        disconnect()
        guard let uuid = UUID(uuidString: identifier) else {
            completion(false)
            return
        }

        pendingConnect = completion
        let timeoutItem = DispatchWorkItem { [weak self] in
            NSLog("BleCentral: connect to \(identifier) timed out")
            self?.disconnect()
        }
        connectTimeout = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

        state { [weak self] state in
            guard let self = self, self.pendingConnect != nil else { return }
            guard state == .poweredOn,
                  let target = self.seen[uuid]
                    ?? self.manager.retrievePeripherals(withIdentifiers: [uuid]).first else {
                self.finishConnect(false)
                return
            }
            self.stopScan()
            self.peripheral = target
            target.delegate = self
            self.manager.connect(target, options: nil)
        }
    }

    func disconnect() {
        let target = peripheral
        peripheral = nil
        writeCharacteristic = nil
        failPendingWrites()
        finishConnect(false)
        if let target = target {
            manager.cancelPeripheralConnection(target)
        }
    }

    /// Write [data] to the device; completes once the device has it
    func send(_ data: Data, completion: @escaping (Bool) -> Void) {
        guard isConnected, let target = peripheral, let characteristic = writeCharacteristic else {
            NSLog("BleCentral: send failed - not connected")
            completion(false)
            return
        }
        if characteristic.properties.contains(.write) {
            pendingWrites.append(completion)
            target.writeValue(data, for: characteristic, type: .withResponse)
        } else {
            target.writeValue(data, for: characteristic, type: .withoutResponse)
            completion(true)
        }
    }

    private func finishConnect(_ success: Bool) {
        connectTimeout?.cancel()
        connectTimeout = nil
        guard let completion = pendingConnect else { return }
        pendingConnect = nil
        if !success, let target = peripheral {
            peripheral = nil
            writeCharacteristic = nil
            manager.cancelPeripheralConnection(target)
        }
        completion(success)
    }

    private func failPendingWrites() {
        let writes = pendingWrites
        pendingWrites.removeAll()
        writes.forEach { $0(false) }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        if state == .unknown || state == .resetting { return }
        let waiters = stateWaiters
        stateWaiters.removeAll()
        waiters.forEach { $0(state) }

        if state != .poweredOn && peripheral != nil {
            // Connections end when Bluetooth goes off, without a callback
            let wasConnected = isConnected
            peripheral = nil
            writeCharacteristic = nil
            failPendingWrites()
            finishConnect(false)
            if wasConnected { onDisconnected?() }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let name = name, name.hasPrefix("Disto") else { return }
        seen[peripheral.identifier] = peripheral
        if reported.insert(peripheral.identifier).inserted {
            onDeviceFound?(name, peripheral.identifier.uuidString)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        peripheral.discoverServices([BleCentral.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        guard peripheral == self.peripheral else { return }
        NSLog("BleCentral: connect failed: \(error?.localizedDescription ?? "unknown")")
        peripheral.delegate = nil
        self.peripheral = nil
        finishConnect(false)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard peripheral == self.peripheral else { return }
        NSLog("BleCentral: disconnected: \(error?.localizedDescription ?? "by request")")
        let wasConnected = isConnected
        self.peripheral = nil
        writeCharacteristic = nil
        failPendingWrites()
        finishConnect(false)
        if wasConnected { onDisconnected?() }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard let service = peripheral.services?.first(where: { $0.uuid == BleCentral.serviceUUID }) else {
            NSLog("BleCentral: DistoX service not found")
            finishConnect(false)
            return
        }
        peripheral.discoverCharacteristics([BleCentral.writeUUID, BleCentral.notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard peripheral == self.peripheral else { return }
        let characteristics = service.characteristics ?? []
        guard let write = characteristics.first(where: { $0.uuid == BleCentral.writeUUID }),
              let notify = characteristics.first(where: { $0.uuid == BleCentral.notifyUUID }) else {
            NSLog("BleCentral: DistoX characteristics not found")
            finishConnect(false)
            return
        }
        writeCharacteristic = write
        peripheral.setNotifyValue(true, for: notify)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == BleCentral.notifyUUID else { return }
        // Connected once the device's packets reach us
        finishConnect(error == nil && characteristic.isNotifying)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == BleCentral.notifyUUID,
              error == nil, let value = characteristic.value else { return }
        onData?(value)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral == self.peripheral, !pendingWrites.isEmpty else { return }
        if let error = error {
            NSLog("BleCentral: write failed: \(error.localizedDescription)")
        }
        pendingWrites.removeFirst()(error == nil)
    }
}
