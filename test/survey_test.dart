import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/survey.dart';

void main() {
  group('Point.compareTo', () {
    test('orders by series, then by point', () {
      expect(const Point(1, 2).compareTo(const Point(1, 1)), greaterThan(0));
      expect(const Point(2, 0).compareTo(const Point(1, 9)), greaterThan(0));
      expect(const Point(1, 1).compareTo(const Point(1, 1)), 0);
    });
  });

  group('MeasuredDistance.station', () {
    Point station(Point from, Point? to) =>
        MeasuredDistance(from, to, 5, 0, 0).station;

    test('is the From station of a cross section', () {
      expect(station(const Point(1, 2), null), const Point(1, 2));
    });

    test('is the To station of a forward shot', () {
      expect(station(const Point(1, 1), const Point(1, 2)), const Point(1, 2));
    });

    test('is the From station of a backward shot', () {
      expect(station(const Point(1, 2), const Point(1, 1)), const Point(1, 2));
    });

    test('is the new series of a Start Here dummy shot', () {
      expect(station(const Point(1, 5), const Point(3, 0)), const Point(3, 0));
    });
  });

  group('Survey.lastStation', () {
    Point? lastStation(List<MeasuredDistance> stretches,
            [List<ReferencePoint> referencePoints = const []]) =>
        Survey(stretches: stretches, referencePoints: referencePoints)
            .lastStation;

    test('is null for an empty survey', () {
      expect(lastStation([]), isNull);
    });

    test('is the last reference point without stretches', () {
      expect(lastStation([], [const ReferencePoint(Point(1, 0), 0, 0, 0)]),
          const Point(1, 0));
    });

    test('is the station of the last stretch', () {
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          const MeasuredDistance(Point(1, 2), Point(1, 1), 5, 180, 0),
        ]),
        const Point(1, 2),
      );
    });

    test('is not affected by a branch listed before its parent series', () {
      // A section branching off at 1.1 is listed before the one reaching 1.1
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0),
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        ]),
        const Point(1, 1),
      );
    });
  });
}
