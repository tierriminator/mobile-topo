import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

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
class DistoXService extends ChangeNotifier {
  final DistoXProtocol _protocol = DistoXProtocol();

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  Timer? _reconnectTimer;

  DistoXConnectionState _connectionState = DistoXConnectionState.disconnected;
  DistoXDevice? _connectedDevice;
  DistoXDevice? _selectedDevice;
  String? _lastError;
  bool _autoReconnect = false;

  // Buffer for incomplete packets
  final List<int> _buffer = [];

  // Callbacks
  void Function(DistoXMeasurement measurement)? onMeasurement;

  DistoXConnectionState get connectionState => _connectionState;
  DistoXDevice? get connectedDevice => _connectedDevice;
  DistoXDevice? get selectedDevice => _selectedDevice;
  String? get lastError => _lastError;
  bool get autoReconnect => _autoReconnect;
  bool get isConnected => _connectionState == DistoXConnectionState.connected;

  /// Check if Bluetooth is available on this platform
  Future<bool> get isBluetoothAvailable async {
    try {
      return await FlutterBluetoothSerial.instance.isAvailable ?? false;
    } catch (e) {
      debugPrint('Bluetooth not available: $e');
      return false;
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> get isBluetoothEnabled async {
    try {
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request to enable Bluetooth (Android only)
  Future<bool> requestEnableBluetooth() async {
    try {
      return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
    } catch (e) {
      debugPrint('Failed to request Bluetooth enable: $e');
      return false;
    }
  }

  /// Get list of bonded (paired) DistoX devices
  Future<List<DistoXDevice>> getBondedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices
          .where((d) => _isDistoXDevice(d.name))
          .map((d) => DistoXDevice(
                name: d.name ?? 'Unknown',
                address: d.address,
                isBonded: d.isBonded,
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to get bonded devices: $e');
      return [];
    }
  }

  /// Start scanning for DistoX devices
  Stream<DistoXDevice> startDiscovery() async* {
    try {
      await for (final result
          in FlutterBluetoothSerial.instance.startDiscovery()) {
        if (_isDistoXDevice(result.device.name)) {
          yield DistoXDevice(
            name: result.device.name ?? 'Unknown',
            address: result.device.address,
            isBonded: result.device.isBonded,
          );
        }
      }
    } catch (e) {
      debugPrint('Discovery error: $e');
    }
  }

  /// Stop scanning
  Future<void> stopDiscovery() async {
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (e) {
      debugPrint('Failed to cancel discovery: $e');
    }
  }

  /// Select a device (stores for auto-reconnect)
  void selectDevice(DistoXDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  /// Set auto-reconnect option
  void setAutoReconnect(bool value) {
    _autoReconnect = value;
    notifyListeners();
  }

  /// Connect to a DistoX device
  Future<bool> connect(DistoXDevice device) async {
    if (_connectionState == DistoXConnectionState.connecting ||
        _connectionState == DistoXConnectionState.reconnecting) {
      return false;
    }

    _cancelReconnect();
    _lastError = null;
    _connectionState = DistoXConnectionState.connecting;
    _selectedDevice = device;
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      _connectionState = DistoXConnectionState.connected;
      _protocol.reset();
      _buffer.clear();

      // Listen for incoming data
      _inputSubscription = _connection!.input?.listen(
        _onDataReceived,
        onDone: _onDisconnected,
        onError: _onError,
      );

      debugPrint('Connected to ${device.name}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Connection failed: $e');
      _lastError = e.toString();
      _connectionState = DistoXConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();

      if (_autoReconnect) {
        _scheduleReconnect();
      }
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _cancelReconnect();
    await _inputSubscription?.cancel();
    _inputSubscription = null;

    try {
      await _connection?.finish();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _connection = null;
    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _buffer.clear();
    notifyListeners();
  }

  /// Send raw data to device
  Future<void> _send(Uint8List data) async {
    if (_connection == null || !_connection!.isConnected) {
      throw StateError('Not connected');
    }
    _connection!.output.add(data);
    await _connection!.output.allSent;
  }

  /// Send acknowledge for a measurement
  Future<void> _acknowledge(DistoXMeasurement measurement) async {
    final ack = _protocol.buildAcknowledgeFor(measurement);
    await _send(ack);
  }

  void _onDataReceived(Uint8List data) {
    // Add to buffer
    _buffer.addAll(data);

    // Process complete packets (8 bytes each)
    while (_buffer.length >= 8) {
      final packet = Uint8List.fromList(_buffer.sublist(0, 8));
      _buffer.removeRange(0, 8);

      final type = _protocol.getPacketType(packet);
      if (type == DistoXPacketType.measurement) {
        try {
          final measurement = _protocol.parseMeasurementPacket(packet);
          if (measurement != null) {
            // Send acknowledge
            _acknowledge(measurement).catchError((e) {
              debugPrint('Failed to send ack: $e');
            });

            // Notify listeners
            debugPrint('Received: $measurement');
            onMeasurement?.call(measurement);
          }
        } catch (e) {
          debugPrint('Failed to parse measurement: $e');
        }
      } else if (type == DistoXPacketType.calibrationAccel ||
          type == DistoXPacketType.calibrationMag) {
        // Calibration packets - acknowledge but ignore for now
        final seqBit = (packet[0] >> 7) & 0x01;
        _send(_protocol.buildAcknowledge(seqBit)).catchError((e) {
          debugPrint('Failed to send calibration ack: $e');
        });
      }
    }
  }

  void _onDisconnected() {
    debugPrint('DistoX disconnected');
    _connection = null;
    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _buffer.clear();
    notifyListeners();

    if (_autoReconnect && _selectedDevice != null) {
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

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_autoReconnect && _selectedDevice != null) {
        connect(_selectedDevice!);
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Check if device name matches DistoX pattern (DistoX-nnnn)
  bool _isDistoXDevice(String? name) {
    if (name == null) return false;
    return name.startsWith('DistoX') || name.startsWith('Disto');
  }

  @override
  void dispose() {
    _cancelReconnect();
    _inputSubscription?.cancel();
    _connection?.dispose();
    super.dispose();
  }
}
