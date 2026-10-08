import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/data/pocket_topo_file.dart';
import 'package:mobile_topo/models/cross_section.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';

/// Writes `.top` files byte by byte as described in
/// docs/pocket_topo/PocketTopoFileFormat.txt
class TopWriter {
  final _bytes = BytesBuilder();

  void byte(int value) => _bytes.addByte(value);

  void int16(int value) => _bytes.add(
      (ByteData(2)..setInt16(0, value, Endian.little)).buffer.asUint8List());

  void int32(int value) => _bytes.add(
      (ByteData(4)..setInt32(0, value, Endian.little)).buffer.asUint8List());

  void uint32(int value) => _bytes.add(
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List());

  void int64(int value) => _bytes.add(
      (ByteData(8)..setInt64(0, value, Endian.little)).buffer.asUint8List());

  void string(String text) {
    final encoded = utf8.encode(text);
    var length = encoded.length;
    while (length >= 0x80) {
      byte(length & 0x7F | 0x80);
      length >>= 7;
    }
    byte(length);
    _bytes.add(encoded);
  }

  void header({int version = 3}) {
    byte(0x54);
    byte(0x6F);
    byte(0x70);
    byte(version);
  }

  /// [time] is taken as the wall clock time PocketTopo stores
  void trip(DateTime time, {String comment = '', int declination = 0}) {
    final utc = DateTime.utc(time.year, time.month, time.day, time.hour,
        time.minute, time.second);
    int64(utc.microsecondsSinceEpoch * 10 + 621355968000000000);
    string(comment);
    int16(declination);
  }

  static int majorMinor(int major, int minor) => major << 16 | minor;
  static int number(int n) => 0x80000001 + n;
  static const int undefined = 0x80000000;

  void shot(int from, int to, int distanceMm, int azimuth, int inclination,
      {bool flipped = false, int trip = -1, String? comment}) {
    uint32(from);
    uint32(to);
    int32(distanceMm);
    int16(azimuth.toSigned(16));
    int16(inclination);
    byte((flipped ? 1 : 0) | (comment != null ? 2 : 0));
    byte(0); // Roll
    int16(trip);
    if (comment != null) string(comment);
  }

  void reference(int station, int eastMm, int northMm, int altitudeMm,
      {String comment = ''}) {
    uint32(station);
    int64(eastMm);
    int64(northMm);
    int32(altitudeMm);
    string(comment);
  }

  void mapping() {
    int32(0);
    int32(0);
    int32(500);
  }

  void polygon(List<(int, int)> points, int color) {
    byte(1);
    int32(points.length);
    for (final (x, y) in points) {
      int32(x);
      int32(y);
    }
    byte(color);
  }

  void xSection(int x, int y, int station, int direction) {
    byte(3);
    int32(x);
    int32(y);
    uint32(station);
    int32(direction);
  }

  /// An empty drawing
  void drawing() {
    mapping();
    byte(0);
  }

  Uint8List get bytes => _bytes.toBytes();
}

/// A file with the given trip, shot and reference writers and empty drawings
Uint8List topFile({
  void Function(TopWriter w)? trips,
  int tripCount = 0,
  void Function(TopWriter w)? shots,
  int shotCount = 0,
  void Function(TopWriter w)? references,
  int referenceCount = 0,
  void Function(TopWriter w)? outline,
  void Function(TopWriter w)? sideView,
}) {
  final w = TopWriter()..header();
  w.int32(tripCount);
  trips?.call(w);
  w.int32(shotCount);
  shots?.call(w);
  w.int32(referenceCount);
  references?.call(w);
  w.mapping();
  (outline ?? (w) => w.drawing())(w);
  (sideView ?? (w) => w.drawing())(w);
  return w.bytes;
}

PocketTopoImport read(Uint8List bytes) {
  var id = 0;
  return PocketTopoFile.read(bytes, newId: () => 'trip${id++}');
}

