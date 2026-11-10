import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/views/widgets/station_markers.dart';

/// Paints the stations of [groups], given with their colour, as markers
class _MarkersPainter extends CustomPainter {
  final List<(List<(Point, Offset)>, Color)> groups;
  final Point? selected;

  _MarkersPainter(this.groups, {this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final markers = StationMarkers(size, selected: selected);
    for (final (stations, color) in groups) {
      markers.add(stations, color: color);
    }
    markers.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// What the markers of [groups] paint: the number of dots by ARGB colour,
/// and the number of station IDs
Future<(Map<int, int>, int)> _paint(WidgetTester tester,
    List<(List<(Point, Offset)>, Color)> groups,
    {Point? selected}) async {
  await tester.pumpWidget(CustomPaint(
    painter: _MarkersPainter(groups, selected: selected),
    size: const Size(400, 300),
  ));
  final dots = <int, int>{};
  var labels = 0;
  expect(tester.renderObject(find.byType(CustomPaint)),
      paints..everything((method, arguments) {
    if (method == #drawRawPoints && arguments[0] == PointMode.points) {
      final color = (arguments[2] as Paint).color.toARGB32();
      dots[color] =
          (dots[color] ?? 0) + (arguments[1] as Float32List).length ~/ 2;
    }
    if (method == #drawCircle) {
      final color = (arguments[2] as Paint).color.toARGB32();
      dots[color] = (dots[color] ?? 0) + 1;
    }
    if (method == #drawParagraph) labels++;
    return true;
  }));
  return (dots, labels);
}

void main() {
  const black = Color(0xff000000);
  const red = Color(0xfff44336);

  int dotsOf(Map<int, int> dots, Color color) => dots[color.toARGB32()] ?? 0;

  testWidgets('stations far apart are all drawn with their IDs',
      (tester) async {
    final (dots, labels) = await _paint(tester, [
      ([(const Point(1, 0), const Offset(50, 50)),
        (const Point(1, 1), const Offset(150, 50)),
        (const Point(1, 2), const Offset(250, 50))], black),
    ]);
    expect(dotsOf(dots, black), 3);
    expect(labels, 3);
  });

  testWidgets('of stations crowded together only one is drawn',
      (tester) async {
    final (dots, labels) = await _paint(tester, [
      ([(const Point(1, 0), const Offset(100, 100)),
        (const Point(1, 1), const Offset(101, 100)),
        (const Point(1, 2), const Offset(102, 101))], black),
    ]);
    expect(dotsOf(dots, black), 1);
    expect(labels, 1);
  });

  testWidgets('stations drawn on top take precedence', (tester) async {
    final (dots, _) = await _paint(tester, [
      ([(const Point(1, 0), const Offset(100, 100))], black),
      ([(const Point(2, 0), const Offset(101, 100))], red),
    ]);
    expect(dotsOf(dots, red), 1);
    expect(dotsOf(dots, black), 0);
  });

  testWidgets('IDs that would overlap are left out', (tester) async {
    // The dots are apart, but the IDs are wider than the space between them
    final (dots, labels) = await _paint(tester, [
      ([(const Point(1, 10), const Offset(100, 100)),
        (const Point(1, 11), const Offset(112, 100))], black),
    ]);
    expect(dotsOf(dots, black), 2);
    expect(labels, 1);
  });

  testWidgets('the selected station is always drawn', (tester) async {
    final (dots, labels) = await _paint(tester, [
      ([(const Point(1, 0), const Offset(100, 100)),
        (const Point(1, 1), const Offset(101, 100))], black),
      ([(const Point(2, 0), const Offset(100, 101))], red),
    ], selected: const Point(1, 1));
    expect(dotsOf(dots, Colors.blue), 1);
    expect(dotsOf(dots, black), 0);
    expect(dotsOf(dots, red), 0);
    expect(labels, 1);
  });
}
