import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'bluetooth_adapter.dart';
import 'distox_service.dart';

/// Android implementation of BluetoothAdapter using flutter_bluetooth_serial.
class AndroidBluetoothAdapter implements BluetoothAdapter {
  BluetoothConnection? _connection;
  final _connectionStateController = StreamController<bool>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();

  StreamSubscription<Uint8List>? _inputSubscription;

  @override
  Future<bool> isAvailable() async {
    try {
      return await FlutterBluetoothSerial.instance.isAvailable ?? false;
    } catch (e) {
      debugPrint('Bluetooth not available: $e');
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestEnable() async {
    try {
      return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
    } catch (e) {
      debugPrint('Failed to request Bluetooth enable: $e');
      return false;
    }
  }

  @override
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

  @override
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

  @override
  Future<void> stopDiscovery() async {
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (e) {
      debugPrint('Failed to cancel discovery: $e');
    }
  }

  @override
  Future<void> connect(String address) async {
    // Add timeout to prevent hanging on unavailable device
    _connection = await BluetoothConnection.toAddress(address)
        .timeout(const Duration(seconds: 10));

    // Listen for incoming data
    _inputSubscription = _connection!.input?.listen(
      (data) => _dataController.add(data),
      onDone: () => _connectionStateController.add(false),
      onError: (e) {
        debugPrint('Bluetooth error: $e');
        _connectionStateController.add(false);
      },
    );

    _connectionStateController.add(true);
  }

  @override
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;

    try {
      await _connection?.finish();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _connection = null;
    _connectionStateController.add(false);
  }

  @override
  Future<void> send(Uint8List data) async {
    if (_connection == null || !_connection!.isConnected) {
      throw StateError('Not connected');
    }
    _connection!.output.add(data);
    await _connection!.output.allSent;
  }

  @override
  Stream<Uint8List> get dataStream => _dataController.stream;

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _connection?.dispose();
    _connectionStateController.close();
    _dataController.close();
  }

  bool _isDistoXDevice(String? name) {
    if (name == null) return false;
    return name.startsWith('DistoX') || name.startsWith('Disto');
  }
}
