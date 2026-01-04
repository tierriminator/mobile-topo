import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../controllers/settings_controller.dart';
import 'bluetooth_channel.dart';
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
/// Supported platforms: Android (flutter_bluetooth_serial), macOS (IOBluetooth).
class DistoXService extends ChangeNotifier {
  final SettingsController _settings;
  final DistoXProtocol _protocol = DistoXProtocol();

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  Timer? _reconnectTimer;

  DistoXConnectionState _connectionState = DistoXConnectionState.disconnected;
  DistoXDevice? _connectedDevice;
  DistoXDevice? _selectedDevice;
  String? _lastError;

  // Buffer for incomplete packets
  final List<int> _buffer = [];

  // Callbacks
  void Function(DistoXMeasurement measurement)? onMeasurement;
  void Function(DistoXDevice device)? onConnectionSuccess;

  DistoXService(this._settings);

  DistoXConnectionState get connectionState => _connectionState;
  DistoXDevice? get connectedDevice => _connectedDevice;
  DistoXDevice? get selectedDevice => _selectedDevice;
  String? get lastError => _lastError;
  bool get autoReconnect => _settings.autoConnect;
  bool get isConnected => _connectionState == DistoXConnectionState.connected;

  /// Whether running on Android (uses flutter_bluetooth_serial)
  bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  /// Whether running on macOS (uses platform channel)
  bool get _isMacOS {
    try {
      return Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  /// Whether running on a platform that supports real Bluetooth
  bool get isPlatformSupported => _isAndroid || _isMacOS;

  /// Check if Bluetooth is available on this platform
  Future<bool> get isBluetoothAvailable async {
    if (_isMacOS) {
      return await BluetoothChannel.instance.isAvailable();
    }
    if (_isAndroid) {
      try {
        return await FlutterBluetoothSerial.instance.isAvailable ?? false;
      } catch (e) {
        debugPrint('Bluetooth not available: $e');
        return false;
      }
    }
    return false; // Unsupported platform
  }

  /// Check if Bluetooth is enabled
  Future<bool> get isBluetoothEnabled async {
    if (_isMacOS) {
      return await BluetoothChannel.instance.isPoweredOn();
    }
    if (_isAndroid) {
      try {
        return await FlutterBluetoothSerial.instance.isEnabled ?? false;
      } catch (e) {
        return false;
      }
    }
    return false; // Unsupported platform
  }

  /// Request to enable Bluetooth (Android only)
  Future<bool> requestEnableBluetooth() async {
    if (_isMacOS) {
      // macOS: user must enable Bluetooth in System Preferences
      return await BluetoothChannel.instance.isPoweredOn();
    }
    if (_isAndroid) {
      try {
        return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
      } catch (e) {
        debugPrint('Failed to request Bluetooth enable: $e');
        return false;
      }
    }
    return true;
  }

  /// Get list of bonded (paired) DistoX devices
  Future<List<DistoXDevice>> getBondedDevices() async {
    if (_isMacOS) {
      try {
        final devices = await BluetoothChannel.instance.getPairedDevices();
        return devices
            .where((d) => _isDistoXDevice(d.name))
            .map((d) => DistoXDevice(
                  name: d.name,
                  address: d.address,
                  isBonded: true,
                ))
            .toList();
      } catch (e) {
        debugPrint('Failed to get paired devices: $e');
        return [];
      }
    }
    if (_isAndroid) {
      try {
        final devices =
            await FlutterBluetoothSerial.instance.getBondedDevices();
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
    return []; // Unsupported platform
  }

  /// Start scanning for DistoX devices
  Stream<DistoXDevice> startDiscovery() async* {
    if (_isMacOS) {
      await BluetoothChannel.instance.startDiscovery();
      // Note: discovered devices come through method channel callback
      // For now, we just wait - the UI will update from getPairedDevices
      return;
    }
    if (_isAndroid) {
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
    // Unsupported platform - no devices to discover
  }

  /// Stop scanning
  Future<void> stopDiscovery() async {
    if (_isMacOS) {
      await BluetoothChannel.instance.stopDiscovery();
      return;
    }
    if (_isAndroid) {
      try {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      } catch (e) {
        debugPrint('Failed to cancel discovery: $e');
      }
    }
  }

  /// Select a device (stores for auto-reconnect)
  void selectDevice(DistoXDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  /// Attempt to auto-connect to a previously connected device.
  ///
  /// Returns true if connection was attempted (device found), false otherwise.
  /// The actual connection success is indicated by [onConnectionSuccess].
  Future<bool> tryAutoConnect(String? deviceAddress, String? deviceName) async {
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
      debugPrint('AutoConnect: device $deviceAddress not in bonded list, trying anyway');
      targetDevice = DistoXDevice(
        name: deviceName ?? 'DistoX',
        address: deviceAddress,
        isBonded: false,
      );
    }

    debugPrint('AutoConnect: attempting connection to ${targetDevice.name} (${targetDevice.address})');
    setAutoReconnect(true); // Enable auto-reconnect for this session
    connect(targetDevice);
    return true;
  }

  /// Set auto-reconnect option
  void setAutoReconnect(bool value) {
    _settings.autoConnect = value;
    notifyListeners();
  }

  StreamSubscription<Uint8List>? _macOSDataSubscription;
  StreamSubscription<BluetoothChannelState>? _macOSStateSubscription;

  /// Connect to a DistoX device
  Future<bool> connect(DistoXDevice device) async {
    // Only block if already actively connecting (not reconnecting - that's our trigger)
    if (_connectionState == DistoXConnectionState.connecting) {
      return false;
    }

    _cancelReconnect();
    _lastError = null;
    _connectionState = DistoXConnectionState.connecting;
    _selectedDevice = device;
    notifyListeners();

    // macOS: use platform channel
    if (_isMacOS) {
      try {
        final success =
            await BluetoothChannel.instance.connect(device.address);
        if (success) {
          _connectedDevice = device;
          _connectionState = DistoXConnectionState.connected;
          _protocol.reset();
          _buffer.clear();

          // Listen for incoming data from platform channel
          _macOSDataSubscription =
              BluetoothChannel.instance.dataStream.listen(
            _onDataReceived,
            onDone: _onDisconnected,
            onError: _onError,
          );

          // Listen for connection state changes (disconnect detection)
          _macOSStateSubscription =
              BluetoothChannel.instance.connectionState.listen((state) {
            if (state == BluetoothChannelState.disconnected &&
                _connectionState == DistoXConnectionState.connected) {
              debugPrint('macOS: connection state changed to disconnected');
              _onDisconnected();
            }
          });

          debugPrint('Connected to ${device.name} via macOS');
          notifyListeners();
          onConnectionSuccess?.call(device);
          return true;
        } else {
          _lastError = 'Connection failed';
          _connectionState = DistoXConnectionState.disconnected;
          notifyListeners();
          if (autoReconnect) {
            _scheduleReconnect();
          }
          return false;
        }
      } catch (e) {
        debugPrint('macOS connection failed: $e');
        _lastError = e.toString();
        _connectionState = DistoXConnectionState.disconnected;
        _connectedDevice = null;
        notifyListeners();
        if (autoReconnect) {
          _scheduleReconnect();
        }
        return false;
      }
    }

    // Android: use flutter_bluetooth_serial
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
      onConnectionSuccess?.call(device);
      return true;
    } catch (e) {
      debugPrint('Connection failed: $e');
      _lastError = e.toString();
      _connectionState = DistoXConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();

      if (autoReconnect) {
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
    await _macOSDataSubscription?.cancel();
    _macOSDataSubscription = null;
    await _macOSStateSubscription?.cancel();
    _macOSStateSubscription = null;

    if (_isMacOS) {
      await BluetoothChannel.instance.disconnect();
    } else {
      try {
        await _connection?.finish();
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }

    _connection = null;
    _connectedDevice = null;
    _connectionState = DistoXConnectionState.disconnected;
    _buffer.clear();
    notifyListeners();
  }

  /// Send raw data to device
  Future<void> _send(Uint8List data) async {
    if (_isMacOS) {
      final success = await BluetoothChannel.instance.send(data);
      if (!success) {
        throw StateError('Send failed');
      }
      return;
    }
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
    debugPrint('DistoX: received ${data.length} bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // Add to buffer
    _buffer.addAll(data);
    debugPrint('DistoX: buffer now has ${_buffer.length} bytes');

    // Process complete packets (8 bytes each)
    while (_buffer.length >= 8) {
      final packet = Uint8List.fromList(_buffer.sublist(0, 8));
      _buffer.removeRange(0, 8);

      final type = _protocol.getPacketType(packet);
      debugPrint('DistoX: packet type = $type (0x${type?.toRadixString(16) ?? "null"})');
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
        debugPrint('DistoX: Unknown packet type $type, ACKing anyway (seq bit $seqBit)');
        _send(_protocol.buildAcknowledge(seqBit)).catchError((e) {
          debugPrint('Failed to send ack for unknown type: $e');
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
    debugPrint('_scheduleReconnect: timer=${_reconnectTimer != null}, device=$_selectedDevice');
    if (_reconnectTimer != null) return;
    if (_selectedDevice == null) return;

    _connectionState = DistoXConnectionState.reconnecting;
    notifyListeners();

    debugPrint('_scheduleReconnect: scheduling reconnect in 5 seconds');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      debugPrint('_scheduleReconnect: timer fired, autoReconnect=$autoReconnect, device=$_selectedDevice');
      if (autoReconnect && _selectedDevice != null) {
        debugPrint('_scheduleReconnect: calling connect()');
        connect(_selectedDevice!);
      } else {
        debugPrint('_scheduleReconnect: skipping connect (autoReconnect=$autoReconnect)');
        _connectionState = DistoXConnectionState.disconnected;
        notifyListeners();
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
    _macOSDataSubscription?.cancel();
    _macOSStateSubscription?.cancel();
    _connection?.dispose();
    super.dispose();
  }
}
