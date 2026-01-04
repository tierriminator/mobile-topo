import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/settings_controller.dart';
import 'bluetooth_adapter.dart';
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
  final String address;
  final bool isBonded;

  const DistoXDevice({
    required this.name,
    required this.address,
    this.isBonded = false,
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
/// Uses classic Bluetooth SPP (Serial Port Profile) as specified in the
/// DistoX protocol documentation.
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

  // Buffer for incomplete packets
  final List<int> _buffer = [];

  // Callbacks
  void Function(DistoXMeasurement measurement)? onMeasurement;
  void Function(DistoXDevice device)? onConnectionSuccess;

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
  Future<bool> tryAutoConnect(
      String? deviceAddress, String? deviceName) async {
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
    // Only block if already actively connecting
    if (_connectionState == DistoXConnectionState.connecting) {
      return false;
    }

    _cancelReconnect();
    _lastError = null;
    _connectionState = DistoXConnectionState.connecting;
    _selectedDevice = device;
    notifyListeners();

    try {
      await _adapter.connect(device.address);
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
    _buffer.clear();
    debugPrint('Connected to ${device.name}');
    notifyListeners();
    onConnectionSuccess?.call(device);
  }

  void _finishConnectionFailed(String error) {
    debugPrint('Connection failed: $error');
    _lastError = error;
    _connectionState = DistoXConnectionState.disconnected;
    _connectedDevice = null;
    notifyListeners();
    if (autoReconnect) {
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
    _buffer.clear();
    notifyListeners();
  }

  /// Send raw data to device
  Future<void> _send(Uint8List data) async {
    await _adapter.send(data);
  }

  void _onDataReceived(Uint8List data) {
    debugPrint(
        'DistoX: received ${data.length} bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // Add to buffer
    _buffer.addAll(data);
    debugPrint('DistoX: buffer now has ${_buffer.length} bytes');

    // Process complete packets (8 bytes each)
    while (_buffer.length >= 8) {
      final packet = Uint8List.fromList(_buffer.sublist(0, 8));
      _buffer.removeRange(0, 8);

      final type = _protocol.getPacketType(packet);
      debugPrint(
          'DistoX: packet type = $type (0x${type?.toRadixString(16) ?? "null"})');
      if (type == DistoXPacketType.measurement) {
        // Always send ACK for measurement packets, even duplicates
        // DistoX will retry if it doesn't receive ACK
        final seqBit = (packet[0] >> 7) & 0x01;
        _send(_protocol.buildAcknowledge(seqBit)).then((_) {
          debugPrint('Sent ACK for seq bit $seqBit');
        }).catchError((e) {
          debugPrint('Failed to send ack: $e');
        });

        try {
          final measurement = _protocol.parseMeasurementPacket(packet);
          if (measurement != null) {
            // Notify listeners (only for non-duplicate measurements)
            debugPrint('Received: $measurement');
            onMeasurement?.call(measurement);
          } else {
            debugPrint('Duplicate packet ignored (seq bit $seqBit)');
          }
        } catch (e) {
          debugPrint('Failed to parse measurement: $e');
        }
      } else if (type == DistoXPacketType.calibrationAccel ||
          type == DistoXPacketType.calibrationMag ||
          type == DistoXPacketType.vector) {
        // Calibration/vector packets - acknowledge but ignore for now
        final seqBit = (packet[0] >> 7) & 0x01;
        debugPrint('DistoX: ACKing type $type packet (seq bit $seqBit)');
        _send(_protocol.buildAcknowledge(seqBit)).catchError((e) {
          debugPrint('Failed to send ack for type $type: $e');
        });
      } else {
        // Unknown packet type - still acknowledge to avoid blocking
        final seqBit = (packet[0] >> 7) & 0x01;
        debugPrint(
            'DistoX: Unknown packet type $type, ACKing anyway (seq bit $seqBit)');
        _send(_protocol.buildAcknowledge(seqBit)).catchError((e) {
          debugPrint('Failed to send ack for unknown type: $e');
        });
      }
    }
  }

  void _onDisconnected() {
    debugPrint('DistoX disconnected');
    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _buffer.clear();
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
    debugPrint(
        '_scheduleReconnect: timer=${_reconnectTimer != null}, device=$_selectedDevice');
    if (_reconnectTimer != null) return;
    if (_selectedDevice == null) return;

    _connectionState = DistoXConnectionState.reconnecting;
    notifyListeners();

    debugPrint('_scheduleReconnect: scheduling reconnect in 5 seconds');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      debugPrint(
          '_scheduleReconnect: timer fired, autoReconnect=$autoReconnect, device=$_selectedDevice');
      if (autoReconnect && _selectedDevice != null) {
        debugPrint('_scheduleReconnect: calling connect()');
        connect(_selectedDevice!);
      } else {
        debugPrint(
            '_scheduleReconnect: skipping connect (autoReconnect=$autoReconnect)');
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
