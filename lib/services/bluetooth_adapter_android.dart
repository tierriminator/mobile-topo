import 'dart:async';
import 'dart:typed_data';

import 'bluetooth_adapter.dart';
import 'bluetooth_channel.dart';
import 'distox_service.dart';

/// Android implementation of BluetoothAdapter.
///
/// Talks to the app's own RFCOMM plugin
/// (`android/.../BluetoothPlugin.kt`) over the shared `mobile_topo/bluetooth`
/// platform channel. The DistoX is a Classic Bluetooth SPP device, so BLE
/// packages cannot be used here.
class AndroidBluetoothAdapter implements BluetoothAdapter {
  final _connectionStateController = StreamController<bool>.broadcast();

  StreamSubscription<BluetoothChannelState>? _stateSubscription;

  AndroidBluetoothAdapter() {
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
  Future<bool> requestEnable() => BluetoothChannel.instance.requestEnable();

  @override
  Future<List<DistoXDevice>> getBondedDevices() async {
    // Android 12+ returns nothing without BLUETOOTH_CONNECT.
    await BluetoothChannel.instance.ensurePermissions();

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
  Stream<DistoXDevice> startDiscovery() {
    final controller = StreamController<DistoXDevice>();
    StreamSubscription<BluetoothChannelDevice>? deviceSubscription;
    StreamSubscription<void>? completeSubscription;

    Future<void> cleanUp() async {
      await deviceSubscription?.cancel();
      await completeSubscription?.cancel();
      deviceSubscription = null;
      completeSubscription = null;
    }

    controller.onListen = () async {
      // Scanning needs BLUETOOTH_SCAN on Android 12+, location below that.
      if (!await BluetoothChannel.instance.ensurePermissions()) {
        await controller.close();
        return;
      }

      deviceSubscription =
          BluetoothChannel.instance.discoveredDevices.listen((device) {
        if (_isDistoXDevice(device.name)) {
          controller.add(DistoXDevice(
            name: device.name,
            address: device.address,
            isBonded: false,
          ));
        }
      });

      completeSubscription =
          BluetoothChannel.instance.discoveryComplete.listen((_) {
        controller.close();
      });

      await BluetoothChannel.instance.startDiscovery();
    };

    controller.onCancel = () async {
      await cleanUp();
      await BluetoothChannel.instance.stopDiscovery();
    };

    return controller.stream;
  }

  @override
  Future<void> stopDiscovery() => BluetoothChannel.instance.stopDiscovery();

  @override
  Future<void> connect(String address) async {
    if (!await BluetoothChannel.instance.ensurePermissions()) {
      throw Exception('Bluetooth permission denied');
    }

    // Dart-side fallback slightly longer than the 5s native timeout.
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
