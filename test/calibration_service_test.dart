import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/calibration_service.dart';
import 'package:mobile_topo/services/distox_protocol.dart';
import 'package:mobile_topo/services/distox_service.dart';
import 'package:mobile_topo/utils/matrix_helpers.dart';
import 'package:vector_math/vector_math.dart';

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

double _rad(double deg) => deg * math.pi / 180;

Matrix3 _rotX(double w) => matrix3FromRowMajor([
      1, 0, 0, //
      0, math.cos(w), -math.sin(w), //
      0, math.sin(w), math.cos(w), //
    ]);

Matrix3 _rotY(double w) => matrix3FromRowMajor([
      math.cos(w), 0, math.sin(w), //
      0, 1, 0, //
      -math.sin(w), 0, math.cos(w), //
    ]);

Matrix3 _rotZ(double w) => matrix3FromRowMajor([
      math.cos(w), -math.sin(w), 0, //
      math.sin(w), math.cos(w), 0, //
      0, 0, 1, //
    ]);

/// Deliver a shot taken at [yaw] (bearing), [pitch] and [roll] in degrees,
/// as raw counts of a slightly distorted sensor pair.
void _shootAt(
  CalibrationService service,
  int number,
  double yaw,
  double pitch,
  double roll,
) {
  const alpha = 27.0; // angle between gravity and magnetic field
  final down = Vector3(0, 0, 1);
  final body = _rotX(-_rad(roll)).multiplied(_rotY(-_rad(pitch)));
  final field =
      body.multiplied(_rotZ(-_rad(yaw))).multiplied(_rotY(_rad(alpha)));
  final pG = matrix3FromRowMajor([
    16200, 130, -90, //
    -70, 15850, 210, //
    140, 60, 16050, //
  ]);
  final pM = matrix3FromRowMajor([
    15000, -260, 175, //
    310, 15450, -120, //
    -85, 195, 14550, //
  ]);
  final g = pG.transformVector(body.transformVector(down)) +
      Vector3(180, -240, 95);
  final m = pM.transformVector(field.transformVector(down)) +
      Vector3(-620, 410, 730);

  service.onCalibrationAccelPacket(CalibrationAccelPacket(
    gx: g.x.round(),
    gy: g.y.round(),
    gz: g.z.round(),
    measurementNumber: number,
    sequenceBit: 0,
  ));
  service.onCalibrationMagPacket(CalibrationMagPacket(
    mx: m.x.round(),
    my: m.y.round(),
    mz: m.z.round(),
    measurementNumber: number,
    sequenceBit: 0,
  ));
}

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

    test('undoing the last shot asks for it again', () {
      final service = _service();
      for (int i = 1; i <= 3; i++) {
        _shoot(service, i);
      }

      service.undoLastShot();

      expect(service.measurementCount, 2);
      expect(service.filledSlots, {0, 1});
      expect(service.suggestedNext?.slotIndex, 2);

      _shoot(service, 4);

      expect(service.measurementCount, 3);
      expect(service.filledSlots, {0, 1, 2});
      expect(service.suggestedNext?.slotIndex, 3);
    });

    test('undo goes back shot by shot to the start', () {
      final service = _service();
      _shoot(service, 1);
      _shoot(service, 2);

      service.undoLastShot();
      service.undoLastShot();

      expect(service.canUndoLastShot, isFalse);
      expect(service.measurementCount, 0);
      expect(service.suggestedNext?.slotIndex, 0);
    });
  });

  group('flagged directions', () {
    /// Shoot all 56 slots as asked, facing [forward], with [aim] giving the
    /// actual (bearing offset, inclination) of a shot that is off target.
    Future<CalibrationService> calibrate({
      (double, double)? Function(int direction, int roll)? aim,
    }) async {
      const forward = 30.0;
      final service = _service();
      for (int n = 1; service.suggestedNext != null; n++) {
        final next = service.suggestedNext!;
        final (bearing, inclination) =
            aim?.call(next.direction, next.rollIndex) ??
                CalibrationPositions.relativeDirections[next.direction];
        _shootAt(service, n, forward + bearing, inclination,
            next.rollIndex * 90.0);
      }
      await pumpEventQueue();
      await service.evaluate();
      return service;
    }

    test('none when every shot is on target', () async {
      final service = await calibrate();

      expect(service.rmsError, lessThan(CalibrationService.errorThreshold));
      expect(service.flaggedDirections, isEmpty);
    });

    test('a group shot off its target point has a high error', () async {
      // One shot of Right misses the target point by 3°.
      final service = await calibrate(
        aim: (d, r) => d == 1 && r == 2 ? (93.0, 0.0) : null,
      );

      final flagged = service.flaggedDirections;
      expect(flagged.keys, [1]);
      expect(flagged[1]!.highError,
          greaterThanOrEqualTo(CalibrationService.errorThreshold));
    });

    test('a direction shot the wrong way is misaligned', () async {
      // Right-Back, upper corner is shot towards Back-Left instead.
      final (backLeft, upper) = CalibrationPositions.relativeDirections[6];
      final service = await calibrate(
        aim: (d, r) => d == 5 ? (backLeft, upper) : null,
      );

      final flagged = service.flaggedDirections;
      expect(flagged.keys, [5]);
      expect(flagged[5]!.misaligned, isTrue);
    });

    test('retaking a flagged direction on target clears it', () async {
      final (backLeft, upper) = CalibrationPositions.relativeDirections[6];
      final service = await calibrate(
        aim: (d, r) => d == 5 ? (backLeft, upper) : null,
      );

      service.retakeDirection(5);
      expect(service.flaggedDirections, isEmpty,
          reason: 'nothing is flagged while slots are open');
      for (int n = 100; service.suggestedNext != null; n++) {
        final next = service.suggestedNext!;
        expect(next.direction, 5);
        final (bearing, inclination) =
            CalibrationPositions.relativeDirections[5];
        _shootAt(service, n, 30 + bearing, inclination, next.rollIndex * 90.0);
      }
      await pumpEventQueue();
      await service.evaluate();

      expect(service.measurementCount, 56);
      expect(service.flaggedDirections, isEmpty);
    });
  });

  group('direction retake', () {
    test('discards the four shots of the direction and asks for them', () {
      final service = _service();
      for (int i = 1; i <= 12; i++) {
        _shoot(service, i);
      }

      service.retakeDirection(1);

      expect(service.measurementCount, 8);
      expect(service.filledSlots, {0, 1, 2, 3, 8, 9, 10, 11});
      expect(service.measurements.map((m) => m.direction),
          [0, 0, 0, 0, 2, 2, 2, 2]);
      expect(service.suggestedNext?.slotIndex, 4);
    });

    test('new shots refill the direction, then the slots are complete', () {
      final service = _service();
      for (int i = 1; i <= 12; i++) {
        _shoot(service, i);
      }
      service.retakeDirection(1);

      for (int i = 13; i <= 16; i++) {
        _shoot(service, i);
      }

      expect(service.filledSlots, {for (int s = 0; s < 12; s++) s});
      expect(service.measurements.where((m) => m.direction == 1).map((m) => m.gx),
          [113, 114, 115, 116]);
      expect(service.suggestedNext?.slotIndex, 12);
    });

    test('undo only reaches back to the start of the retake', () {
      final service = _service();
      for (int i = 1; i <= 8; i++) {
        _shoot(service, i);
      }
      service.retakeDirection(0);
      expect(service.canUndoLastShot, isFalse);

      _shoot(service, 9);
      expect(service.canUndoLastShot, isTrue);
      service.undoLastShot();

      expect(service.canUndoLastShot, isFalse);
      expect(service.measurementCount, 4);
      expect(service.measurements.every((m) => m.direction == 1), isTrue);
      expect(service.suggestedNext?.slotIndex, 0);
    });
  });
}
