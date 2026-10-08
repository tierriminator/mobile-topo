import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';

import '../../models/survey.dart';

/// Pan and zoom state of a view that draws world coordinates in metres with
/// the y axis pointing down, shared by the map and sketch views.
///
/// Transforms are immutable: panning and zooming produce new transforms.
@immutable
class ViewTransform {
  /// Furthest a view can be zoomed out, in pixels per metre. Zooming in is
  /// unlimited.
  static const minScale = 5.0;

  /// Pixels per metre
  final double scale;

  /// Screen position of the world origin, relative to the canvas centre
  final Offset offset;

  const ViewTransform({this.scale = 20.0, this.offset = Offset.zero});

  Offset worldToScreen(Offset world, Size size) =>
      world * scale + offset + size.center(Offset.zero);

  Offset screenToWorld(Offset screen, Size size) =>
      (screen - size.center(Offset.zero) - offset) / scale;

  /// The transform a pinch or pan gesture that started on this transform
  /// leads to: zoomed by [gestureScale] and moved by [focalPointDelta]
  ViewTransform pinched(double gestureScale, Offset focalPointDelta) =>
      ViewTransform(
        scale: math.max(minScale, scale * gestureScale),
        offset: offset + focalPointDelta,
      );

  /// Zoomed by [factor], keeping the world point under [screenPos] in place
  ViewTransform zoomedAt(Offset screenPos, Size size, double factor) {
    final newScale = math.max(minScale, scale * factor);
    final fromCenter = screenPos - size.center(Offset.zero);
    return ViewTransform(
      scale: newScale,
      offset: fromCenter - (fromCenter - offset) * (newScale / scale),
    );
  }

  /// Zoomed by one mouse wheel step towards the cursor
  ViewTransform scrolled(PointerScrollEvent event, Size size) => zoomedAt(
        event.localPosition,
        size,
        event.scrollDelta.dy > 0 ? 0.9 : 1.1,
      );

  /// Moved so the bounding box of [worldPoints] is centred on the canvas;
  /// unchanged if there are no points
  ViewTransform centeredOn(Iterable<Offset> worldPoints) {
    if (worldPoints.isEmpty) return this;
    final bounds = worldPoints
        .map((p) => Rect.fromPoints(p, p))
        .reduce((a, b) => a.expandToInclude(b));
    return ViewTransform(scale: scale, offset: -bounds.center * scale);
  }

  /// The scale as a ratio, assuming 1 mm per pixel. Zoomed in beyond 1:1 the
  /// ratio keeps two significant digits instead of rounding to 0.
  String get scaleLabel {
    final ratio = 1000 / scale;
    return '1:${ratio >= 1 ? ratio.round() : ratio.toStringAsPrecision(2)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ViewTransform && other.scale == scale && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);
}

extension PlanPosition on StationPosition {
  /// The station's position in a plan view: east to the right, north up
  Offset get plan => Offset(east, -north);
}
