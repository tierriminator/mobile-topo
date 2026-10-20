import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/location_service.dart';
import 'package:mobile_topo/services/position_average.dart';

void main() {
  LocationFix fix(double latitude, double longitude,
          {double accuracy = 5, double? altitude, double? altitudeAccuracy}) =>
      LocationFix(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: altitude,
        altitudeAccuracy: altitudeAccuracy,
      );

  test('is empty at first', () {
    final average = PositionAverage();
    expect(average.isEmpty, isTrue);
    expect(average.latest, isNull);
    expect(average.scatter, 0);
  });

  test('averages equally accurate fixes evenly', () {
    final average = PositionAverage()
      ..add(fix(47, 8))
      ..add(fix(47.002, 8.004));
    expect(average.count, 2);
    expect(average.latitude, closeTo(47.001, 1e-12));
    expect(average.longitude, closeTo(8.002, 1e-12));
  });

  test('weights fixes by the inverse square of their accuracy', () {
    // Twice as accurate counts four times as much
    final average = PositionAverage()
      ..add(fix(47, 8, accuracy: 2))
      ..add(fix(47.005, 8, accuracy: 4));
    expect(average.latitude, closeTo(47.001, 1e-12));
  });

  test('does not let an overly confident fix outweigh the others', () {
    // Accuracies below half a metre count as half a metre
    final average = PositionAverage()
      ..add(fix(47, 8, accuracy: 0.01))
      ..add(fix(47.001, 8, accuracy: 0.5));
    expect(average.latitude, closeTo(47.0005, 1e-12));
  });

  test('averages the altitude of the fixes reporting one', () {
    final average = PositionAverage()
      ..add(fix(47, 8))
      ..add(fix(47, 8, altitude: 700, altitudeAccuracy: 3))
      ..add(fix(47, 8, altitude: 712, altitudeAccuracy: 6));
    // Weighted 4:1 by the vertical accuracy
    expect(average.altitude, closeTo(702.4, 1e-9));
    expect(PositionAverage().altitude, isNull);
    expect((PositionAverage()..add(fix(47, 8))).altitude, isNull);
  });

  test('measures the scatter in metres', () {
    // 0.0001° of latitude is about 11.1 m; each lies 5.6 m from the mean
    final average = PositionAverage()
      ..add(fix(47, 8))
      ..add(fix(47.0001, 8));
    expect(average.scatter, closeTo(5.56, 0.02));
    expect(average.latest?.latitude, 47.0001);
  });
}
