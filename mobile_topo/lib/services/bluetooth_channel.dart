import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel interface for Classic Bluetooth operations.
///
/// Used on macOS where flutter_bluetooth_serial is not available.
class BluetoothChannel {
  static const MethodChannel _channel = MethodChannel('mobile_topo/bluetooth');
  static const EventChannel _dataChannel =
      EventChannel('mobile_topo/bluetooth/data');
  static const EventChannel _stateChannel =
      EventChannel('mobile_topo/bluetooth/state');

  static BluetoothChannel? _instance;
  static BluetoothChannel get instance => _instance ??= BluetoothChannel._();

  BluetoothChannel._() {
    _stateChannel.receiveBroadcastStream().listen(_onStateEvent);
  }

  final _connectionStateController =
      StreamController<BluetoothChannelState>.broadcast();
  Stream<BluetoothChannelState> get connectionState =>
      _connectionStateController.stream;

  Stream<Uint8List>? _dataStream;
  BluetoothChannelState _currentState = BluetoothChannelState.disconnected;

  BluetoothChannelState get currentState => _currentState;

  void _onStateEvent(dynamic event) {
    if (event is String) {
      switch (event) {
        case 'connected':
          _currentState = BluetoothChannelState.connected;
        case 'disconnected':
          _currentState = BluetoothChannelState.disconnected;
        case 'connecting':
          _currentState = BluetoothChannelState.connecting;
      }
      _connectionStateController.add(_currentState);
    }
  }

  /// Check if Bluetooth is available
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Bluetooth availability check failed: $e');
      return false;
    }
  }

  /// Check if Bluetooth is powered on
  Future<bool> isPoweredOn() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPoweredOn');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Bluetooth power check failed: $e');
      return false;
    }
  }

  /// Get list of paired devices
  Future<List<BluetoothChannelDevice>> getPairedDevices() async {
    try {
      final result = await _channel.invokeMethod<List>('getPairedDevices');
      if (result == null) return [];

      return result.map((device) {
        final map = Map<String, dynamic>.from(device as Map);
        return BluetoothChannelDevice(
          name: map['name'] as String? ?? 'Unknown',
          address: map['address'] as String,
        );
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get paired devices: $e');
      return [];
    }
  }

  /// Start device discovery
  Future<void> startDiscovery() async {
    try {
      await _channel.invokeMethod('startDiscovery');
    } on PlatformException catch (e) {
      debugPrint('Failed to start discovery: $e');
    }
  }

  /// Stop device discovery
  Future<void> stopDiscovery() async {
    try {
      await _channel.invokeMethod('stopDiscovery');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop discovery: $e');
    }
  }

  /// Connect to a device by address
  Future<bool> connect(String address) async {
    try {
      final result = await _channel.invokeMethod<bool>('connect', {
        'address': address,
      });
      if (result == true) {
        _currentState = BluetoothChannelState.connected;
        _connectionStateController.add(_currentState);
      }
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Connection failed: $e');
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _currentState = BluetoothChannelState.disconnected;
      _connectionStateController.add(_currentState);
    } on PlatformException catch (e) {
      debugPrint('Disconnect failed: $e');
    }
  }

  /// Send data to connected device
  Future<bool> send(Uint8List data) async {
    try {
      final result = await _channel.invokeMethod<bool>('send', {
        'data': data,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Send failed: $e');
      return false;
    }
  }

  /// Get stream of incoming data
  Stream<Uint8List> get dataStream {
    _dataStream ??= _dataChannel
        .receiveBroadcastStream()
        .map((data) => Uint8List.fromList(List<int>.from(data as List)));
    return _dataStream!;
  }

  void dispose() {
    _connectionStateController.close();
  }
}

/// Connection state for platform channel Bluetooth
enum BluetoothChannelState {
  disconnected,
  connecting,
  connected,
}

/// Device info from platform channel
class BluetoothChannelDevice {
  final String name;
  final String address;

  BluetoothChannelDevice({
    required this.name,
    required this.address,
  });

  @override
  String toString() => 'BluetoothChannelDevice($name, $address)';
}
