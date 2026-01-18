import 'dart:math' as math;
import 'dart:typed_data';

import '../utils/linear_algebra.dart';

/// Raw sensor reading from one calibration measurement.
class CalibrationMeasurement {
  /// Accelerometer X (16-bit signed raw value).
  final int gx;

  /// Accelerometer Y (16-bit signed raw value).
  final int gy;

  /// Accelerometer Z (16-bit signed raw value).
  final int gz;

  /// Magnetometer X (16-bit signed raw value).
  final int mx;

  /// Magnetometer Y (16-bit signed raw value).
  final int my;

  /// Magnetometer Z (16-bit signed raw value).
  final int mz;

  /// Measurement number (1-56, as reported by device).
  final int index;

  /// Whether to include in calibration calculation.
  final bool enabled;

  /// Group identifier ('A', 'B', or null for ungrouped).
  /// Measurements in the same group should point in the same direction.
  final String? group;

  const CalibrationMeasurement({
    required this.gx,
    required this.gy,
    required this.gz,
    required this.mx,
    required this.my,
    required this.mz,
    required this.index,
    this.enabled = true,
    this.group,
  });

  /// Create a copy with modified fields.
  CalibrationMeasurement copyWith({
    int? gx,
    int? gy,
    int? gz,
    int? mx,
    int? my,
    int? mz,
    int? index,
    bool? enabled,
    String? group,
    bool clearGroup = false,
  }) {
    return CalibrationMeasurement(
      gx: gx ?? this.gx,
      gy: gy ?? this.gy,
      gz: gz ?? this.gz,
      mx: mx ?? this.mx,
      my: my ?? this.my,
      mz: mz ?? this.mz,
      index: index ?? this.index,
      enabled: enabled ?? this.enabled,
      group: clearGroup ? null : (group ?? this.group),
    );
  }

  /// Raw accelerometer reading as Vector3.
  Vector3 get gVector => Vector3(gx.toDouble(), gy.toDouble(), gz.toDouble());

  /// Raw magnetometer reading as Vector3.
  Vector3 get mVector => Vector3(mx.toDouble(), my.toDouble(), mz.toDouble());

  /// Convert to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'gx': gx,
        'gy': gy,
        'gz': gz,
        'mx': mx,
        'my': my,
        'mz': mz,
        'index': index,
        'enabled': enabled,
        if (group != null) 'group': group,
      };

  /// Create from JSON.
  factory CalibrationMeasurement.fromJson(Map<String, dynamic> json) {
    return CalibrationMeasurement(
      gx: json['gx'] as int,
      gy: json['gy'] as int,
      gz: json['gz'] as int,
      mx: json['mx'] as int,
      my: json['my'] as int,
      mz: json['mz'] as int,
      index: json['index'] as int,
      enabled: json['enabled'] as bool? ?? true,
      group: json['group'] as String?,
    );
  }

  @override
  String toString() =>
      'CalibrationMeasurement(#$index, G=($gx,$gy,$gz), M=($mx,$my,$mz), '
      'enabled=$enabled, group=$group)';
}

/// Computed results for one measurement after applying calibration.
class CalibrationResult {
  /// Error estimate in degrees (should be < 0.5 for good calibration).
  final double error;

  /// Magnitude of calibrated G vector (should be ~1).
  final double gMagnitude;

  /// Magnitude of calibrated M vector (should be ~1).
  final double mMagnitude;

  /// Angle between G and M in degrees (dip angle, should be consistent).
  final double alpha;

  /// Computed azimuth in degrees.
  final double azimuth;

  /// Computed inclination in degrees.
  final double inclination;

  /// Computed roll in degrees.
  final double roll;

  const CalibrationResult({
    required this.error,
    required this.gMagnitude,
    required this.mMagnitude,
    required this.alpha,
    required this.azimuth,
    required this.inclination,
    required this.roll,
  });

  @override
  String toString() =>
      'CalibrationResult(err=${error.toStringAsFixed(2)}deg, '
      '|G|=${gMagnitude.toStringAsFixed(3)}, |M|=${mMagnitude.toStringAsFixed(3)}, '
      'alpha=${alpha.toStringAsFixed(1)}deg)';
}

/// Calibration coefficients (transformation matrices).
///
/// The calibration transform is: calibrated = A * raw + B
/// where A is a 3x3 matrix and B is a bias vector.
class CalibrationCoefficients {
  /// Accelerometer rotation/scale matrix.
  final Matrix3 aG;

  /// Accelerometer bias vector.
  final Vector3 bG;

  /// Magnetometer rotation/scale matrix.
  final Matrix3 aM;

  /// Magnetometer bias vector.
  final Vector3 bM;

