import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/calibration_diagnosis.dart';
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

/// How a calibration shot is actually taken: bearing offset from Forward,
/// inclination and roll in degrees, and the disturbances of [_shootAt].
class _Shot {
  final double bearing;
  final double inclination;
  final double roll;
  final double gravityScale;
  final double dipOffset;

  const _Shot(
    this.bearing,
    this.inclination,
    this.roll, {
    this.gravityScale = 1,
    this.dipOffset = 0,
  });

  _Shot copyWith({
    double? bearing,
    double? inclination,
    double? roll,
    double? gravityScale,
    double? dipOffset,
  }) =>
      _Shot(
        bearing ?? this.bearing,
        inclination ?? this.inclination,
        roll ?? this.roll,
        gravityScale: gravityScale ?? this.gravityScale,
        dipOffset: dipOffset ?? this.dipOffset,
      );
}

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
///
/// [gravityScale] scales the gravity reading, as the accelerometer measuring
/// the device's movement on top of gravity would. [dipOffset] tilts the
/// magnetic field by that many degrees, as a local disturbance would.
void _shootAt(
  CalibrationService service,
  int number,
  double yaw,
  double pitch,
  double roll, {
  double gravityScale = 1,
  double dipOffset = 0,
}) {
  final alpha = 27.0 + dipOffset; // angle between gravity and magnetic field
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
  final g = pG.transformVector(body.transformVector(down) * gravityScale) +
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

  group('diagnosis', () {
    const limit = CalibrationService.errorThreshold;

    /// Shoot the slots that are open as asked, facing [forward]. [shot]
    /// changes how a slot is actually shot; it gets the asked bearing offset,
    /// inclination and roll and returns null to shoot as asked.
    Future<void> shootOpenSlots(
      CalibrationService service, {
      _Shot? Function(int direction, int roll, _Shot asked)? shot,
    }) async {
      const forward = 30.0;
      for (int n = service.measurementCount + 1;
          service.suggestedNext != null;
          n++) {
        final next = service.suggestedNext!;
        final (bearing, inclination) =
            CalibrationPositions.relativeDirections[next.direction];
        final asked = _Shot(bearing, inclination, next.rollIndex * 90.0);
        final actual = shot?.call(next.direction, next.rollIndex, asked) ?? asked;
        _shootAt(
          service,
          n,
          forward + actual.bearing,
          actual.inclination,
          actual.roll,
          gravityScale: actual.gravityScale,
          dipOffset: actual.dipOffset,
        );
      }
      await pumpEventQueue();
      await service.evaluate();
    }

    Future<CalibrationService> calibrate({
      _Shot? Function(int direction, int roll, _Shot asked)? shot,
    }) async {
      final service = _service();
      await shootOpenSlots(service, shot: shot);
      return service;
    }

    /// Which shot of each horizontal direction misses, and how: a different
    /// orientation and side for each, as real misses are. The same miss in
    /// every group would look like a misalignment between laser and sensors,
    /// which is what the groups calibrate away.
    const misses = {
      0: (roll: 2, side: MissSide.above),
      1: (roll: 0, side: MissSide.below),
      2: (roll: 3, side: MissSide.right),
      3: (roll: 1, side: MissSide.left),
    };

    /// One shot of each horizontal direction aims [degrees] off the point
    /// the other three hit, as [misses] says, which drives the error over the
    /// limit.
    _Shot? missTargets(int d, int r, _Shot asked, {double degrees = 5}) {
      final miss = misses[d];
      if (miss == null || miss.roll != r) return null;
      return switch (miss.side) {
        MissSide.above =>
          asked.copyWith(inclination: asked.inclination + degrees),
        MissSide.below =>
          asked.copyWith(inclination: asked.inclination - degrees),
        MissSide.right => asked.copyWith(bearing: asked.bearing + degrees),
        MissSide.left => asked.copyWith(bearing: asked.bearing - degrees),
      };
    }

    test('reports nothing when every shot is on target', () async {
      final service = await calibrate();

      expect(service.rmsError, lessThan(limit));
      expect(service.diagnosis.isOk, isTrue);
    });

    test('reports nothing while the error is within the limit', () async {
      // A free direction shot the wrong way does not affect the calibration.
      final (backLeft, upper) = CalibrationPositions.relativeDirections[6];
      final service = await calibrate(
        shot: (d, r, asked) =>
            d == 5 ? asked.copyWith(bearing: backLeft, inclination: upper) : null,
      );

      expect(service.rmsError, lessThan(limit));
      expect(service.diagnosis.isOk, isTrue);
    });

    test('names the shots that miss their target, and aiming as the cause',
        () async {
      final service = await calibrate(shot: missTargets);

      expect(service.rmsError, greaterThanOrEqualTo(limit));
      final diagnosis = service.diagnosis;
      expect(diagnosis.problem, CalibrationProblem.aiming);
      expect(diagnosis.directions.keys, unorderedEquals([0, 1, 2, 3]));
      for (final MapEntry(key: d, value: issues) in diagnosis.directions.entries) {
        expect(issues, hasLength(1), reason: 'direction $d: $issues');
        final issue = issues.single;
        expect(issue.problem, ShotProblem.offTarget);
        expect(issue.rollIndex, misses[d]!.roll, reason: 'direction $d');
        expect(issue.side, misses[d]!.side, reason: 'direction $d');
        expect(issue.degrees, closeTo(5, 1), reason: 'direction $d');
      }
    });

    test('names a direction shot the wrong way once the error is high',
        () async {
      final (backLeft, upper) = CalibrationPositions.relativeDirections[6];
      final service = await calibrate(
        shot: (d, r, asked) => d == 5
            ? asked.copyWith(bearing: backLeft, inclination: upper)
            : missTargets(d, r, asked),
      );

      final issues = service.diagnosis.directions[5]!;
      expect(issues, hasLength(4));
      expect(issues.every((i) => i.problem == ShotProblem.wrongDirection),
          isTrue);
      // The two upper corners are acos(1/3) = 70.5° apart.
      expect(issues.first.degrees, closeTo(70.5, 3));
    });

    test('names a shot held in the wrong orientation', () async {
      // The second shot of Forward-Right, lower corner is held display left
      // instead of display right.
      final service = await calibrate(
        shot: (d, r, asked) => d == 8 && r == 1
            ? asked.copyWith(roll: 270)
            : missTargets(d, r, asked),
      );

      final issue = service.diagnosis.directions[8]!.single;
      expect(issue.problem, ShotProblem.wrongOrientation);
      expect(issue.rollIndex, 1);
      expect(issue.actualRollIndex, 3);
    });

    test('blames movement when gravity readings differ', () async {
      // The accelerometer adds up to 2% of movement to the corner shots.
      final service = await calibrate(
        shot: (d, r, asked) => d >= 4 && d < 12
            ? asked.copyWith(gravityScale: r.isEven ? 1.02 : 0.98)
            : null,
      );

      expect(service.rmsError, greaterThanOrEqualTo(limit));
      final diagnosis = service.diagnosis;
      expect(diagnosis.problem, CalibrationProblem.unsteady);
      expect(
        diagnosis.directions.values
            .expand((issues) => issues)
            .every((i) => i.problem == ShotProblem.unsteady),
        isTrue,
      );
    });

    test('blames the magnetic field when the dip differs', () async {
      // The field tilts by up to 1.5° between the corner shots.
      final service = await calibrate(
        shot: (d, r, asked) => d >= 4 && d < 12
            ? asked.copyWith(dipOffset: r.isEven ? 1.5 : -1.5)
            : null,
      );

      expect(service.rmsError, greaterThanOrEqualTo(limit));
      expect(service.diagnosis.problem, CalibrationProblem.magnetic);
    });

    test('always reports a cause once the error is over the limit', () async {
      for (final degrees in [2.0, 3.0, 4.0, 6.0, 10.0]) {
        final service = await calibrate(
          shot: (d, r, asked) => missTargets(d, r, asked, degrees: degrees),
        );
        final rmsError = service.rmsError!;
        expect(service.diagnosis.problem == null, rmsError < limit,
            reason: 'miss $degrees°, error $rmsError');
        expect(service.diagnosis.isOk, rmsError < limit,
            reason: 'miss $degrees°, error $rmsError');
      }
    });

    test('retaking the named directions on target clears the report',
        () async {
      final service = await calibrate(shot: missTargets);
      expect(service.diagnosis.isOk, isFalse);

      for (final direction in [0, 1, 2, 3]) {
        service.retakeDirection(direction);
        expect(service.diagnosis.isOk, isTrue,
            reason: 'nothing is reported while slots are open');
        await shootOpenSlots(service);
      }

      expect(service.measurementCount, 56);
      expect(service.diagnosis.isOk, isTrue);
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
