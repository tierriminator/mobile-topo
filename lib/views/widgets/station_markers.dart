/// Shared drawing and tapping of survey stations in the map and sketch views
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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

  final textPainter = TextPainter(
    text: TextSpan(
      text: id.toString(),
      style: TextStyle(
        color: selected ? Colors.blue : Colors.black87,
        fontSize: 10,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(canvas, screenPos + const Offset(6, -12));
}

/// Status bar text with a station's ID and coordinates
String stationStatus(AppLocalizations l10n, StationPosition pos) =>
    l10n.stationStatus(
      pos.id.toString(),
      pos.east.toStringAsFixed(1),
      pos.north.toStringAsFixed(1),
      pos.altitude.toStringAsFixed(1),
    );