  /// Optional non-linear correction (DistoX2 only).
  final Vector3? nL;

  const CalibrationCoefficients({
    required this.aG,
    required this.bG,
    required this.aM,
    required this.bM,
    this.nL,
  });

  /// Create default (identity) coefficients.
  factory CalibrationCoefficients.identity() => CalibrationCoefficients(
        aG: Matrix3.identity(),
        bG: Vector3.zero,
        aM: Matrix3.identity(),
        bM: Vector3.zero,
      );

  /// Scaling factors for coefficient serialization.
  static const double _fv = 24000.0; // For bias vectors (B)
  static const double _fm = 16384.0; // For matrix elements (A)

  /// Serialize to 48 bytes for device memory.
  ///
  /// Layout (from TopoDroid/PocketTopo):
  /// - Bytes 0-23: G transform
  ///   - [0-1]: bG.x * FV
  ///   - [2-3]: aG[0,0] * FM
  ///   - [4-5]: aG[0,1] * FM
  ///   - [6-7]: aG[0,2] * FM
  ///   - [8-9]: aG[1,0] * FM
  ///   - [10-11]: aG[1,1] * FM
  ///   - [12-13]: aG[1,2] * FM
  ///   - [14-15]: aG[2,0] * FM
  ///   - [16-17]: aG[2,1] * FM
  ///   - [18-19]: aG[2,2] * FM
  ///   - [20-21]: bG.y * FV
  ///   - [22-23]: bG.z * FV
  /// - Bytes 24-47: M transform (same layout)
  Uint8List toBytes() {
    final bytes = Uint8List(48);
    final data = ByteData.view(bytes.buffer);

    // G coefficients
    data.setInt16(0, _toInt16(bG.x * _fv), Endian.little);
    data.setInt16(2, _toInt16(aG.get(0, 0) * _fm), Endian.little);
    data.setInt16(4, _toInt16(aG.get(0, 1) * _fm), Endian.little);
    data.setInt16(6, _toInt16(aG.get(0, 2) * _fm), Endian.little);
    data.setInt16(8, _toInt16(aG.get(1, 0) * _fm), Endian.little);
    data.setInt16(10, _toInt16(aG.get(1, 1) * _fm), Endian.little);
    data.setInt16(12, _toInt16(aG.get(1, 2) * _fm), Endian.little);
    data.setInt16(14, _toInt16(aG.get(2, 0) * _fm), Endian.little);
    data.setInt16(16, _toInt16(aG.get(2, 1) * _fm), Endian.little);
    data.setInt16(18, _toInt16(aG.get(2, 2) * _fm), Endian.little);
    data.setInt16(20, _toInt16(bG.y * _fv), Endian.little);
    data.setInt16(22, _toInt16(bG.z * _fv), Endian.little);

    // M coefficients
    data.setInt16(24, _toInt16(bM.x * _fv), Endian.little);
    data.setInt16(26, _toInt16(aM.get(0, 0) * _fm), Endian.little);
    data.setInt16(28, _toInt16(aM.get(0, 1) * _fm), Endian.little);
    data.setInt16(30, _toInt16(aM.get(0, 2) * _fm), Endian.little);
    data.setInt16(32, _toInt16(aM.get(1, 0) * _fm), Endian.little);
    data.setInt16(34, _toInt16(aM.get(1, 1) * _fm), Endian.little);
    data.setInt16(36, _toInt16(aM.get(1, 2) * _fm), Endian.little);
    data.setInt16(38, _toInt16(aM.get(2, 0) * _fm), Endian.little);
    data.setInt16(40, _toInt16(aM.get(2, 1) * _fm), Endian.little);
    data.setInt16(42, _toInt16(aM.get(2, 2) * _fm), Endian.little);
    data.setInt16(44, _toInt16(bM.y * _fv), Endian.little);
    data.setInt16(46, _toInt16(bM.z * _fv), Endian.little);

    return bytes;
  }

