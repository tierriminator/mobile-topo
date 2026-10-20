import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/data/therion_file.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/coordinate_system.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';

void main() {
  final created = DateTime(2024, 3, 15, 9);
  final trip = Trip(
    id: 't1',
    date: DateTime(2024, 3, 15),
    declination: 2.5,
    comment: 'Alice, Bob',
    createdAt: created,
  );
  final earlierTrip = Trip(id: 't0', date: DateTime(2023, 1, 2), createdAt: created);

  Section section(String id, String name, Survey survey,
          {Sketch outline = const Sketch(), Sketch sideView = const Sketch()}) =>
      Section(
        id: id,
        name: name,
        survey: survey,
        outlineSketch: outline,
        sideViewSketch: sideView,
        createdAt: created,
        modifiedAt: created,
      );

  final entrance = section(
    's1',
    'Entrance',
    const Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 10, 90, 0,
            tripId: 't1', comment: 'squeeze'),
        MeasuredDistance(Point(1, 1), null, 2, 0, 0, tripId: 't1'),
        MeasuredDistance(Point(1, 2), Point(1, 1), 5, 270, 0,
            tripId: 't1', flipped: true),
        MeasuredDistance(Point(1, 2), Point(1, 3), 3, 0, -90, tripId: 't0'),
        MeasuredDistance(Point(1, 3), Point(1, 4), 1, 0, 0),
      ],
      referencePoints: [
        ReferencePoint(Point(1, 0), 100, 200, 300, comment: 'GPS'),
      ],
    ),
    outline: const Sketch(strokes: [
      Stroke(
          points: [Offset(100, -200), Offset(110, -201)],
          color: SketchColors.red),
    ]),
    sideView: const Sketch(strokes: [
      Stroke(
          points: [Offset(0, -300), Offset(1, -302)],
          color: SketchColors.black),
    ]),
  );
  final cave = Cave(
    id: 'c',
    name: 'Höhle "Nord"',
    sections: [entrance],
    trips: [earlierTrip, trip],
    createdAt: created,
    modifiedAt: created,
  );

  group('survey', () {
    final text = TherionFile.survey(cave, [entrance], cave.name);
    final lines = text.split('\n');

    test('names the survey with a keyword and the title', () {
      expect(lines[0], 'encoding utf-8');
      expect(lines[1], 'survey H_hle_Nord_ -title "Höhle ""Nord"""');
      expect(lines.where((l) => l.isNotEmpty).last, 'endsurvey');
    });

    test('fixes the reference points', () {
      expect(lines, contains('    fix 1.0 100.000 200.000 300.000 # GPS'));
      // Local coordinates only need no coordinate system
      expect(lines.where((l) => l.trim().startsWith('cs ')), isEmpty);
    });

    group('coordinate system', () {
      /// The lines of the fixed stations' centreline for [references] in
      /// [system]
      List<String> fixes(
          CoordinateSystem system, List<ReferencePoint> references) {
        final s = section(
            's', 'S', Survey(stretches: const [], referencePoints: references));
        final text = TherionFile.survey(
            cave.copyWith(sections: [s], coordinateSystem: system), [s], 'S');
        final lines = text.split('\n');
        final start = lines.indexOf('  centreline');
        return lines.sublist(start + 1, lines.indexOf('  endcentreline'));
      }

      test('is the EPSG code of the Swiss grid', () {
        expect(
            fixes(CoordinateSystem.swiss, const [
              ReferencePoint(Point(1, 0), 2702698, 1203724, 735),
              ReferencePoint(Point(2, 0), 702698, 203724, 735),
            ]),
            [
              '    cs EPSG:2056',
              '    fix 1.0 2702698.000 1203724.000 735.000',
              '    cs EPSG:21781',
              '    fix 2.0 702698.000 203724.000 735.000',
            ]);
      });

      test('names the UTM zone and hemisphere', () {
        expect(
            fixes(const Utm(33, south: true), const [
              ReferencePoint(Point(1, 0), 512345, 7190000, 1200),
            ]).first,
            '    cs UTM33S');
        expect(
            fixes(const Utm(32), const [
              ReferencePoint(Point(1, 0), 512345, 5200000, 1200),
            ]).first,
            '    cs UTM32');
      });

      test('keeps degrees as they are, longitude first', () {
        expect(
            fixes(CoordinateSystem.wgs84, const [
              ReferencePoint(Point(1, 0), 8.78839, 46.97664, 735),
            ]),
            [
              '    cs long-lat',
              '    fix 1.0 8.7883900 46.9766400 735.000',
            ]);
      });

      test('is local for points that do not fit the system', () {
        expect(
            fixes(CoordinateSystem.swiss, const [
              ReferencePoint(Point(1, 0), 2702698, 1203724, 735),
              ReferencePoint(Point(2, 0), 10, 20, 30),
            ]),
            [
              '    cs EPSG:2056',
              '    fix 1.0 2702698.000 1203724.000 735.000',
              '    cs local',
              '    fix 2.0 10.000 20.000 30.000',
            ]);
      });
    });

    test('writes a centreline per trip in trip order', () {
      final earlier = lines.indexOf('    date 2023.01.02');
      final later = lines.indexOf('    date 2024.03.15');
      expect(earlier, greaterThan(0));
      expect(later, greaterThan(earlier));
      expect(lines[later + 1], '    # Alice, Bob');
      // Manual declinations are against map north
      expect(lines[later + 2], '    grid-angle 2.50 degrees');
      expect(lines[later + 3], '    data normal from to length compass clino');
    });

    test('writes shots, splays and side view directions', () {
      final start = lines.indexOf('    date 2024.03.15');
      expect(lines.sublist(start + 4, start + 10), [
        '    extend right',
        '    1.0 1.1 10.000 90.00 0.00 # squeeze',
        '    1.1 - 2.000 0.00 0.00',
        '    extend left',
        '    1.2 1.1 5.000 270.00 0.00',
        '  endcentreline',
      ]);
    });

    test('puts stretches without a trip last, with no declination', () {
      final last = lines.lastIndexOf('  centreline');
      expect(lines.sublist(last + 1, last + 6), [
        '    grid-angle 0.00 degrees',
        '    data normal from to length compass clino',
        '    extend right',
        '    1.3 1.4 1.000 0.00 0.00',
        '  endcentreline',
      ]);
    });

    test('gives automatic declinations against true north', () {
      final auto = trip.copyWith(autoDeclination: true);
      final autoCave = cave.copyWith(trips: [earlierTrip, auto]);
      final lines = TherionFile.survey(autoCave, [entrance], 'S').split('\n');
      final value = autoCave.automaticDeclination(auto.date);
      expect(lines, contains('    declination ${value.toStringAsFixed(2)} degrees'));
    });

    test('falls back to a plain survey name', () {
      expect(TherionFile.survey(cave, [], '  ').split('\n')[1],
          'survey survey -title "  "');
    });
  });

  group('PocketTopo text', () {
    final text = TherionFile.pocketTopoText(cave, [entrance]);
    final lines = text.split('\n');

    List<String> block(String start, String end) {
      final from = lines.indexOf(start);
      return lines.sublist(from + 1, lines.indexOf(end, from + 1));
    }

    test('writes the reference points', () {
      expect(lines.sublist(0, 2), ['FIX', '1.0\t100.000\t200.000\t300.000']);
    });

    test('writes the stretches by trip with their side view direction', () {
      expect(block('DATE 2024-03-15', 'TRIP'), [
        'DECLINATION\t2.50',
        'DATA',
        '1.0\t1.1\t90.00\t0.00\t10.000\t>',
        '1.1\t\t0.00\t0.00\t2.000\t>',
        '1.2\t1.1\t270.00\t0.00\t5.000\t<',
      ]);
      expect(block('DATE 2023-01-02', 'TRIP'), [
        'DECLINATION\t0.00',
        'DATA',
        '1.2\t1.3\t0.00\t-90.00\t3.000\t>',
      ]);
      expect(block('TRIP', 'DATE 2023-01-02'), isEmpty);
    });

    test('draws the plan in metres with north up and declination applied',
        () {
      final plan = block('PLAN', 'ELEVATION');
      expect(plan.sublist(0, 2), ['STATIONS', '100.000\t200.000\t1.0']);
      // 10 m at 90° plus 2.5° declination
      expect(plan[2], startsWith('109.990\t199.564\t1.1'));
      expect(plan, contains('SHOTS'));
      expect(plan.sublist(plan.indexOf('POLYLINE RED')), [
        'POLYLINE RED',
        '100.000\t200.000',
        '110.000\t201.000',
      ]);
    });

    test('draws the side view with altitude up', () {
      final from = lines.indexOf('ELEVATION');
      final elevation = lines.sublist(from + 1);
      expect(elevation.sublist(0, 2), ['STATIONS', '0.000\t300.000\t1.0']);
      expect(elevation.sublist(elevation.indexOf('POLYLINE BLACK')), [
        'POLYLINE BLACK',
        '0.000\t300.000',
        '1.000\t302.000',
        '',
      ]);
    });
  });
}
