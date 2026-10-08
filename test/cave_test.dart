import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/models/cave.dart';
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

    test('the newest trip is the active one', () {
      final newer = Trip(id: 'newer', date: DateTime(2020), createdAt: now);
      final c = cave().addTrip(trip).addTrip(newer);
      expect(c.activeTrip, same(newer));
      expect(c.removeTrip('newer').activeTrip, same(trip));
      expect(c.removeTrip('newer').removeTrip('trip').activeTrip, isNull);
    });

    test('isTripUsed looks at sections nested in areas', () {
      final c = cave().addTrip(trip);
      expect(c.isTripUsed('trip'), isFalse);
      expect(
        c.replaceSection(section('a2', [tripStretch])).isTripUsed('trip'),
        isTrue,
      );
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
