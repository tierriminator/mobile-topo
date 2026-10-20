import 'dart:math' as math;

import 'geo_position.dart';
import 'igrf_coefficients.dart';

/// Magnetic declination from the International Geomagnetic Reference Field
/// (IGRF-14): the angle from geographic north to magnetic north in degrees,
/// positive when magnetic north lies east, as trips use it.
///
/// The model covers 1900 to 2030. Earlier dates get the field of 1900,
/// later ones extrapolate the change of 2025-2030.
class MagneticDeclination {
  /// Reference radius of the model in km
  static const double _radius = 6371.2;

  /// WGS84 semi-major and semi-minor axis in km
  static const double _a = 6378.137;
  static const double _b = 6356.752314245;

  static const int _maxDegree = 13;
  static const int _firstEpoch = 1900;
  static const int _lastEpoch = 2025;
  static const int _epochStep = 5;

  /// The declination at [position] on [date], [altitude] metres above the
  /// ellipsoid
  static double at(GeoPosition position, DateTime date, {num altitude = 0}) {
    final (g, h) = _coefficients(_decimalYear(date));

    // Geodetic to geocentric coordinates
    final latitude = position.latitude * math.pi / 180;
    final longitude = position.longitude * math.pi / 180;
    final height = altitude / 1000;
    final sinLat = math.sin(latitude);
    final cosLat = math.cos(latitude);
    const a2 = _a * _a;
    const b2 = _b * _b;
    final rho = math.sqrt(a2 * cosLat * cosLat + b2 * sinLat * sinLat);
    final r = math.sqrt(height * height +
        2 * height * rho +
        (a2 * a2 * cosLat * cosLat + b2 * b2 * sinLat * sinLat) / (rho * rho));
    final cd = (height + rho) / r;
    final sd = (a2 - b2) / rho * cosLat * sinLat / r;
    // Cosine and sine of the geocentric colatitude
    final cosTheta = sinLat * cd - cosLat * sd;
    final sinTheta = cosLat * cd + sinLat * sd;

    final (p, dp) = _legendre(cosTheta, sinTheta);

    var bTheta = 0.0;
    var bPhi = 0.0;
    var bR = 0.0;
    var ratio = _radius / r;
    ratio *= ratio;
    for (var n = 1; n <= _maxDegree; n++) {
      ratio *= _radius / r;
      for (var m = 0; m <= n; m++) {
        final cosM = math.cos(m * longitude);
        final sinM = math.sin(m * longitude);
        final gnm = g[n][m];
        final hnm = h[n][m];
        bR += ratio * (n + 1) * (gnm * cosM + hnm * sinM) * p[n][m];
        bTheta -= ratio * (gnm * cosM + hnm * sinM) * dp[n][m];
        // At the poles, sin θ vanishes along with the terms it divides
        if (sinTheta.abs() > 1e-10) {
          bPhi += ratio * m * (gnm * sinM - hnm * cosM) * p[n][m] / sinTheta;
        }
      }
    }

    // North and east components, rotated back to the geodetic frame
    final north = -bTheta * cd + -bR * sd;
    final east = bPhi;
    return math.atan2(east, north) * 180 / math.pi;
  }

  /// The date as a year with fraction
  static double _decimalYear(DateTime date) {
    final start = DateTime.utc(date.year);
    final end = DateTime.utc(date.year + 1);
    final day = DateTime.utc(date.year, date.month, date.day);
    return date.year +
        day.difference(start).inHours / end.difference(start).inHours;
  }

  /// Coefficients g and h by degree and order for [year]: interpolated
  /// between the epochs, or extrapolated from the last one with the secular
  /// variation
  static (List<List<double>>, List<List<double>>) _coefficients(double year) {
    final table = _table;
    final g = [for (var n = 0; n <= _maxDegree; n++) List.filled(n + 1, 0.0)];
    final h = [for (var n = 0; n <= _maxDegree; n++) List.filled(n + 1, 0.0)];
    const epochs = (_lastEpoch - _firstEpoch) ~/ _epochStep + 1;
    final position = ((year.clamp(_firstEpoch, double.infinity) - _firstEpoch) /
        _epochStep);
    for (final row in table) {
      final double value;
      if (position >= epochs - 1) {
        value =
            row.values[epochs - 1] + row.values[epochs] * (year - _lastEpoch);
      } else {
        final i = position.floor();
        final t = position - i;
        value = row.values[i] * (1 - t) + row.values[i + 1] * t;
      }
      (row.isG ? g : h)[row.n][row.m] = value;
    }
    return (g, h);
  }

  /// Schmidt semi-normalised associated Legendre functions P(n, m) of the
  /// colatitude θ and their derivatives by θ, computed with the Gauss
  /// normalised recursion and scaled to Schmidt normalisation
  static (List<List<double>>, List<List<double>>) _legendre(
      double cosTheta, double sinTheta) {
    final p = [for (var n = 0; n <= _maxDegree; n++) List.filled(n + 1, 0.0)];
    final dp = [for (var n = 0; n <= _maxDegree; n++) List.filled(n + 1, 0.0)];
    p[0][0] = 1;
    for (var n = 1; n <= _maxDegree; n++) {
      for (var m = 0; m <= n; m++) {
        if (m == n) {
          p[n][m] = sinTheta * p[n - 1][m - 1];
          dp[n][m] = sinTheta * dp[n - 1][m - 1] + cosTheta * p[n - 1][m - 1];
        } else {
          final k = n == 1
              ? 0.0
              : ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          final p2 = n >= 2 && m <= n - 2 ? p[n - 2][m] : 0.0;
          final dp2 = n >= 2 && m <= n - 2 ? dp[n - 2][m] : 0.0;
          p[n][m] = cosTheta * p[n - 1][m] - k * p2;
          dp[n][m] = cosTheta * dp[n - 1][m] - sinTheta * p[n - 1][m] - k * dp2;
        }
      }
    }

    // Factors from Gauss to Schmidt normalisation
    var s = 1.0;
    for (var n = 1; n <= _maxDegree; n++) {
      s *= (2 * n - 1) / n;
      var snm = s;
      for (var m = 0; m <= n; m++) {
        if (m > 0) snm *= math.sqrt((n - m + 1) * (m == 1 ? 2 : 1) / (n + m));
        p[n][m] *= snm;
        dp[n][m] *= snm;
      }
    }
    return (p, dp);
  }

  /// The rows of [igrf14Coefficients], read once
  static final List<_Row> _table = [
    for (final line in igrf14Coefficients.split('\n'))
      if (line.trim().isNotEmpty) _Row.parse(line),
  ];
}

/// One coefficient of the model: its values per epoch, then its secular
/// variation
class _Row {
  final bool isG;
  final int n;
  final int m;
  final List<double> values;

  const _Row(this.isG, this.n, this.m, this.values);

  factory _Row.parse(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    return _Row(
      fields[0] == 'g',
      int.parse(fields[1]),
      int.parse(fields[2]),
      [for (final f in fields.skip(3)) double.parse(f)],
    );
  }
}
