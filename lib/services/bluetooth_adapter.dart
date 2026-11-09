import 'dart:async';
import 'dart:typed_data';

import 'distox_service.dart';

/// Abstract interface for platform-specific Bluetooth operations.
///
/// `PlatformBluetoothAdapter` implements it for Android, macOS and iOS with
/// the app's own native plugins.
abstract class BluetoothAdapter {
  /// Check if Bluetooth is available on this device
  Future<bool> isAvailable();

  /// Check if Bluetooth is currently enabled
  Future<bool> isEnabled();

  /// Request to enable Bluetooth (may show system dialog)
  Future<bool> requestEnable();

  /// Get list of paired/bonded DistoX devices
  Future<List<DistoXDevice>> getBondedDevices();

  /// Start scanning for DistoX devices, over Bluetooth Classic and Low
  /// Energy where the platform has them
  Stream<DistoXDevice> startDiscovery();

  /// Stop scanning
  Future<void> stopDiscovery();

  /// Connect to [device], over Bluetooth Low Energy if it is a DistoX BLE.
  /// Throws on failure.
  Future<void> connect(DistoXDevice device);

  /// Disconnect from current device
  Future<void> disconnect();

  /// Send data to connected device.
  /// Throws on failure.
  Future<void> send(Uint8List data);

  /// Stream of incoming data from connected device
  Stream<Uint8List> get dataStream;

  /// Stream of connection state changes (true = connected, false = disconnected)
  Stream<bool> get connectionStateStream;

  /// Dispose resources
  void dispose();
}
