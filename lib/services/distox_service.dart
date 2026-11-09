import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/settings_controller.dart';
import 'bluetooth_adapter.dart';
import 'distox_framing.dart';
import 'distox_protocol.dart';

/// Connection state for DistoX device
enum DistoXConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Represents a discovered DistoX device
class DistoXDevice {
  final String name;

  /// The Bluetooth address, or on iOS and for BLE devices on macOS the
  /// identifier the system gives the device
  final String address;
  final bool isBonded;

  /// Whether this is a DistoX BLE, reached over Bluetooth Low Energy rather
  /// than Bluetooth Classic SPP
  final bool ble;

  const DistoXDevice({
    required this.name,
    required this.address,
    this.isBonded = false,
    this.ble = false,
  });

  @override
  String toString() => 'DistoXDevice($name, $address)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistoXDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// Service for connecting to and communicating with DistoX devices.
///
/// The DistoX2 uses classic Bluetooth SPP (Serial Port Profile) as specified
/// in the DistoX protocol documentation, the DistoX BLE Bluetooth Low Energy
/// with the same protocol wrapped by [BleFraming].
///
/// Platform-specific Bluetooth operations are delegated to [BluetoothAdapter].
class DistoXService extends ChangeNotifier {
  final SettingsController _settings;
  final BluetoothAdapter _adapter;
  final DistoXProtocol _protocol = DistoXProtocol();

  Timer? _reconnectTimer;
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<bool>? _stateSubscription;

  DistoXConnectionState _connectionState = DistoXConnectionState.disconnected;
  DistoXDevice? _connectedDevice;
  DistoXDevice? _selectedDevice;
  String? _lastError;

  // How packets travel to and from the connected device
  DistoXFraming _framing = ClassicFraming();

  // Callbacks
  void Function(DistoXMeasurement measurement)? onMeasurement;
  void Function(DistoXDevice device)? onConnectionSuccess;
  void Function(CalibrationAccelPacket packet)? onCalibrationAccel;
  void Function(CalibrationMagPacket packet)? onCalibrationMag;
  void Function(DistoXMemoryReply reply)? onMemoryReply;

  DistoXService(this._settings, this._adapter);

  DistoXConnectionState get connectionState => _connectionState;
  DistoXDevice? get connectedDevice => _connectedDevice;
  DistoXDevice? get selectedDevice => _selectedDevice;
  String? get lastError => _lastError;
  bool get autoReconnect => _settings.autoConnect;
  bool get isConnected => _connectionState == DistoXConnectionState.connected;

  /// Check if Bluetooth is available on this platform
  Future<bool> get isBluetoothAvailable => _adapter.isAvailable();

  /// Check if Bluetooth is enabled
  Future<bool> get isBluetoothEnabled => _adapter.isEnabled();

  /// Request to enable Bluetooth
  Future<bool> requestEnableBluetooth() => _adapter.requestEnable();

  /// Get list of bonded (paired) DistoX devices
  Future<List<DistoXDevice>> getBondedDevices() => _adapter.getBondedDevices();

  /// Start scanning for DistoX devices
  Stream<DistoXDevice> startDiscovery() => _adapter.startDiscovery();

  /// Stop scanning
  Future<void> stopDiscovery() => _adapter.stopDiscovery();

