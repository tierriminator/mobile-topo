/// Shared drawing and tapping of survey stations in the map and sketch views
library;

import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/settings.dart';
import '../../models/survey.dart';
import 'view_transform.dart';

/// How close a tap must be to a station to select it, in pixels
const _tapRadius = 20.0;

/// The station within tapping distance of [tap], given the stations' world
/// [positions], or null if none is near
Point? stationAt(Map<Point, Offset> positions, Offset tap,
    ViewTransform transform, Size size) {
  for (final entry in positions.entries) {
    final screenPos = transform.worldToScreen(entry.value, size);
    if ((screenPos - tap).distance < _tapRadius) return entry.key;
  }
  return null;
}

/// Where a station's ID is drawn, relative to the station
const _labelOffset = Offset(6, -12);

/// How far a station may lie outside the canvas and still have its ID
/// reach into it
const _labelReach = 100.0;

/// Station IDs laid out for drawing, by ID and whether the station is
/// selected. Laying out the IDs of a large cave for every frame makes
/// panning lag, so they are kept, up to [_maxLabels].
final _labels = <(String, bool), TextPainter>{};
const _maxLabels = 20000;

TextPainter _label(Point id, bool selected) {
  final key = (id.toString(), selected);
  if (_labels[key] case final label?) return label;
  if (_labels.length >= _maxLabels) {
    for (final label in _labels.values) {
      label.dispose();
    }
    _labels.clear();
  }
  return _labels[key] = TextPainter(
    text: TextSpan(
      text: key.$1,
      style: TextStyle(
        color: selected ? Colors.blue : Colors.black87,
        fontSize: 10,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Draws a station as a dot of [radius] in [color] with its ID next to it.
/// A selected station is drawn larger and in blue.
void paintStation(
  Canvas canvas,
  Offset screenPos,
  Point id, {
  required Color color,
  required bool selected,
  double radius = 4,
}) {
  canvas.drawCircle(
    screenPos,
    selected ? radius + 2 : radius,
    Paint()
      ..color = selected ? Colors.blue : color
      ..style = PaintingStyle.fill,
  );
  _label(id, selected).paint(canvas, screenPos + _labelOffset);
}

/// Draws [stations], given by ID and screen position, like [paintStation],
/// all dots in one go and leaving out the stations too far off the canvas
/// of [size] to show. The [selected] station is drawn last, on top.
void paintStations(
  Canvas canvas,
  Size size,
  Iterable<(Point, Offset)> stations, {
  required Color color,
  Point? selected,
  double radius = 4,
}) {
  final area = (Offset.zero & size).inflate(_labelReach);
  final shown = [
    for (final station in stations)
      if (area.contains(station.$2) && station.$1 != selected) station,
  ];
  canvas.drawRawPoints(
    PointMode.points,
    Float32List.fromList([
      for (final (_, position) in shown) ...[position.dx, position.dy],
    ]),
    Paint()
      ..color = color
      ..strokeWidth = 2 * radius
      ..strokeCap = StrokeCap.round,
  );
  for (final (id, position) in shown) {
    _label(id, false).paint(canvas, position + _labelOffset);
  }
  for (final (id, position) in stations) {
    if (id == selected) {
      paintStation(canvas, position, id,
          color: color, selected: true, radius: radius);
    }
  }
}

/// Draws lines between the given pairs of screen positions in one go
void paintLines(Canvas canvas, Iterable<(Offset, Offset)> lines, Paint paint) {
  canvas.drawRawPoints(
    PointMode.lines,
    Float32List.fromList([
      for (final (from, to) in lines) ...[from.dx, from.dy, to.dx, to.dy],
    ]),
    paint,
  );
}

/// Status bar text with a station's ID and coordinates in [unit]
String stationStatus(
        AppLocalizations l10n, StationPosition pos, LengthUnit unit) =>
    l10n.stationStatus(
      pos.id.toString(),
      unit.fromMeters(pos.east).toStringAsFixed(1),
      unit.fromMeters(pos.north).toStringAsFixed(1),
      unit.fromMeters(pos.altitude).toStringAsFixed(1),
      unit.symbol,
    );
