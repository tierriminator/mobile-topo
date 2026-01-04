import 'dart:async';
import 'dart:typed_data';

import 'bluetooth_adapter.dart';
import 'bluetooth_channel.dart';
import 'distox_service.dart';

/// macOS implementation of BluetoothAdapter using IOBluetooth via platform channel.
class MacOSBluetoothAdapter implements BluetoothAdapter {
  final _connectionStateController = StreamController<bool>.broadcast();

  StreamSubscription<BluetoothChannelState>? _stateSubscription;

  MacOSBluetoothAdapter() {
    // Forward BluetoothChannel state to our stream
    _stateSubscription =
        BluetoothChannel.instance.connectionState.listen((state) {
      _connectionStateController.add(state == BluetoothChannelState.connected);
    });
  }

  @override
  Future<bool> isAvailable() => BluetoothChannel.instance.isAvailable();

  @override
  Future<bool> isEnabled() => BluetoothChannel.instance.isPoweredOn();

  @override
  Future<bool> requestEnable() async {
    // macOS: user must enable Bluetooth in System Preferences
    return await BluetoothChannel.instance.isPoweredOn();
  }

  @override
  Future<List<DistoXDevice>> getBondedDevices() async {
    final devices = await BluetoothChannel.instance.getPairedDevices();
    return devices
        .where((d) => _isDistoXDevice(d.name))
        .map((d) => DistoXDevice(
              name: d.name,
              address: d.address,
              isBonded: true,
            ))
        .toList();
  }

  @override
  Stream<DistoXDevice> startDiscovery() async* {
    await BluetoothChannel.instance.startDiscovery();
    // Note: discovered devices come through method channel callback
    // For now, we just wait - the UI will update from getBondedDevices
  }

  @override
  Future<void> stopDiscovery() => BluetoothChannel.instance.stopDiscovery();

  @override
  Future<void> connect(String address) async {
    // Add Dart-side timeout as fallback (native timeout is 5s, this is 7s)
    // Fail fast - rely on reconnect to keep trying
    final success = await BluetoothChannel.instance
        .connect(address)
        .timeout(const Duration(seconds: 7));
    if (!success) {
      throw Exception('Connection failed');
    }
  }

  @override
  Future<void> disconnect() => BluetoothChannel.instance.disconnect();

  @override
  Future<void> send(Uint8List data) async {
    final success = await BluetoothChannel.instance.send(data);
    if (!success) {
      throw Exception('Send failed');
    }
  }

  @override
  Stream<Uint8List> get dataStream => BluetoothChannel.instance.dataStream;

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _connectionStateController.close();
  }

  bool _isDistoXDevice(String? name) {
    if (name == null) return false;
    return name.startsWith('DistoX') || name.startsWith('Disto');
  }
}