  /// Select a device (stores for auto-reconnect)
  void selectDevice(DistoXDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  /// Attempt to auto-connect to a previously connected device.
  ///
  /// Returns true if connection was attempted (device found), false otherwise.
  /// The actual connection success is indicated by [onConnectionSuccess].
  Future<bool> tryAutoConnect(String? deviceAddress, String? deviceName,
      {bool ble = false}) async {
    if (deviceAddress == null) {
      debugPrint('AutoConnect: no stored device address');
      return false;
    }

    if (!await isBluetoothAvailable) {
      debugPrint('AutoConnect: Bluetooth not available');
      return false;
    }

    if (!await isBluetoothEnabled) {
      debugPrint('AutoConnect: Bluetooth not enabled');
      return false;
    }

    // Look for the device in bonded devices
    final bondedDevices = await getBondedDevices();
    DistoXDevice? targetDevice;

    for (final device in bondedDevices) {
      if (device.address == deviceAddress) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice == null) {
      // Device not found in bonded list, create one with stored info
      debugPrint(
          'AutoConnect: device $deviceAddress not in bonded list, trying anyway');
      targetDevice = DistoXDevice(
        name: deviceName ?? 'DistoX',
        address: deviceAddress,
        isBonded: false,
        ble: ble,
      );
    }

    debugPrint(
        'AutoConnect: attempting connection to ${targetDevice.name} (${targetDevice.address})');
    setAutoReconnect(true); // Enable auto-reconnect for this session
    connect(targetDevice);
    return true;
  }

  /// Set auto-reconnect option
  void setAutoReconnect(bool value) {
    _settings.autoConnect = value;
    notifyListeners();
  }

  /// Connect to a DistoX device
  Future<bool> connect(DistoXDevice device) async {
    if (_connectionState == DistoXConnectionState.connecting) {
      return false;
    }

    _cancelReconnect();
    _lastError = null;
    _connectionState = DistoXConnectionState.connecting;
    _selectedDevice = device;
    notifyListeners();

    try {
      await _adapter.connect(device);
      _setupDataSubscription();
      _finishConnectionSuccess(device);
      return true;
    } on TimeoutException {
      _finishConnectionFailed('Connection timeout');
      return false;
    } catch (e) {
      _finishConnectionFailed(e.toString());
      return false;
    }
  }

  void _setupDataSubscription() {
    // Drop subscriptions from an earlier connection; the data stream is a
    // broadcast stream, so they would otherwise receive every packet too
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();

    // Listen for incoming data
    _dataSubscription = _adapter.dataStream.listen(
      _onDataReceived,
      onDone: _onDisconnected,
      onError: _onError,
    );

    // Listen for connection state changes (disconnect detection)
    _stateSubscription = _adapter.connectionStateStream.listen((connected) {
      if (!connected && _connectionState == DistoXConnectionState.connected) {
        debugPrint('Bluetooth: connection state changed to disconnected');
        _onDisconnected();
      }
    });
  }

  void _finishConnectionSuccess(DistoXDevice device) {
    _connectedDevice = device;
    _connectionState = DistoXConnectionState.connected;
    _protocol.reset();
    _framing = device.ble ? BleFraming() : ClassicFraming();
    debugPrint('Connected to ${device.name}');
    notifyListeners();
    onConnectionSuccess?.call(device);
  }

  void _finishConnectionFailed(String error) {
    _lastError = error;
    _connectionState = DistoXConnectionState.disconnected;
    _connectedDevice = null;
    notifyListeners();
    if (autoReconnect && _selectedDevice != null) {
      _scheduleReconnect();
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _cancelReconnect();
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;

    await _adapter.disconnect();

    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _framing.reset();
    notifyListeners();
  }

  /// Send raw data to device
  Future<void> _send(Uint8List data) async {
    await _adapter.send(data);
  }

  /// Send a DistoX2 command to the device, encoded for its link.
  ///
  /// This is used by CalibrationService for sending calibration commands
  /// and memory read/write commands.
  Future<void> sendCommand(Uint8List data) async {
    if (!isConnected) {
      throw StateError('Not connected to device');
    }
    await _send(_framing.encode(data));
  }

  void _onDataReceived(Uint8List data) {
    debugPrint(
        'DistoX: received ${data.length} bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    for (final packet in _framing.receive(data)) {
      // Acknowledge data packets, even duplicates: the DistoX sends a packet
      // again until it is acknowledged. Unknown ones too, so that they do
      // not block the ones after them
      final ack = _framing.acknowledge(packet);
      if (ack != null) {
        _send(ack).catchError((e) {
          debugPrint('Failed to send ack: $e');
        });
      }

      final type = _protocol.getPacketType(packet);
      debugPrint(
          'DistoX: packet type = $type (0x${type?.toRadixString(16) ?? "null"})');
      if (type == DistoXPacketType.measurement) {
        try {
          final measurement = _protocol.parseMeasurementPacket(packet);
          if (measurement != null) {
            // Notify listeners (only for non-duplicate measurements)
            debugPrint('Received: $measurement');
            onMeasurement?.call(measurement);
          } else {
            debugPrint('Duplicate packet ignored');
          }
        } catch (e) {
          debugPrint('Failed to parse measurement: $e');
        }
      } else if (type == DistoXPacketType.calibrationAccel) {
        final parsed = _protocol.parseCalibrationAccelPacket(packet);
        if (parsed != null) {
          onCalibrationAccel?.call(parsed);
        }
      } else if (type == DistoXPacketType.calibrationMag) {
        final parsed = _protocol.parseCalibrationMagPacket(packet);
        if (parsed != null) {
          onCalibrationMag?.call(parsed);
        }
      } else if (type == DistoXPacketType.memoryReply) {
        final reply = parseMemoryReply(packet);
        if (reply != null) {
          onMemoryReply?.call(reply);
        }
      }
      // Vector packets only carry quality information
    }
  }

  void _onDisconnected() {
    debugPrint('DistoX disconnected');
    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _framing.reset();
    notifyListeners();

    if (autoReconnect && _selectedDevice != null) {
      _scheduleReconnect();
    }
  }

  void _onError(dynamic error) {
    debugPrint('DistoX error: $error');
    _lastError = error.toString();
    _onDisconnected();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    if (_selectedDevice == null) return;

    _connectionState = DistoXConnectionState.reconnecting;
    notifyListeners();

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _reconnectTimer = null;
      if (autoReconnect && _selectedDevice != null) {
        connect(_selectedDevice!);
      } else {
        _connectionState = DistoXConnectionState.disconnected;
        notifyListeners();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  void dispose() {
    _cancelReconnect();
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _adapter.dispose();
    super.dispose();
  }
}
