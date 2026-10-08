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

  test('Survey.totalLength sums survey shots but not cross sections', () {
    const survey = Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
        MeasuredDistance(Point(1, 1), null, 2, 90, 0),
        MeasuredDistance(Point(1, 1), null, 3, 270, 0),
        MeasuredDistance(Point(1, 1), Point(1, 2), 7, 0, 0),
      ],
      referencePoints: [],
    );

    expect(survey.totalLength, 12);
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

  group('comments', () {
    test('survive a JSON round trip', () {
      const stretch = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0,
          comment: 'Big hall');
      const point = ReferencePoint(Point(1, 0), 1, 2, 3, comment: 'GPS');

      expect(MeasuredDistance.fromJson(stretch.toJson()).comment, 'Big hall');
      expect(ReferencePoint.fromJson(point.toJson()).comment, 'GPS');
    });

    test('are left out of the JSON when not set', () {
      const stretch = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0);
      const point = ReferencePoint(Point(1, 0), 1, 2, 3);

      expect(stretch.toJson().containsKey('comment'), isFalse);
      expect(point.toJson().containsKey('comment'), isFalse);
    });

    test('are trimmed and removed when empty', () {
      const stretch = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0,
          comment: 'Big hall');
      const point = ReferencePoint(Point(1, 0), 1, 2, 3, comment: 'GPS');

      expect(stretch.withComment('  Sump  ').comment, 'Sump');
      expect(stretch.withComment('  ').comment, isNull);
      expect(point.withComment('').comment, isNull);
    });

    test('are kept by copyWith', () {
      const stretch = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0,
          comment: 'Big hall');
      const point = ReferencePoint(Point(1, 0), 1, 2, 3, comment: 'GPS');

      expect(stretch.copyWith(distance: 6).comment, 'Big hall');
      expect(point.copyWith(east: 4).comment, 'GPS');
    });
  });
}