void main() {
  group('file', () {
    test('reads an empty file', () {
      final result = read(topFile());
      expect(result.trips, isEmpty);
      expect(result.survey.stretches, isEmpty);
      expect(result.survey.referencePoints, isEmpty);
      expect(result.outlineSketch.isEmpty, isTrue);
      expect(result.sideViewSketch.isEmpty, isTrue);
    });

    test('rejects files of other formats and versions', () {
      expect(() => read(Uint8List.fromList(utf8.encode('Cal\x01'))),
          throwsFormatException);
      final version2 = (TopWriter()..header(version: 2)).bytes;
      expect(() => read(version2), throwsFormatException);
    });

    test('rejects truncated files', () {
      final bytes = topFile();
      expect(() => read(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
          throwsFormatException);
    });

    test('rejects unknown drawing elements', () {
      final bytes = topFile(outline: (w) {
        w.mapping();
        w.byte(2);
      });
      expect(() => read(bytes), throwsFormatException);
    });
  });

  group('trips', () {
    test('reads date, comment and declination', () {
      final result = read(topFile(
        tripCount: 2,
        trips: (w) {
          w.trip(DateTime(2009, 7, 14, 10, 30),
              comment: 'Entrance series', declination: 0x0200);
          w.trip(DateTime(2010, 1, 2), declination: -0x0100);
        },
      ));

      final [first, second] = result.trips;
      expect(first.id, 'trip0');
      expect(first.date, DateTime(2009, 7, 14));
      expect(first.createdAt, DateTime(2009, 7, 14, 10, 30));
      expect(first.comment, 'Entrance series');
      expect(first.declination, closeTo(2.8125, 1e-9));
      expect(second.id, 'trip1');
      expect(second.date, DateTime(2010, 1, 2));
      expect(second.declination, closeTo(-1.40625, 1e-9));
    });

    test('shots refer to their trip by ID', () {
      final result = read(topFile(
        tripCount: 2,
        trips: (w) {
          w.trip(DateTime(2009, 7, 14));
          w.trip(DateTime(2009, 7, 15));
        },
        shotCount: 2,
        shots: (w) {
          w.shot(TopWriter.majorMinor(1, 0), TopWriter.undefined, 1000, 0, 0,
              trip: 1);
          w.shot(TopWriter.majorMinor(1, 0), TopWriter.undefined, 1000, 0, 0);
        },
      ));
      expect(result.survey.stretches.map((s) => s.tripId), ['trip1', null]);
    });
  });

  group('shots', () {
    test('reads stations, distance and angles', () {
      final result = read(topFile(
        shotCount: 1,
        shots: (w) => w.shot(TopWriter.majorMinor(1, 2),
            TopWriter.majorMinor(1, 3), 12345, 0xC000, -0x1000),
      ));

      final [stretch] = result.survey.stretches;
      expect(stretch.from, const Point(1, 2));
      expect(stretch.to, const Point(1, 3));
      expect(stretch.distance, closeTo(12.345, 1e-9));
      expect(stretch.azimut, closeTo(270, 1e-9));
      expect(stretch.inclination, closeTo(-22.5, 1e-9));
      expect(stretch.flipped, isFalse);
      expect(stretch.comment, isNull);
    });

    test('reads plain station numbers as series 0', () {
      final result = read(topFile(
        shotCount: 2,
        shots: (w) {
          w.shot(TopWriter.number(0), TopWriter.number(5), 1000, 0, 0);
          w.shot(TopWriter.number(5), TopWriter.number(70000), 1000, 0, 0);
        },
      ));
      expect(result.survey.stretches.map((s) => (s.from, s.to)), [
        (const Point(0, 0), const Point(0, 5)),
        (const Point(0, 5), const Point(0, 70000)),
      ]);
    });

    test('reads flipped shots and comments', () {
      final result = read(topFile(
        shotCount: 1,
        shots: (w) => w.shot(
            TopWriter.majorMinor(1, 0), TopWriter.majorMinor(1, 1), 1000, 0, 0,
            flipped: true, comment: ' Big chamber '),
      ));
      final [stretch] = result.survey.stretches;
      expect(stretch.flipped, isTrue);
      expect(stretch.comment, 'Big chamber');
    });

    test('averages repeated measurements of a survey shot', () {
      // Azimuths around north: 359.5, 0 and 0.5 degrees
      final result = read(topFile(
        shotCount: 5,
        shots: (w) {
          final from = TopWriter.majorMinor(1, 0);
          final to = TopWriter.majorMinor(1, 1);
          w.shot(from, to, 10000, 0xFFA5, 0x0100);
          w.shot(from, to, 10020, 0, 0x0100, comment: 'Duck');
          w.shot(from, to, 10040, 0x005B, 0x0100);
          w.shot(from, TopWriter.undefined, 2000, 0x4000, 0);
          w.shot(from, to, 5000, 0, 0);
        },
      ));

      final [average, splay, again] = result.survey.stretches;
      expect(average.distance, closeTo(10.02, 1e-9));
      expect(average.azimut % 360, anyOf(closeTo(0, 1e-3), closeTo(360, 1e-3)));
      expect(average.inclination, closeTo(1.40625, 1e-3));
      expect(average.comment, 'Duck');
      expect(splay.to, isNull);
      // Not following directly: a separate measurement of the same shot
      expect(again.distance, closeTo(5, 1e-9));
    });

    test('reads splays and turns those towards a station around', () {
      final result = read(topFile(
        shotCount: 3,
        shots: (w) {
          w.shot(TopWriter.majorMinor(1, 0), TopWriter.undefined, 2000,
              0x4000, 0x1000);
          w.shot(TopWriter.undefined, TopWriter.majorMinor(1, 1), 3000,
              0x4000, 0x1000);
          w.shot(TopWriter.undefined, TopWriter.undefined, 4000, 0, 0);
        },
      ));

      final [splay, reversed] = result.survey.stretches;
      expect(splay.from, const Point(1, 0));
      expect(splay.to, isNull);
      expect(splay.azimut, closeTo(90, 1e-9));
      expect(reversed.from, const Point(1, 1));
      expect(reversed.to, isNull);
      expect(reversed.azimut, closeTo(270, 1e-9));
      expect(reversed.inclination, closeTo(-22.5, 1e-9));
      expect(result.skippedShots, 1);
    });
  });

  test('reads reference points', () {
    final comment = 'GPS ${'ä' * 100}';
    final result = read(topFile(
      referenceCount: 1,
      references: (w) => w.reference(TopWriter.majorMinor(1, 0), -600123456,
          5200000000, -12345,
          comment: comment),
    ));

    final [reference] = result.survey.referencePoints;
    expect(reference.id, const Point(1, 0));
    expect(reference.east, closeTo(-600123.456, 1e-9));
    expect(reference.north, closeTo(5200000, 1e-9));
    expect(reference.altitude, closeTo(-12.345, 1e-9));
    expect(reference.comment, comment);
  });

  group('drawings', () {
    test('reads strokes with their colors', () {
      final result = read(topFile(
        outline: (w) {
          w.mapping();
          w.polygon([(0, 0), (1000, 2000)], 3);
          w.polygon([(500, 500)], 7);
          w.byte(0);
        },
      ));

      final [line, dot] = result.outlineSketch.strokes;
      expect(line.points, const [Offset(0, 0), Offset(1, 2)]);
      expect(line.color, SketchColors.brown);
      expect(dot.points, const [Offset(0.5, 0.5), Offset(0.5, 0.5)]);
      expect(dot.color, SketchColors.orange);
    });

    test('reads cross sections', () {
      final result = read(topFile(
        sideView: (w) {
          w.mapping();
          w.xSection(1000, -1000, TopWriter.majorMinor(1, 2), -1);
          w.xSection(2000, 0, TopWriter.majorMinor(1, 3), 0x4000);
          w.byte(0);
        },
      ));

      expect(result.sideViewSketch.crossSections, const [
        CrossSection(
          station: Point(1, 2),
          position: Offset(1, -1),
          kind: CrossSectionKind.horizontal,
        ),
        CrossSection(
          station: Point(1, 3),
          position: Offset(2, 0),
          kind: CrossSectionKind.vertical,
        ),
      ]);
    });

    test('places drawings relative to the first reference point', () {
      final result = read(topFile(
        shotCount: 1,
        shots: (w) => w.shot(TopWriter.majorMinor(1, 0),
            TopWriter.majorMinor(1, 1), 10000, 0x4000, 0),
        referenceCount: 1,
        references: (w) =>
            w.reference(TopWriter.majorMinor(1, 0), 100000, 200000, 300000),
        outline: (w) {
          w.mapping();
          w.polygon([(0, 0), (10000, 0)], 1);
          w.byte(0);
        },
        sideView: (w) {
          w.mapping();
          w.polygon([(0, 0), (10000, 0)], 1);
          w.byte(0);
        },
      ));

      expect(result.outlineSketch.strokes.single.points,
          const [Offset(100, -200), Offset(110, -200)]);
      expect(result.sideViewSketch.strokes.single.points,
          const [Offset(0, -300), Offset(10, -300)]);
    });
  });
}
