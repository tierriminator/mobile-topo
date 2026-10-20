import 'dart:math' as math;

import 'location_service.dart';

/// Averages position fixes for a more exact position than a single one:
/// each fix is weighted by the inverse square of its estimated accuracy,
/// so better fixes count more
class PositionAverage {
  final List<LocationFix> _fixes = [];

  /// Accuracies are not taken as better than this, so a single overly
  /// confident fix cannot outweigh all others
  static const double _minAccuracy = 0.5;

  /// WGS84 semi-major axis and squared eccentricity
  static const double _a = 6378137;
  static const double _e2 = 0.00669437999014;

  void add(LocationFix fix) => _fixes.add(fix);

  int get count => _fixes.length;

  bool get isEmpty => _fixes.isEmpty;

  /// The latest fix, if any
  LocationFix? get latest => _fixes.lastOrNull;

  static double _weight(double accuracy) =>
      1 / math.pow(math.max(accuracy, _minAccuracy), 2);

  /// The weighted mean of [value] over the fixes [weight] gives a weight
  static double? _mean(Iterable<LocationFix> fixes,
      double Function(LocationFix) value, double Function(LocationFix) weight) {
    var sum = 0.0;
    var total = 0.0;
    for (final fix in fixes) {
      final w = weight(fix);
      sum += value(fix) * w;
      total += w;
    }
    return total == 0 ? null : sum / total;
  }

  double get latitude =>
      _mean(_fixes, (f) => f.latitude, (f) => _weight(f.accuracy))!;

  double get longitude =>
      _mean(_fixes, (f) => f.longitude, (f) => _weight(f.accuracy))!;

  /// The mean altitude of the fixes reporting one, weighted by their
  /// vertical accuracy where reported; null if none reports an altitude
  double? get altitude => _mean(
        _fixes.where((f) => f.altitude != null),
        (f) => f.altitude!,
        (f) => _weight(f.altitudeAccuracy ?? f.accuracy),
      );

  /// Root mean square horizontal distance of the fixes from the mean in
  /// metres: how much they scatter, which shows when the position has
  /// settled
  double get scatter {
    if (_fixes.isEmpty) return 0;
    final phi = latitude * math.pi / 180;
    final s = 1 - _e2 * math.sin(phi) * math.sin(phi);
    // Metres per radian along the meridian and the parallel
    final northRadius = _a * (1 - _e2) / math.pow(s, 1.5);
    final eastRadius = _a / math.sqrt(s) * math.cos(phi);
    var sum = 0.0;
    for (final fix in _fixes) {
      final north = (fix.latitude - latitude) * math.pi / 180 * northRadius;
      final east = (fix.longitude - longitude) * math.pi / 180 * eastRadius;
      sum += north * north + east * east;
    }
    return math.sqrt(sum / _fixes.length);
  }
}
