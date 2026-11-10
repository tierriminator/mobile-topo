import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/data/cave_file.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/coordinate_system.dart';
import 'package:mobile_topo/models/geo_position.dart';
import 'package:mobile_topo/models/magnetic_declination.dart';
import 'package:mobile_topo/models/series_problem.dart';
import 'package:mobile_topo/models/series_range.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';

void main() {
  final now = DateTime(2026);

  Section section(String id, [List<MeasuredDistance> stretches = const []]) =>
      Section(
        id: id,
        name: id,
        survey: Survey(stretches: stretches, referencePoints: const []),
        createdAt: now,
        modifiedAt: now,
      );

  Cave cave() => Cave(
        id: 'cave',
        name: 'Cave',
        sections: [section('root')],
        areas: [
          Area(
            id: 'area',
            name: 'Area',
            sections: [section('a1')],
            subAreas: [
              Area(
                id: 'sub',
                name: 'Sub',
                sections: [section('a2')],
                createdAt: now,
                modifiedAt: now,
              ),
            ],
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        createdAt: now,
        modifiedAt: now,
      );

  const stretch =
      MeasuredDistance(Point(1, 0), Point(1, 1), 5.0, 90.0, 0.0);

  group('Cave', () {
    test('allSections includes sections nested in areas', () {
      expect(cave().allSections.map((s) => s.id), ['root', 'a1', 'a2']);
    });

    test('replaceSection replaces a deeply nested section', () {
      final updated = cave().replaceSection(section('a2', [stretch]));
      final a2 = updated.allSections.firstWhere((s) => s.id == 'a2');
      expect(a2.survey.stretches, [stretch]);
      expect(updated.allSections.length, 3);
    });

    test('removeSection removes a deeply nested section', () {
      expect(cave().removeSection('a2').allSections.map((s) => s.id),
          ['root', 'a1']);
      expect(cave().removeSection('root').allSections.map((s) => s.id),
          ['a1', 'a2']);
    });
  });

  group('reserved series', () {
    // Trip a surveys series 1 and starts series 2; trip b, a day later and
    // listed first, starts series 10 and 11 and also a dummy shot into
    // series 2, which stays a's as a is earlier
    final a = Trip(id: 'a', date: DateTime(2026, 1, 1), createdAt: now);
    final b = Trip(id: 'b', date: DateTime(2026, 1, 2), createdAt: now);
    MeasuredDistance shot(Point from, Point to, String trip,
            [num distance = 5]) =>
        MeasuredDistance(from, to, distance, 0, 0, tripId: trip);
    Cave surveyed({List<SeriesRange> aReserves = const [],
            List<SeriesRange> bReserves = const []}) =>
        cave()
            .copyWith(trips: [
              b.copyWith(reservedSeries: bReserves),
              a.copyWith(reservedSeries: aReserves),
            ])
            .replaceSection(section('root', [
              shot(const Point(1, 1), const Point(10, 0), 'b', 0),
              shot(const Point(10, 0), const Point(10, 1), 'b'),
              shot(const Point(10, 1), const Point(11, 0), 'b', 0),
              shot(const Point(10, 1), const Point(2, 0), 'b', 0),
            ]))
            .replaceSection(section('a1', [
              shot(const Point(1, 0), const Point(1, 1), 'a'),
              shot(const Point(1, 1), const Point(2, 0), 'a', 0),
            ]));

    test('a series belongs to the earliest trip starting it', () {
      expect(surveyed().seriesTrips, {10: 'b', 11: 'b', 2: 'a'});
    });

    test('a zero length shot to a later station only ties in', () {
      // b ties series 10 in with 1.0 and a in with 10.1, neither starting
      // the series measured from there
      final c = surveyed().replaceSection(section('a2', [
        shot(const Point(10, 1), const Point(1, 0), 'b', 0),
        shot(const Point(1, 0), const Point(10, 1), 'a', 0),
      ]));
      expect(c.seriesTrips, {10: 'b', 11: 'b', 2: 'a'});
    });

    /// The problem of the reserved series of the trip with [id] in [c]
    SeriesProblem? problemOf(Cave c, String id) =>
        c.seriesProblemOf(c.findTrip(id)!);

    test('series their trip\'s ranges allow are fine', () {
      final c = surveyed(
          aReserves: const [SeriesRange(1, 9)],
          bReserves: const [SeriesRange(10)]);
      expect(problemOf(c, 'a'), isNull);
      expect(problemOf(c, 'b'), isNull);
    });

    test('a series outside its trip\'s closed ranges is a problem', () {
      final problem =
          problemOf(surveyed(bReserves: const [SeriesRange(10, 10)]), 'b');
      expect(problem, isA<SeriesOutsideRanges>());
      expect((problem as SeriesOutsideRanges).series, 11);
    });

    test('a series below its trip\'s open range is a problem', () {
      final problem =
          problemOf(surveyed(bReserves: const [SeriesRange(11)]), 'b');
      expect((problem as SeriesOutsideRanges).series, 10);
    });

    test('a series in another trip\'s closed range is a problem for both',
        () {
      final c = surveyed(aReserves: const [SeriesRange(2, 10)]);
      final ofB = problemOf(c, 'b') as SeriesReservedByOther;
      expect(ofB.series, 10);
      expect(ofB.reservedBy.id, 'a');
      final ofA = problemOf(c, 'a') as RangeHoldsOtherSeries;
      expect(ofA.series, 10);
      expect(ofA.trip.id, 'b');
    });

    test('another trip\'s open range reserves nothing', () {
      final c = surveyed(aReserves: const [SeriesRange(2)]);
      expect(problemOf(c, 'a'), isNull);
      expect(problemOf(c, 'b'), isNull);
    });

    test('without reserved series nothing is a problem', () {
      expect(problemOf(surveyed(), 'a'), isNull);
      expect(problemOf(surveyed(), 'b'), isNull);
    });

    test('ranges themselves can be wrong', () {
      expect(
          problemOf(surveyed(aReserves: const [SeriesRange(5, 3)]), 'a'),
          isA<RangeEndsBeforeStart>());
      expect(
          problemOf(
              surveyed(
                  aReserves: const [SeriesRange(20), SeriesRange(30, 31)]),
              'a'),
          isA<OpenRangeNotLast>());
      expect(
          problemOf(
              surveyed(
                  aReserves: const [SeriesRange(1, 5), SeriesRange(5, 8)]),
              'a'),
          isA<RangesOverlap>());
      final c = surveyed(
          aReserves: const [SeriesRange(1, 9)],
          bReserves: const [SeriesRange(8, 12)]);
      expect(problemOf(c, 'b'), isA<RangeOverlapsOtherTrip>());
    });
  });

  group('Trips', () {
    final trip = Trip(id: 'trip', date: now, declination: 2.5, createdAt: now);
    const tripStretch = MeasuredDistance(
        Point(1, 0), Point(1, 1), 5.0, 90.0, 0.0,
        tripId: 'trip');

    test('combinedSurvey corrects azimuths by the trip declination', () {
      final c = cave()
          .addTrip(trip)
          .replaceSection(section('root', [tripStretch, stretch]));
      final azimuths = c.combinedSurvey.stretches.map((s) => s.azimut);
      expect(azimuths, [92.5, 90.0]);
      // The stored data keeps the measured azimuth
      expect(c.allSections.first.survey.stretches.first.azimut, 90.0);
    });

    group('automatic declination', () {
      final autoTrip = Trip(
          id: 'trip',
          date: DateTime(2026, 10, 20),
          declination: 2.5,
          autoDeclination: true,
          createdAt: now);
      const bern = GeoPosition(46.95108, 7.43864);
      const reference = ReferencePoint(Point(1, 0), 2600000, 1200000, 500);

      Cave withReference(List<ReferencePoint> refs) => cave()
          .addTrip(autoTrip)
          .replaceSection(Section(
            id: 'root',
            name: 'root',
            survey: Survey(stretches: const [tripStretch], referencePoints: refs),
            createdAt: now,
            modifiedAt: now,
          ));

      test('is computed at the first reference point in Swiss grid', () {
        const later = ReferencePoint(Point(2, 0), 0, 0, 0);
        final c = withReference(const [reference, later]);
        expect(c.firstReferencePoint, reference);
        expect(c.declinationPosition.latitude, closeTo(bern.latitude, 1e-4));
        expect(c.declinationOf(autoTrip),
            closeTo(MagneticDeclination.at(bern, autoTrip.date), 1e-3));
      });

      test('is computed at the Hölloch if the first point is not in the grid',
          () {
        const local = ReferencePoint(Point(1, 0), 0, 0, 0);
        expect(withReference(const [local, reference]).declinationPosition,
            GeoPosition.hoelloch);
      });

      test('is computed at the first reference point in other systems', () {
        const lonLat = ReferencePoint(Point(1, 0), 18.4, -33.9, 0);
        final c = withReference(const [lonLat])
            .copyWith(coordinateSystem: CoordinateSystem.wgs84);
        expect(c.declinationPosition, const GeoPosition(-33.9, 18.4));
        // In the Swiss grid, the same numbers are local coordinates
        expect(withReference(const [lonLat]).declinationPosition,
            GeoPosition.hoelloch);
      });

      test('is computed at the Hölloch without a reference point', () {
        final c = withReference(const []);
        expect(c.firstReferencePoint, isNull);
        expect(c.declinationPosition, GeoPosition.hoelloch);
      });

      test('is turned to grid north at the reference point', () {
        const atHoelloch = ReferencePoint(Point(1, 0),
            GeoPosition.hoellochEast, GeoPosition.hoellochNorth, 735);
        final c = withReference(const [atHoelloch]);
        final trueDeclination = MagneticDeclination.at(
            GeoPosition.hoelloch, autoTrip.date);
        expect(c.automaticDeclination(autoTrip.date),
            closeTo(trueDeclination, 1e-6));
        // Grid north lies about a degree west of true north there
        expect(c.gridConvergence, closeTo(-0.99, 0.03));
        expect(c.declinationOf(autoTrip),
            closeTo(trueDeclination + c.gridConvergence, 1e-9));

        // A manual declination is already against map north
        expect(c.declinationOf(autoTrip.copyWith(autoDeclination: false)),
            2.5);
      });

      test('is turned at the Hölloch without a usable reference point', () {
        const local = ReferencePoint(Point(1, 0), 0, 0, 0);
        expect(withReference(const [local]).gridConvergence,
            closeTo(-0.99, 0.03));
        expect(withReference(const []).gridConvergence, closeTo(-0.99, 0.03));
        // In UTM, the Hölloch is close to the central meridian
        expect(
            withReference(const [])
                .copyWith(coordinateSystem: const Utm(32))
                .gridConvergence,
            closeTo(0.155, 0.005));
      });

      test('corrects azimuths instead of the manual declination', () {
        final c = withReference(const []);
        final expected = 90 +
            MagneticDeclination.at(GeoPosition.hoelloch, autoTrip.date) +
            c.gridConvergence;
        expect(c.combinedSurvey.stretches.single.azimut,
            closeTo(expected, 1e-9));
      });

      test('positions are computed in metres from degrees', () {
        // 0.001° of latitude apart: about 111 m
        const first = ReferencePoint(Point(1, 0), 8.79, 46.98, 600);
        const second = ReferencePoint(Point(2, 0), 8.79, 46.981, 610);
        final c = withReference(const [first, second])
            .copyWith(coordinateSystem: CoordinateSystem.wgs84);
        final [a, b] = c.combinedSurvey.referencePoints;
        expect(b.north - a.north, closeTo(111.2, 0.5));
        expect(b.east - a.east, closeTo(0, 0.5));
        expect(a.altitude, 600);
        // The stored data keeps the degrees
        expect(c.firstReferencePoint, first);

        // Metric systems are kept as they are
        final swiss = withReference(const [reference]);
        expect(swiss.combinedSurvey.referencePoints.single, same(reference));
      });

      group('points entered in another system', () {
        const swissPoint = ReferencePoint(Point(1, 0), 2709400, 1204300, 650,
            coordinateSystem: CoordinateSystem.swiss);
        final position = CoordinateSystem.swiss.toGeo(2709400, 1204300)!;
        Cave utmCave(List<ReferencePoint> refs) => withReference(refs)
            .copyWith(coordinateSystem: const Utm(32));

        test('keep their own system for their position', () {
          final c = utmCave(const [swissPoint]);
          expect(c.systemOf(swissPoint), CoordinateSystem.swiss);
          expect(c.referencePosition, position);
        });

        test('are converted to the cave\'s system', () {
          final c = utmCave(const [swissPoint]);
          final shown = c.inCoordinateSystem(swissPoint);
          final (:east, :north) = const Utm(32).fromGeo(position);
          expect(shown.east, east);
          expect(shown.north, north);
          expect(shown.altitude, 650);
          expect(shown.coordinateSystem, const Utm(32));
          // Positions are computed from them in the cave's grid too
          expect(c.combinedSurvey.referencePoints.single.east, east);
        });

        test('are kept as entered when in the cave\'s system', () {
          final c = withReference(const [swissPoint]);
          expect(c.inCoordinateSystem(swissPoint), same(swissPoint));
        });

        test('are kept as they are when they fit no system', () {
          const local = ReferencePoint(Point(1, 0), 10, 20, 30,
              coordinateSystem: CoordinateSystem.swiss);
          expect(utmCave(const [local]).inCoordinateSystem(local), same(local));
        });

        test('are stored in the cave\'s system once East or North is edited',
            () {
          final c = utmCave(const [swissPoint]);
          final shown = c.inCoordinateSystem(swissPoint);

          // Other edits keep the coordinates as entered
          final renamed = c.editedReferencePoint(
              swissPoint, shown.copyWith(id: const Point(2, 0), altitude: 700));
          expect(renamed.id, const Point(2, 0));
          expect(renamed.altitude, 700);
          expect(renamed.east, 2709400);
          expect(renamed.coordinateSystem, CoordinateSystem.swiss);

          final moved = c.editedReferencePoint(
              swissPoint, shown.copyWith(east: 512000));
          expect(moved.east, 512000);
          expect(moved.north, shown.north);
          expect(moved.coordinateSystem, const Utm(32));
        });

        test('untagged ones take the system they come into', () {
          const untagged = ReferencePoint(Point(1, 0), 1, 2, 3);
          final survey = const Survey(
            stretches: [],
            referencePoints: [untagged, swissPoint],
          ).withReferenceSystem(const Utm(32));
          expect(survey.referencePoints.first.coordinateSystem,
              const Utm(32));
          expect(survey.referencePoints.last, same(swissPoint));
        });

        test('keep their system through JSON', () {
          final copy = ReferencePoint.fromJson(swissPoint.toJson());
          expect(copy.coordinateSystem, CoordinateSystem.swiss);
          expect(ReferencePoint.fromJson(
                  const ReferencePoint(Point(1, 0), 1, 2, 3).toJson())
              .coordinateSystem,
              isNull);
        });
      });

      test('the coordinate system is stored with the cave', () {
        final file = CaveFile(
            id: 'c',
            name: 'c',
            coordinateSystem: const Utm(33, south: true),
            createdAt: now,
            modifiedAt: now);
        expect(CaveFile.fromJson(file.toJson()).coordinateSystem,
            const Utm(33, south: true));

        // Caves stored before there was a choice are in the Swiss grid
        final json = file.toJson()..remove('coordinateSystem');
        expect(CaveFile.fromJson(json).coordinateSystem, CoordinateSystem.swiss);
      });

      test('survives a JSON round trip of the trip', () {
        expect(Trip.fromJson(autoTrip.toJson()).autoDeclination, isTrue);
        expect(trip.toJson().containsKey('autoDeclination'), isFalse);
        expect(Trip.fromJson(trip.toJson()).autoDeclination, isFalse);
      });
    });

    test('the newest trip is the active one', () {
      final newer = Trip(id: 'newer', date: DateTime(2020), createdAt: now);
      final c = cave().addTrip(trip).addTrip(newer);
      expect(c.activeTrip, same(newer));
      expect(c.removeTrip('newer').activeTrip, same(trip));
      expect(c.removeTrip('newer').removeTrip('trip').activeTrip, isNull);
    });

    test('a trip made active is the active one until another is', () {
      final newer = Trip(
          id: 'newer', date: now, createdAt: now.add(const Duration(hours: 1)));
      final activated =
          trip.copyWith(activatedAt: now.add(const Duration(hours: 2)));
      final c = cave().addTrip(activated).addTrip(newer);
      expect(c.activeTrip, same(activated));

      // Removing it brings back the trip active before
      expect(c.removeTrip('trip').activeTrip, same(newer));

      final newest = Trip(
          id: 'newest', date: now, createdAt: now.add(const Duration(hours: 3)));
      expect(c.addTrip(newest).activeTrip, same(newest));
    });

    test('isTripUsed looks at sections nested in areas', () {
      final c = cave().addTrip(trip);
      expect(c.isTripUsed('trip'), isFalse);
      expect(
        c.replaceSection(section('a2', [tripStretch])).isTripUsed('trip'),
        isTrue,
      );
    });

    test('tripsOnlyUsedBy leaves out trips other sections or none use', () {
      final shared = Trip(id: 'shared', date: now, createdAt: now);
      final unused = Trip(id: 'unused', date: now, createdAt: now);
      const sharedStretch = MeasuredDistance(
          Point(1, 1), Point(1, 2), 5.0, 90.0, 0.0,
          tripId: 'shared');
      final c = cave()
          .addTrip(trip)
          .addTrip(shared)
          .addTrip(unused)
          .replaceSection(section('a2', [tripStretch, sharedStretch]))
          .replaceSection(section('root', [sharedStretch]));

      expect(c.tripsOnlyUsedBy('a2'), [trip]);
      expect(c.tripsOnlyUsedBy('root'), isEmpty);
      expect(c.tripsOnlyUsedBy('missing'), isEmpty);
    });

    test('tripsUsedBy gives the trips a section measured on', () {
      final shared = Trip(id: 'shared', date: now, createdAt: now);
      final unused = Trip(id: 'unused', date: now, createdAt: now);
      const sharedStretch = MeasuredDistance(
          Point(1, 1), Point(1, 2), 5.0, 90.0, 0.0,
          tripId: 'shared');
      final a2 = section('a2', [sharedStretch, tripStretch, sharedStretch]);
      final c = cave()
          .addTrip(trip)
          .addTrip(shared)
          .addTrip(unused)
          .replaceSection(a2);

      expect(c.tripsUsedBy(a2), [trip, shared]);
      expect(c.tripsUsedBy(section('root', [stretch])), isEmpty);
    });

    test('a stretch keeps its trip through JSON and edits', () {
      final json = tripStretch.toJson();
      expect(MeasuredDistance.fromJson(json).tripId, 'trip');
      expect(tripStretch.copyWith(distance: 6).tripId, 'trip');
      expect(stretch.toJson().containsKey('tripId'), isFalse);
    });

    test('Trip survives a JSON round trip', () {
      final original = Trip(
          id: 't', date: DateTime.utc(2026, 10, 8), declination: -1.5,
          comment: 'Anna, Ben', createdAt: DateTime.utc(2026, 10, 9, 8, 30));
      final copy = Trip.fromJson(original.toJson());
      expect(copy.id, 't');
      expect(copy.date, original.date);
      expect(copy.createdAt, original.createdAt);
      expect(copy.declination, -1.5);
      expect(copy.comment, 'Anna, Ben');
      expect(copy.activatedAt, isNull);
      expect(original.toJson().containsKey('activatedAt'), isFalse);

      final activated = original.copyWith(
          activatedAt: DateTime.utc(2026, 10, 10, 7));
      expect(Trip.fromJson(activated.toJson()).activatedAt,
          activated.activatedAt);

      expect(copy.reservedSeries, isEmpty);
      expect(original.toJson().containsKey('reservedSeries'), isFalse);
      const ranges = [SeriesRange(10, 19), SeriesRange(50)];
      final reserving = original.copyWith(reservedSeries: ranges);
      expect(Trip.fromJson(reserving.toJson()).reservedSeries, ranges);
    });
  });

  group('SelectionState', () {
    test('changeSection updates the section within the selected cave', () {
      final c = cave();
      final state = SelectionState()
        ..selectSection(c, c.allSections.firstWhere((s) => s.id == 'a1'));

      final changed = state.changeSection(
          'a1', (s) => s.copyWith(survey: s.survey.addStretch(stretch)));

      final a1 =
          state.selectedCave!.allSections.firstWhere((s) => s.id == 'a1');
      expect(a1.survey.stretches, [stretch]);
      expect(identical(a1, state.selectedSection), isTrue);
      expect(identical(changed, a1), isTrue);
    });

    test('changeSection builds on the changes made before', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);
      const other = MeasuredDistance(Point(1, 1), Point(1, 2), 3, 0, 0);

      state.changeSection(
          'root', (s) => s.copyWith(survey: s.survey.addStretch(stretch)));
      state.changeSection(
          'root', (s) => s.copyWith(survey: s.survey.addStretch(other)));

      expect(state.selectedSection!.survey.stretches, [stretch, other]);
    });

    test('changeSection leaves other sections alone', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);

      final changed = state.changeSection(
          'a1', (s) => s.copyWith(survey: s.survey.addStretch(stretch)));

      expect(changed, isNull);
      expect(
          state.selectedCave!.allSections
              .firstWhere((s) => s.id == 'a1')
              .survey
              .stretches,
          isEmpty);
    });

    test('removeCave clears the selection only if it is in that cave', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);

      state.removeCave('other cave');
      expect(state.selectedSection?.id, 'root');

      state.removeCave('cave');
      expect(state.selectedSection, isNull);
      expect(state.selectedCave, isNull);
    });

    test('removeSection clears the selection if it is the selected one', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);

      state.removeSection('cave', 'root');

      expect(state.selectedSection, isNull);
      expect(state.selectedCave, isNull);
    });

    test('removeSection removes another section from the selected cave', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);

      state.removeSection('cave', 'a2');
      state.removeSection('other cave', 'a1');

      expect(state.selectedSection?.id, 'root');
      expect(state.selectedCave!.allSections.map((s) => s.id), ['root', 'a1']);
    });

    test('updateTrips takes over trips but keeps the selected sections', () {
      final c = cave();
      final state = SelectionState()..selectSection(c, c.sections.first);
      state.changeSection(
          'root', (s) => s.copyWith(survey: s.survey.addStretch(stretch)));

      // A stale copy of the cave, as the explorer may hold it
      final withTrip = c.addTrip(Trip(id: 'trip', date: now, createdAt: now));
      state.updateTrips(withTrip);

      expect(state.selectedCave!.activeTrip?.id, 'trip');
      expect(state.selectedCave!.sections.first.survey.stretches, [stretch]);
    });
  });
}
