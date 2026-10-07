import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/calibration_service.dart';
import 'package:mobile_topo/services/distox_protocol.dart';
import 'package:mobile_topo/services/distox_service.dart';

/// Adapter that is never connected; shots are fed to the service directly.
class _OfflineAdapter implements BluetoothAdapter {
  @override
  Future<void> send(Uint8List data) async {}
  @override
  Stream<Uint8List> get dataStream => const Stream.empty();
  @override
  Stream<bool> get connectionStateStream => const Stream.empty();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<bool> requestEnable() async => true;
  @override
  Future<List<DistoXDevice>> getBondedDevices() async => const [];
  @override
  Stream<DistoXDevice> startDiscovery() => const Stream.empty();
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String address) async {}
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() {}
}

CalibrationService _service() =>
    CalibrationService(DistoXService(SettingsController(), _OfflineAdapter()));

/// Deliver one calibration shot as the device does: G packet, then M packet.
void _shoot(CalibrationService service, int number) {
  service.onCalibrationAccelPacket(CalibrationAccelPacket(
    gx: 100 + number,
    gy: 200,
    gz: 24000,
    measurementNumber: number,
    sequenceBit: 0,
  ));
  service.onCalibrationMagPacket(CalibrationMagPacket(
    mx: 9000,
    my: 300 + number,
    mz: 12000,
    measurementNumber: number,
    sequenceBit: 0,
  ));
}

void main() {
  group('shot sequence', () {
    test('the first shot fills the first slot', () {
      final service = _service();
      expect(service.suggestedNext?.slotIndex, 0);

      _shoot(service, 1);

      expect(service.filledSlots, {0});
      expect(service.measurements.single.direction, 0);
      expect(service.suggestedNext?.slotIndex, 1);
    });

    test('shots advance through the rolls of a direction', () {
      final service = _service();
      for (int i = 1; i <= 5; i++) {
        _shoot(service, i);
      }

      expect(service.filledSlots, {0, 1, 2, 3, 4});
      expect(service.measurements.map((m) => m.direction), [0, 0, 0, 0, 1]);
      expect(service.suggestedNext?.slotIndex, 5);
    });

    test('deleting the last shot asks for it again', () {
      final service = _service();
      for (int i = 1; i <= 3; i++) {
        _shoot(service, i);
      }

      service.deleteMeasurement(2);

      expect(service.measurementCount, 2);
      expect(service.filledSlots, {0, 1});
      expect(service.suggestedNext?.slotIndex, 2);

      _shoot(service, 4);

      expect(service.measurementCount, 3);
      expect(service.filledSlots, {0, 1, 2});
      expect(service.suggestedNext?.slotIndex, 3);
    });

    test('a shot replacing a deleted one takes its place and slot', () {
      final service = _service();
      for (int i = 1; i <= 4; i++) {
        _shoot(service, i);
      }

      service.deleteMeasurement(1);
      expect(service.filledSlots, {0, 2, 3});
      expect(service.suggestedNext?.slotIndex, 1);

      _shoot(service, 5);

      expect(service.measurementCount, 4);
      expect(service.filledSlots, {0, 1, 2, 3});
      // The new shot sits at index 1; the shots behind it keep their slots.
      expect(service.measurements[1].gx, 105);
      expect(service.measurements[2].gx, 103);
      expect(service.suggestedNext?.slotIndex, 4);
    });
  });
}
