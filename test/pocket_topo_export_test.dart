import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/data/pocket_topo_file.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/cross_section.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';

import 'pocket_topo_file_test.dart' show TopWriter, topFile;

/// One unit of the file's angles, in degrees
const _angleUnit = 360 / 65536;

final _now = DateTime(2026, 10, 9);

Section _section(String id, Survey survey,
        {Sketch outline = const Sketch(), Sketch sideView = const Sketch()}) =>
    Section(
      id: id,
      name: id,
      survey: survey,
      outlineSketch: outline,
      sideViewSketch: sideView,
      createdAt: _now,
      modifiedAt: _now,
    );

Cave _cave(List<Section> sections, {List<Trip> trips = const []}) => Cave(
      id: 'cave',
      name: 'Cave',
      sections: sections,
      trips: trips,
      createdAt: _now,
      modifiedAt: _now,
    );

PocketTopoImport _read(Uint8List bytes) {
  var id = 0;
  return PocketTopoFile.read(bytes, newId: () => 'read${id++}');
}

void main() {
  final manualTrip = Trip(
    id: 'manual',
    date: DateTime(2026, 10, 8),
    declination: -1.5,
    comment: 'Anna, Ben',
    createdAt: DateTime(2026, 10, 8, 9, 30),
  );
  final autoTrip = Trip(
    id: 'auto',
    date: DateTime(2026, 10, 9),
    autoDeclination: true,
    createdAt: DateTime(2026, 10, 9, 14),
  );
  final unusedTrip = Trip(
    id: 'unused',
    date: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 10, 1),
  );

  const survey = Survey(
    stretches: [
      MeasuredDistance(Point(1, 0), Point(1, 1), 5.123, 90, 10,
          tripId: 'manual'),
      MeasuredDistance(Point(1, 1), null, 2.5, 355.5, -20.25,
          tripId: 'manual', comment: 'Big hall'),
      MeasuredDistance(Point(1, 1), Point(1, 2), 7.5, 180, -5,
          tripId: 'auto', flipped: true),
      MeasuredDistance(Point(1, 2), Point(0, 7), 3, 270, 0),
    ],
    referencePoints: [
      ReferencePoint(Point(1, 0), 2600000.5, 1200000.25, 1500,
          comment: 'Entrance'),
    ],
  );
  // Sketches are drawn in the world coordinates of the cave: near the
  // entrance in the outline, around its altitude in the side view
  Offset plan(double x, double y) => Offset(2600000.5 + x, -1200000.25 + y);
  Offset side(double x, double y) => Offset(x, -1500 + y);
  final outline = Sketch(
    strokes: [
      Stroke(points: [plan(1, 2), plan(3.5, -4)], color: SketchColors.blue),
      Stroke(points: [plan(0, 0), plan(1, 1)], color: SketchColors.black),
    ],
    crossSections: [
      CrossSection(
          station: const Point(1, 1),
          position: plan(5, 3),
          kind: CrossSectionKind.vertical),
      CrossSection(
          station: const Point(1, 2),
          position: plan(-2, 1),
          kind: CrossSectionKind.horizontal),
    ],
  );
  final sideView = Sketch(strokes: [
    Stroke(points: [side(2, -1), side(6, 0.5)], color: SketchColors.orange),
  ]);
  final section =
      _section('section', survey, outline: outline, sideView: sideView);
  final cave =
      _cave([section], trips: [manualTrip, autoTrip, unusedTrip]);

  test('an empty section makes an empty file', () {
    final empty =
        _section('empty', const Survey(stretches: [], referencePoints: []));
    expect(PocketTopoFile.write(_cave([empty]), [empty]), topFile());
  });

  group('reading the file back', () {
    final read = _read(PocketTopoFile.write(cave, [section]));

    test('gives the trips the stretches were measured on', () {
      expect(read.trips, hasLength(2));
      final [manual, auto] = read.trips;
      expect(manual.date, manualTrip.date);
      expect(manual.createdAt, manualTrip.createdAt);
      expect(manual.declination, closeTo(-1.5, _angleUnit));
      expect(manual.autoDeclination, isFalse);
      expect(manual.comment, 'Anna, Ben');
      expect(auto.date, autoTrip.date);
      expect(auto.autoDeclination, isTrue);
    });

    test('gives the stretches', () {
      final stretches = read.survey.stretches;
      expect(stretches, hasLength(survey.stretches.length));
      final tripIds = {'read0': 'manual', 'read1': 'auto'};
      for (var i = 0; i < stretches.length; i++) {
        final written = survey.stretches[i];
        final back = stretches[i];
        expect(back.from, written.from);
        expect(back.to, written.to);
        expect(back.distance, closeTo(written.distance, 0.0005));
        expect(back.azimut, closeTo(written.azimut, _angleUnit));
        expect(back.inclination, closeTo(written.inclination, _angleUnit));
        expect(back.flipped, written.flipped);
        expect(back.comment, written.comment);
        expect(tripIds[back.tripId], written.tripId);
      }
    });

    test('gives the reference points', () {
      final ref = read.survey.referencePoints.single;
      expect(ref.id, const Point(1, 0));
      expect(ref.east, closeTo(2600000.5, 0.0005));
      expect(ref.north, closeTo(1200000.25, 0.0005));
      expect(ref.altitude, closeTo(1500, 0.0005));
      expect(ref.comment, 'Entrance');
    });

    test('places the drawings where they were', () {
      final imported = _cave(
        [_section('imported', read.survey)],
        trips: read.trips,
      );
      final (outlineBack, sideViewBack) = read.sketchesIn(imported);

      void expectNear(Offset back, Offset written) =>
          expect((back - written).distance, lessThan(0.002));

      expect(outlineBack.strokes, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(outlineBack.strokes[i].color, outline.strokes[i].color);
        for (var j = 0; j < outline.strokes[i].points.length; j++) {
          expectNear(outlineBack.strokes[i].points[j],
              outline.strokes[i].points[j]);
        }
      }
      expect(outlineBack.crossSections, hasLength(2));
      for (var i = 0; i < 2; i++) {
        final back = outlineBack.crossSections[i];
        final written = outline.crossSections[i];
        expect(back.station, written.station);
        expect(back.kind, written.kind);
        expectNear(back.position, written.position);
      }
      final stroke = sideViewBack.strokes.single;
      expect(stroke.color, SketchColors.orange);
      expectNear(stroke.points.first, side(2, -1));
      expectNear(stroke.points.last, side(6, 0.5));
    });
  });

  test('writes series 0 as plain numbers', () {
    final bytes = PocketTopoFile.write(cave, [section]);
    final view = ByteData.sublistView(bytes);
    final plain = TopWriter.number(7);
    var found = false;
    for (var i = 0; i + 4 <= bytes.length; i++) {
      if (view.getUint32(i, Endian.little) == plain) found = true;
    }
    expect(found, isTrue);
  });

  test('a station that does not fit the format is reported', () {
    for (final station in const [Point(1.5, 0), Point(40000, 0), Point(1, -1)]) {
      final odd = _section(
          'odd',
          Survey(
            stretches: [MeasuredDistance(const Point(1, 0), station, 1, 0, 0)],
            referencePoints: const [],
          ));
      expect(
        () => PocketTopoFile.write(_cave([odd]), [odd]),
        throwsA(isA<PocketTopoStationException>()
            .having((e) => e.station, 'station', station)),
      );
    }
  });

  test('a cave of several sections makes one file', () {
    final continuation = _section(
      'continuation',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 2), Point(1, 3), 4, 0, 0)],
        referencePoints: [],
      ),
      outline: Sketch(strokes: [
        Stroke(points: [plan(10, 10), plan(11, 10)], color: SketchColors.red),
      ]),
    );
    final whole = _cave([section, continuation],
        trips: [manualTrip, autoTrip]);
    final read = _read(PocketTopoFile.write(whole, whole.sections));

    expect(read.survey.stretches, hasLength(survey.stretches.length + 1));
    expect(read.outlineSketch.strokes, hasLength(3));
  });
}
