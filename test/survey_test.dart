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

  group('equivalent stations', () {
    // 2.0 starts a new series at 1.1 and 3.0 one at 2.0, both with zero
    // length shots. 1.2 is measured back to where 1.0 is, but is not
    // equivalent to it.
    const survey = Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        MeasuredDistance(Point(1, 1), Point(1, 2), 5, 270, 0),
        MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0),
        MeasuredDistance(Point(2, 0), Point(2, 1), 3, 0, 0),
        MeasuredDistance(Point(2, 0), Point(3, 0), 0, 0, 0),
      ],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    );

    test('map to the first station linked by zero length shots', () {
      expect(survey.equivalentStations, {
        const Point(1, 0): const Point(1, 0),
        const Point(1, 1): const Point(1, 1),
        const Point(1, 2): const Point(1, 2),
        const Point(2, 0): const Point(1, 1),
        const Point(2, 1): const Point(2, 1),
        const Point(3, 0): const Point(1, 1),
      });
    });

    test('are left out of the distinct stations after the first', () {
      expect(survey.distinctStations, {
        const Point(1, 0),
        const Point(1, 1),
        const Point(1, 2),
        const Point(2, 1),
      });
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

  group('flipping', () {
    const series = Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        MeasuredDistance(Point(1, 1), null, 2, 0, 0),
        MeasuredDistance(Point(1, 1), Point(1, 2), 5, 90, 0),
        // Backward shot leading to 1.3
        MeasuredDistance(Point(1, 3), Point(1, 2), 5, 270, 0),
        MeasuredDistance(Point(1, 2), Point(2, 0), 5, 0, 0),
      ],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    );

    List<bool> flips(Survey survey) =>
        [for (final s in survey.stretches) s.flipped];

    test('flip turns around the shot leading to the station', () {
      expect(flips(series.flip(const Point(1, 3))),
          [false, false, false, true, false]);
      expect(flips(series.flip(const Point(1, 3)).flip(const Point(1, 3))),
          everyElement(isFalse));
    });

    test('only a station a shot leads to can be flipped', () {
      expect(series.canFlip(const Point(1, 1)), isTrue);
      expect(series.canFlip(const Point(1, 0)), isFalse);
    });

    test('flip all turns around the following shots of the series', () {
      // 2.0 is in another series and keeps its direction
      expect(flips(series.flipAll(const Point(1, 2))),
          [false, false, true, true, false]);
    });

    test('flip all aligns the following shots with the first one', () {
      final mixed = series.flip(const Point(1, 3));
      expect(flips(mixed.flipAll(const Point(1, 2))),
          [false, false, true, true, false]);
      expect(flips(mixed.flipAll(const Point(1, 2)).flipAll(const Point(1, 2))),
          everyElement(isFalse));
    });

    test('the flag survives JSON and edits and is left out when not set', () {
      const stretch =
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0, flipped: true);

      expect(MeasuredDistance.fromJson(stretch.toJson()).flipped, isTrue);
      expect(stretch.copyWith(distance: 6).flipped, isTrue);
      expect(stretch.withComment('Hall').flipped, isTrue);
      expect(stretch.copyWith(flipped: false).toJson().containsKey('flipped'),
          isFalse);
    });
  });
}
