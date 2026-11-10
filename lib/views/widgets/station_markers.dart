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

/// Space kept free between the dots of two stations, in pixels
const _dotGap = 2.0;

/// The station markers of a frame: stations, given by ID and screen
/// position, drawn like [paintStation] once all are added. Zoomed out,
/// stations crowd together, so a station whose dot would overlap one
/// already drawn is left out, as is an ID that would overlap another. The
/// stations added last are drawn on top and so take precedence, the
/// selected station before all others.
class StationMarkers {
  final Size size;
  final Point? selected;
  final _groups = <({
    List<(Point, Offset)> stations,
    Color color,
    double radius,
  })>[];

  StationMarkers(this.size, {this.selected});

  /// Adds [stations] drawn with dots of [radius] in [color]
  void add(Iterable<(Point, Offset)> stations,
      {required Color color, double radius = 4}) {
    _groups.add((stations: stations.toList(), color: color, radius: radius));
  }

  /// Draws the stations, each group's dots in one go, leaving out those too
  /// far off the canvas to show
  void paint(Canvas canvas) {
    final area = (Offset.zero & size).inflate(_labelReach);
    final dots = _Occupied();
    final labels = _Occupied();

    // The selected station from the topmost group it is in
    final selectedGroup = _groups.lastIndexWhere(
        (group) => group.stations.any((station) => station.$1 == selected));
    (Offset, Color, double)? selectedMarker;
    if (selectedGroup >= 0) {
      final group = _groups[selectedGroup];
      final position =
          group.stations.firstWhere((station) => station.$1 == selected).$2;
      selectedMarker = (position, group.color, group.radius);
      dots.add(Rect.fromCircle(center: position, radius: group.radius + 2));
      labels.add(position + _labelOffset & _label(selected!, true).size);
    }

    final shownDots = List.generate(_groups.length, (_) => <Offset>[]);
    final shownLabels = <(Point, Offset)>[];
    for (var g = _groups.length - 1; g >= 0; g--) {
      final group = _groups[g];
      for (final (id, position) in group.stations) {
        if (id == selected || !area.contains(position)) continue;
        final dot = Rect.fromCircle(
            center: position, radius: group.radius + _dotGap / 2);
        if (dots.overlaps(dot)) continue;
        dots.add(dot);
        shownDots[g].add(position);
        final label = position + _labelOffset & _label(id, false).size;
        if (labels.overlaps(label)) continue;
        labels.add(label);
        shownLabels.add((id, position));
      }
    }

    for (var g = 0; g < _groups.length; g++) {
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList([
          for (final position in shownDots[g]) ...[position.dx, position.dy],
        ]),
        Paint()
          ..color = _groups[g].color
          ..strokeWidth = 2 * _groups[g].radius
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final (id, position) in shownLabels) {
      _label(id, false).paint(canvas, position + _labelOffset);
    }
    if (selectedMarker case (final position, final color, final radius)) {
      paintStation(canvas, position, selected!,
          color: color, selected: true, radius: radius);
    }
  }
}

/// Rectangles taken on the canvas, kept in a grid to find overlaps fast
class _Occupied {
  static const _cellSize = 32.0;
  final _cells = <(int, int), List<Rect>>{};

  Iterable<(int, int)> _cellsOf(Rect rect) sync* {
    for (var x = (rect.left / _cellSize).floor();
        x <= (rect.right / _cellSize).floor();
        x++) {
      for (var y = (rect.top / _cellSize).floor();
          y <= (rect.bottom / _cellSize).floor();
          y++) {
        yield (x, y);
      }
    }
  }

  bool overlaps(Rect rect) => _cellsOf(rect)
      .any((cell) => _cells[cell]?.any(rect.overlaps) ?? false);

  void add(Rect rect) {
    for (final cell in _cellsOf(rect)) {
      (_cells[cell] ??= []).add(rect);
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
