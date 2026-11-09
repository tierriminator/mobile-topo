import 'dart:async';
import 'dart:typed_data';

import 'bluetooth_adapter.dart';
import 'bluetooth_channel.dart';
import 'distox_service.dart';

/// BluetoothAdapter of Android, macOS and iOS.
///
/// Talks to the app's own Bluetooth plugin over the shared
/// `mobile_topo/bluetooth` platform channel: `android/.../BluetoothPlugin.kt`,
/// `macos/Runner/BluetoothPlugin.swift` and `ios/Runner/BluetoothPlugin.swift`.
/// The DistoX2 is a Classic Bluetooth SPP device, which iOS cannot reach;
/// the DistoX BLE uses Bluetooth Low Energy, which all three can.
class PlatformBluetoothAdapter implements BluetoothAdapter {
  final _connectionStateController = StreamController<bool>.broadcast();

  StreamSubscription<BluetoothChannelState>? _stateSubscription;

  PlatformBluetoothAdapter() {
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
              ble: d.ble,
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
            ble: device.ble,
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
  Future<void> connect(DistoXDevice device) async {
    if (!await BluetoothChannel.instance.ensurePermissions()) {
      throw Exception('Bluetooth permission denied');
    }

    // Dart-side fallback slightly longer than the native timeout, which
    // gives BLE time to find the device's service too
    final success = await BluetoothChannel.instance
        .connect(device.address, ble: device.ble)
        .timeout(Duration(seconds: device.ble ? 12 : 7));
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
