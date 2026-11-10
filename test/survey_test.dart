import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/series_range.dart';
import 'package:mobile_topo/models/survey.dart';

void main() {
  group('Survey.nextSeriesStart', () {
    // Series 1, 3 and 11 are in use
    const survey = Survey(stretches: [
      MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
      MeasuredDistance(Point(1, 1), Point(3, 0), 5, 0, 0),
      MeasuredDistance(Point(3, 0), Point(11, 0), 5, 0, 0),
    ], referencePoints: []);

    test('without reserved series follows the highest in use', () {
      expect(survey.nextSeriesStart(), const Point(12, 0));
    });

    test('takes the first free series of the reserved ranges', () {
      expect(survey.nextSeriesStart(reserved: const [SeriesRange(3, 5)]),
          const Point(4, 0));
      expect(
          survey.nextSeriesStart(
              reserved: const [SeriesRange(3, 3), SeriesRange(1, 2)]),
          const Point(2, 0));
    });

    test('an open range follows the highest in use, but not below it', () {
      expect(survey.nextSeriesStart(reserved: const [SeriesRange(2)]),
          const Point(12, 0));
      expect(survey.nextSeriesStart(reserved: const [SeriesRange(20)]),
          const Point(20, 0));
    });

    test('an open range comes after the closed ranges before it', () {
      expect(
          survey.nextSeriesStart(
              reserved: const [SeriesRange(3, 4), SeriesRange(20)]),
          const Point(4, 0));
      expect(
          survey.nextSeriesStart(
              reserved: const [SeriesRange(3, 3), SeriesRange(20)]),
          const Point(20, 0));
    });

    test('an open range skips the series others reserve', () {
      expect(
          survey.nextSeriesStart(
              reserved: const [SeriesRange(12)],
              blocked: const [SeriesRange(12, 14)]),
          const Point(15, 0));
    });

    test('finds none once the reserved ranges are used up', () {
      expect(
          survey.nextSeriesStart(
              reserved: const [SeriesRange(1, 1), SeriesRange(3, 3)]),
          isNull);
    });

    test('without reserved series skips the series others reserve', () {
      expect(survey.nextSeriesStart(blocked: const [SeriesRange(12, 14)]),
          const Point(15, 0));
    });
  });

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

    test('is the new series of a dummy shot to a lower series', () {
      const dummy = MeasuredDistance(Point(20, 5), Point(10, 0), 0, 0, 0);
      expect(dummy.station, const Point(10, 0));
      expect(dummy.isBackward, isFalse);
      // A measured shot between series still counts as backward
      expect(station(const Point(20, 5), const Point(10, 0)),
          const Point(20, 5));
    });
  });

  test('without reference points the first station is at the origin', () {
    const survey = Survey(
      stretches: [
        MeasuredDistance(Point(7, 9), Point(7, 10), 0, 0, 0),
        MeasuredDistance(Point(7, 10), Point(7, 11), 5, 90, 0),
      ],
      referencePoints: [],
    );

    final positions = survey.computeStationPositions();

    expect(positions.keys,
        unorderedEquals(const [Point(7, 9), Point(7, 10), Point(7, 11)]));
    expect(positions[const Point(7, 9)]!.east, 0);
    expect(positions[const Point(7, 11)]!.east, closeTo(5, 1e-9));
  });

  test('a long series listed last shot first gets all positions', () {
    // Each shot can only be placed after the one listed after it
    const count = 20000;
    final survey = Survey(
      stretches: [
        for (var i = count; i > 0; i--)
          MeasuredDistance(Point(1, i - 1), Point(1, i), 1, 90, 0),
      ],
      referencePoints: const [ReferencePoint(Point(1, 0), 0, 0, 0)],
    );

    final positions = survey.computeStationPositions();

    expect(positions, hasLength(count + 1));
    expect(positions[const Point(1, count)]!.east, closeTo(count, 1e-6));
  });

  test('in a loop, a station is placed by the shot first in data order', () {
    // 1.2 is reached from 1.1 before the shot from 1.0 comes up, which
    // misses it by a metre
    const survey = Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        MeasuredDistance(Point(1, 1), Point(1, 2), 5, 0, 0),
        MeasuredDistance(Point(1, 0), Point(1, 2), 6, 45, 0),
        MeasuredDistance(Point(1, 2), Point(1, 3), 5, 270, 0),
      ],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    );

    final positions = survey.computeStationPositions();

    expect(positions[const Point(1, 2)]!.east, closeTo(5, 1e-9));
    expect(positions[const Point(1, 2)]!.north, closeTo(5, 1e-9));
    expect(positions[const Point(1, 3)]!.east, closeTo(0, 1e-9));
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

  group('Survey.lastUnreferencedStation', () {
    Point? station(List<MeasuredDistance> stretches,
            [List<Point> referenced = const []]) =>
        Survey(stretches: stretches, referencePoints: [
          for (final p in referenced) ReferencePoint(p, 0, 0, 0),
        ]).lastUnreferencedStation;

    const series = [
      MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
      MeasuredDistance(Point(1, 1), null, 2, 90, 0),
      MeasuredDistance(Point(1, 1), Point(1, 2), 5, 0, 0),
    ];

    test('is null without measurements', () {
      expect(station([]), isNull);
    });

    test('is the station of the last stretch', () {
      expect(station(series), const Point(1, 2));
      // A backward shot's station is the one it is measured from
      expect(
          station(const [MeasuredDistance(Point(1, 2), Point(1, 1), 5, 0, 0)]),
          const Point(1, 2));
    });

    test('goes back past stations with a reference point', () {
      expect(station(series, [const Point(1, 2)]), const Point(1, 1));
      expect(station(series, [const Point(1, 2), const Point(1, 1)]),
          const Point(1, 0));
      expect(
          station(series,
              [const Point(1, 0), const Point(1, 1), const Point(1, 2)]),
          isNull);
    });

    test('counts equivalent stations as referenced', () {
      // 2.0 starts a new series at 1.1, so it is the same station
      final stretches = [
        ...series.take(1),
        const MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0),
      ];
      expect(station(stretches, [const Point(1, 1)]), const Point(1, 0));
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

  group('reversing shots', () {
    test('switches a survey shot between forward and backward', () {
      const forward = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0);
      final backward = forward.reversed();
      expect(backward.from, const Point(1, 1));
      expect(backward.to, const Point(1, 0));
      expect(backward.isBackward, isTrue);
      expect(backward.reversed().isBackward, isFalse);
    });

    test('leaves a cross section unchanged', () {
      const crossSection = MeasuredDistance(Point(1, 2), null, 4, 90, 0);
      expect(crossSection.reversed(), same(crossSection));
    });
  });

  group('turning cross sections into survey shots', () {
    const crossSection =
        MeasuredDistance(Point(1, 2), null, 4, 90, 0, comment: 'Hall');

    test('leads to the next station', () {
      final shot = crossSection.toSurveyShot();
      expect(shot.from, const Point(1, 2));
      expect(shot.to, const Point(1, 3));
      expect(shot.distance, 4);
      expect(shot.comment, 'Hall');
    });

    test('makes a backward shot if asked', () {
      final shot = crossSection.toSurveyShot(backward: true);
      expect(shot.from, const Point(1, 3));
      expect(shot.to, const Point(1, 2));
      expect(shot.isBackward, isTrue);
    });

    test('leaves a survey shot unchanged', () {
      const shot = MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0);
      expect(shot.toSurveyShot(), same(shot));
    });
  });

  group('renumbering', () {
    List<String> ids(Survey survey) =>
        [for (final s in survey.stretches) '${s.from} ${s.to ?? '-'}'];

    test('continues the following rows from the station of the row', () {
      // A cross section at 1.1 was switched into the shot to 1.2, so the
      // following rows still use the old numbers
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 3, 0, 0),
          MeasuredDistance(Point(1, 1), null, 2, 0, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 90, 0),
          // Backward shot
          MeasuredDistance(Point(1, 3), Point(1, 2), 5, 270, 0),
        ],
        referencePoints: [],
      );

      expect(ids(survey.renumberFrom(1)), [
        '1.0 1.1',
        '1.1 1.2',
        '1.2 -',
        '1.2 1.3',
        '1.4 1.3',
      ]);
    });

    test('keeps branches and moves their start along', () {
      // The first shot was edited to lead to 1.2, the rows after it still
      // continue from 1.1
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 2), 5, 90, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 90, 0),
          // Start Here: branch 2 starts at 1.2
          MeasuredDistance(Point(1, 2), Point(2, 0), 0, 0, 0),
          MeasuredDistance(Point(2, 0), Point(2, 1), 4, 0, 0),
          // Continue Here: series 1 goes on from 1.2
          MeasuredDistance(Point(1, 2), null, 0, 0, 0),
          MeasuredDistance(Point(1, 2), Point(1, 3), 6, 90, 0),
        ],
        referencePoints: [],
      );

      expect(ids(survey.renumberFrom(0)), [
        '1.0 1.2',
        '1.2 1.3',
        '1.3 2.0',
        '2.0 2.1',
        '1.3 -',
        '1.3 1.4',
      ]);
    });
  });
}
