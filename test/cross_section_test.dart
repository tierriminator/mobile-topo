import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/data/sketch_serialization.dart';
import 'package:mobile_topo/models/cross_section.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';

Matcher _near(Offset expected) => isA<Offset>()
    .having((o) => (o - expected).distance, 'distance to $expected',
        lessThan(1e-9));

void main() {
  // At a station where the passage runs east: walls 2 m left and 1 m
  // right, roof 3 m up, and a shot 4 m further along the passage
  const splays = [
    MeasuredDistance(Point(1, 1), null, 2, 0, 0),
    MeasuredDistance(Point(1, 1), null, 1, 180, 0),
    MeasuredDistance(Point(1, 1), null, 3, 0, 90),
    MeasuredDistance(Point(1, 1), null, 4, 90, 0),
  ];

  group('CrossSection.splayEnds', () {
    test('a vertical one looks along the passage', () {
      const crossSection = CrossSection(
        station: Point(1, 1),
        position: Offset(10, 10),
        kind: CrossSectionKind.vertical,
      );

      final ends = crossSection.splayEnds(splays, azimuth: 90);

      expect(ends[0], _near(const Offset(8, 10)));
      expect(ends[1], _near(const Offset(11, 10)));
      expect(ends[2], _near(const Offset(10, 7)));
      // Along the passage, so seen end-on
      expect(ends[3], _near(const Offset(10, 10)));
    });

    test('a horizontal one is north up, whichever way the passage runs', () {
      const crossSection = CrossSection(
        station: Point(1, 1),
        position: Offset(10, 10),
        kind: CrossSectionKind.horizontal,
      );

      for (final azimuth in [0.0, 90.0, 225.0]) {
        final ends = crossSection.splayEnds(splays, azimuth: azimuth);
        expect(ends[0], _near(const Offset(10, 8)), reason: 'north wall');
        expect(ends[1], _near(const Offset(10, 11)), reason: 'south wall');
        // Straight up, so seen end-on
        expect(ends[2], _near(const Offset(10, 10)), reason: 'roof');
        expect(ends[3], _near(const Offset(14, 10)), reason: 'east');
      }
    });
  });

  group('Survey.passageAzimuth', () {
    test('bisects the shots to and from the station', () {
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 90, 0),
        ],
        referencePoints: [],
      );

      expect(survey.passageAzimuth(const Point(1, 1)), closeTo(45, 1e-9));
      expect(survey.passageAzimuth(const Point(1, 0)), closeTo(0, 1e-9));
    });

    test('ignores branches', () {
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 0, 0),
          // Branch starting at 1.1
          MeasuredDistance(Point(1, 1), Point(2, 0), 5, 90, 0),
        ],
        referencePoints: [],
      );

      expect(survey.passageAzimuth(const Point(1, 1)), closeTo(0, 1e-9));
    });

    test('takes the first shot leading to a station that closes a loop', () {
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 0, 0),
          // Closing the loop back to 1.0, measured from 1.2
          MeasuredDistance(Point(1, 2), Point(1, 0), 7, 225, 0),
        ],
        referencePoints: [],
      );

      // Arrived at 1.2 from 1.1 going north; the closing shot also counts
      // as leading to 1.2, but comes second
      expect(survey.passageAzimuth(const Point(1, 2)), closeTo(0, 1e-9));
      // 1.0 leads on to 1.1 first, eastwards
      expect(survey.passageAzimuth(const Point(1, 0)), closeTo(90, 1e-9));
    });

    test('is null where the survey turns back', () {
      const survey = Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 5, 180, 0),
        ],
        referencePoints: [],
      );

      expect(survey.passageAzimuth(const Point(1, 1)), isNull);
    });

    test('takes backward shots in survey direction', () {
      // Measured from 1.1 back to 1.0, so the survey runs east
      const survey = Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(1, 0), 5, 270, 0)],
        referencePoints: [],
      );

      expect(survey.passageAzimuth(const Point(1, 1)), closeTo(90, 1e-9));
    });

    test('is null without a survey shot at the station', () {
      const survey = Survey(stretches: splays, referencePoints: []);

      expect(survey.passageAzimuth(const Point(1, 1)), isNull);
    });
  });

  group('Sketch', () {
    const crossSection = CrossSection(
      station: Point(1, 1),
      position: Offset(5, 5),
      kind: CrossSectionKind.vertical,
    );
    const stroke =
        Stroke(points: [Offset(20, 20), Offset(21, 21)], color: Colors.black);

    test('keeps cross sections when strokes change', () {
      final sketch = const Sketch().addCrossSection(crossSection);

      expect(sketch.addStroke(stroke).crossSections, [crossSection]);
      expect(sketch.addStroke(stroke).removeLastStroke().crossSections,
          [crossSection]);
    });

    test('erases a cross section at its station copy', () {
      final sketch =
          const Sketch().addCrossSection(crossSection).addStroke(stroke);

      expect(sketch.eraseAt(const Offset(10, 10), 1), isNull);
      final erased = sketch.eraseAt(const Offset(5.5, 5), 1)!;
      expect(erased.crossSections, isEmpty);
      expect(erased.strokes, hasLength(1));
    });
  });

  group('SketchSerializer', () {
    test('cross sections survive a round trip', () {
      final sketch = const Sketch()
          .addStroke(const Stroke(
              points: [Offset(1, 2), Offset(3, 4)], color: Colors.black))
          .addCrossSection(const CrossSection(
            station: Point(2, 13),
            position: Offset(1.5, -2.5),
            kind: CrossSectionKind.horizontal,
          ));

      final copy = SketchSerializer.sketchFromBytes(
          SketchSerializer.sketchToBytes(sketch));

      expect(copy.strokes.single.points, const [Offset(1, 2), Offset(3, 4)]);
      final crossSection = copy.crossSections.single;
      expect(crossSection.station, const Point(2, 13));
      expect(crossSection.station.toString(), '2.13');
      expect(crossSection.position, const Offset(1.5, -2.5));
      expect(crossSection.kind, CrossSectionKind.horizontal);
    });

    test('reads version 1 sketches, which have strokes only', () {
      const stroke =
          Stroke(points: [Offset(1, 2), Offset(3, 4)], color: Colors.black);
      final strokeBytes = SketchSerializer.strokeToBytes(stroke);
      final bytes = Uint8List(5 + strokeBytes.length)
        ..[0] = 1
        ..setRange(5, 5 + strokeBytes.length, strokeBytes);
      ByteData.view(bytes.buffer).setUint32(1, 1, Endian.little);

      final sketch = SketchSerializer.sketchFromBytes(bytes);

      expect(sketch.strokes.single.points, stroke.points);
      expect(sketch.crossSections, isEmpty);
    });
  });
}