  /// Deserialize from device memory (48 bytes).
  factory CalibrationCoefficients.fromBytes(Uint8List bytes) {
    if (bytes.length < 48) {
      throw ArgumentError('Need at least 48 bytes for coefficients');
    }

    final data = ByteData.view(bytes.buffer);

    // G coefficients
    final bGx = data.getInt16(0, Endian.little) / _fv;
    final aG00 = data.getInt16(2, Endian.little) / _fm;
    final aG01 = data.getInt16(4, Endian.little) / _fm;
    final aG02 = data.getInt16(6, Endian.little) / _fm;
    final aG10 = data.getInt16(8, Endian.little) / _fm;
    final aG11 = data.getInt16(10, Endian.little) / _fm;
    final aG12 = data.getInt16(12, Endian.little) / _fm;
    final aG20 = data.getInt16(14, Endian.little) / _fm;
    final aG21 = data.getInt16(16, Endian.little) / _fm;
    final aG22 = data.getInt16(18, Endian.little) / _fm;
    final bGy = data.getInt16(20, Endian.little) / _fv;
    final bGz = data.getInt16(22, Endian.little) / _fv;

    // M coefficients
    final bMx = data.getInt16(24, Endian.little) / _fv;
    final aM00 = data.getInt16(26, Endian.little) / _fm;
    final aM01 = data.getInt16(28, Endian.little) / _fm;
    final aM02 = data.getInt16(30, Endian.little) / _fm;
    final aM10 = data.getInt16(32, Endian.little) / _fm;
    final aM11 = data.getInt16(34, Endian.little) / _fm;
    final aM12 = data.getInt16(36, Endian.little) / _fm;
    final aM20 = data.getInt16(38, Endian.little) / _fm;
    final aM21 = data.getInt16(40, Endian.little) / _fm;
    final aM22 = data.getInt16(42, Endian.little) / _fm;
    final bMy = data.getInt16(44, Endian.little) / _fv;
    final bMz = data.getInt16(46, Endian.little) / _fv;

    return CalibrationCoefficients(
      aG: Matrix3([aG00, aG01, aG02, aG10, aG11, aG12, aG20, aG21, aG22]),
      bG: Vector3(bGx, bGy, bGz),
      aM: Matrix3([aM00, aM01, aM02, aM10, aM11, aM12, aM20, aM21, aM22]),
      bM: Vector3(bMx, bMy, bMz),
    );
  }

  /// Apply calibration to raw measurement.
  /// Returns calibrated (G, M) vectors.
  (Vector3 g, Vector3 m) apply(CalibrationMeasurement raw) {
    final g = aG.transform(raw.gVector) + bG;
    final m = aM.transform(raw.mVector) + bM;
    return (g, m);
  }

  /// Compute azimuth, inclination, and roll from calibrated vectors.
  (double azimuth, double inclination, double roll) computeAngles(
    Vector3 g,
    Vector3 m,
  ) {
    final gNorm = g.normalized;
    final mNorm = m.normalized;

    // Inclination from G (angle from horizontal)
    // G points down (gravity), so z component gives inclination
    final inclination = math.asin(-gNorm.z) * 180 / math.pi;

    // For azimuth, project M onto horizontal plane
    // Horizontal plane is perpendicular to G
    // East direction in device frame: cross(G, vertical) normalized
    // North direction: cross(East, G)
    const vertical = Vector3(0, 0, -1);
    var east = gNorm.cross(vertical);
    if (east.magnitude < 0.01) {
      // G is nearly vertical, use device Y as fallback
      east = const Vector3(0, 1, 0);
    }
    east = east.normalized;
    final north = east.cross(gNorm).normalized;

    // Project M onto horizontal plane and compute azimuth
    final mHoriz = mNorm - gNorm * mNorm.dot(gNorm);
    final mEast = mHoriz.dot(east);
    final mNorth = mHoriz.dot(north);
    var azimuth = math.atan2(mEast, mNorth) * 180 / math.pi;
    if (azimuth < 0) azimuth += 360;

    // Roll from G
    final roll = math.atan2(gNorm.y, -gNorm.x) * 180 / math.pi;

    return (azimuth, inclination, roll);
  }

  /// Convert to 16-bit signed integer, clamped to valid range.
  static int _toInt16(double value) {
    final rounded = value.round();
    return rounded.clamp(-32768, 32767);
  }
}

/// Full calibration session data.
class CalibrationData {
  /// All collected measurements.
  final List<CalibrationMeasurement> measurements;

  /// Per-measurement results after evaluation.
  final List<CalibrationResult>? results;

  /// Computed calibration coefficients.
  final CalibrationCoefficients? coefficients;

  /// RMS error of the calibration (degrees).
  final double? rmsError;

  /// Number of iterations used in computation.
  final int? iterations;

  const CalibrationData({
    required this.measurements,
    this.results,
    this.coefficients,
    this.rmsError,
    this.iterations,
  });

  /// Create empty calibration data.
  static const empty = CalibrationData(measurements: []);

  /// Get default group assignment for measurement index.
  ///
  /// First 16 measurements are grouped in fours: AAAA BBBB AAAA BBBB
  /// Remaining measurements are ungrouped.
  static String? defaultGroup(int index) {
    if (index > 16) return null;
    // 1-4: A, 5-8: B, 9-12: A, 13-16: B
    return ((index - 1) ~/ 4) % 2 == 0 ? 'A' : 'B';
  }
}
