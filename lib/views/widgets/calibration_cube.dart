import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/calibration.dart';

/// Colors shared by the calibration shot drawings.
abstract final class CalibrationShotColors {
  /// The direction or roll being shot next.
  static const Color current = Color(0xFFFFC107);

  /// Outline that keeps [current] visible on light backgrounds.
  static const Color currentOutline = Color(0xFF8D6E00);

  /// Directions or rolls already shot.
  static const Color done = Color(0xFF43A047);
}

/// A cube around the person calibrating, with an arrow for each calibration
/// direction that is shot or being shot.
///
/// The person stands at the center point and faces "Forward". The view starts
/// from behind, to the right of and above them, so that the forward, up and
/// down arrows do not overlap, and dragging over the cube rotates it. The
/// current arrow gets guide lines down to the shaded eye level plane,
/// separating its bearing from its inclination.
class CalibrationCube extends StatefulWidget {
  /// Direction (index into [CalibrationPositions.relativeDirections]) of the
  /// next shot, drawn in [CalibrationShotColors.current].
  final int? currentDirection;

  /// Directions whose four shots are all taken.
  final Set<int> completedDirections;

  /// Labels for the forward, right, back and left faces.
  final List<String> faceLabels;

  const CalibrationCube({
    super.key,
    required this.currentDirection,
    required this.completedDirections,
    required this.faceLabels,
  });

  @override
  State<CalibrationCube> createState() => _CalibrationCubeState();
}

class _CalibrationCubeState extends State<CalibrationCube> {
  /// How far the viewer is to the right of straight behind the person, in
  /// degrees.
  double _yaw = 35;

  /// How far the viewer is above eye level, in degrees.
  double _elevation = 30;

  /// Rotation per pixel dragged, in degrees.
  static const double _dragSensitivity = 0.5;

  /// Elevation limit, short of straight above or below, where the screen's
  /// up direction is undefined.
  static const double _maxElevation = 85;

  void _onDrag(DragUpdateDetails details) {
    setState(() {
      // The scene follows the finger: dragging right turns the viewer left.
      _yaw = (_yaw - details.delta.dx * _dragSensitivity) % 360;
      _elevation = (_elevation + details.delta.dy * _dragSensitivity)
          .clamp(-_maxElevation, _maxElevation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanUpdate: _onDrag,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CubePainter(
          yaw: _yaw,
          elevation: _elevation,
          currentDirection: widget.currentDirection,
          completedDirections: widget.completedDirections,
          faceLabels: widget.faceLabels,
          edgeColor: scheme.outline.withValues(alpha: 0.45),
          labelColor: scheme.outline,
          centerColor: scheme.onSurface,
          centerRingColor: scheme.surface,
        ),
      ),
    );
  }
}

/// A point of the scene after projection: screen offset in unit space and
/// distance from the viewer along the viewing direction.
typedef _Projected = ({Offset offset, double depth});

class _CubePainter extends CustomPainter {
  final double yaw;
  final double elevation;
  final int? currentDirection;
  final Set<int> completedDirections;
  final List<String> faceLabels;
  final Color edgeColor;
  final Color labelColor;
  final Color centerColor;
  final Color centerRingColor;

  // Scene axes: x right, y forward, z up, cube from -1 to 1.

  /// [yaw] is how far the viewer is to the right of straight behind the
  /// person and [elevation] how far above eye level, both in degrees.
  _CubePainter({
    required this.yaw,
    required this.elevation,
    required this.currentDirection,
    required this.completedDirections,
    required this.faceLabels,
    required this.edgeColor,
    required this.labelColor,
    required this.centerColor,
    required this.centerRingColor,
  });

  /// Viewing direction, from the viewer towards the cube center.
  late final vm.Vector3 _viewDir = vm.Vector3(
    -math.sin(yaw * math.pi / 180) * math.cos(elevation * math.pi / 180),
    math.cos(yaw * math.pi / 180) * math.cos(elevation * math.pi / 180),
    -math.sin(elevation * math.pi / 180),
  );
  late final vm.Vector3 _screenRight =
      _viewDir.cross(vm.Vector3(0, 0, 1))..normalize();
  late final vm.Vector3 _screenUp = _screenRight.cross(_viewDir);

  /// Viewer distance from the cube center, in half cube widths.
  static const double _viewDistance = 6.0;

  _Projected _project(vm.Vector3 p) {
    final depth = p.dot(_viewDir);
    final k = _viewDistance / (_viewDistance + depth);
    return (
      offset: Offset(p.dot(_screenRight) * k, -p.dot(_screenUp) * k),
      depth: depth,
    );
  }

  /// Point where the ray from the center in [direction] leaves the cube.
  static vm.Vector3 _tip(int direction) {
    final (bearing, inclination) =
        CalibrationPositions.relativeDirections[direction];
    final b = bearing * math.pi / 180;
    final i = inclination * math.pi / 180;
    final v = vm.Vector3(
      math.sin(b) * math.cos(i),
      math.cos(b) * math.cos(i),
      math.sin(i),
    );
    final reach = math.max(v.x.abs(), math.max(v.y.abs(), v.z.abs()));
    return v.scaled(1 / reach);
  }

  static final List<vm.Vector3> _corners = [
    for (int i = 0; i < 8; i++)
      vm.Vector3(
        i & 1 == 0 ? -1 : 1,
        i & 2 == 0 ? -1 : 1,
        i & 4 == 0 ? -1 : 1,
      ),
  ];

  /// Corner index pairs that differ in exactly one coordinate.
  static final List<(int, int)> _edges = [
    for (int i = 0; i < 8; i++)
      for (final bit in const [1, 2, 4])
        if (i & bit == 0) (i, i | bit),
  ];

  static final List<vm.Vector3> _faceCenters = [
    vm.Vector3(0, 1, 0), // forward
    vm.Vector3(1, 0, 0), // right
    vm.Vector3(0, -1, 0), // back
    vm.Vector3(-1, 0, 0), // left
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the cube's bounding sphere into the available space, so the size
    // stays the same while rotating.
    final corners = _corners.map(_project).toList();
    final scale = 0.42 * size.shortestSide / math.sqrt(3);
    final origin = size.center(Offset.zero);
    Offset toScreen(_Projected p) => origin + p.offset * scale;

    // Eye level plane, which the horizontal directions lie in
    final eyeLevel = [
      for (final (x, y) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
        toScreen(_project(vm.Vector3(x.toDouble(), y.toDouble(), 0))),
    ];
    canvas.drawPath(
      Path()..addPolygon(eyeLevel, true),
      Paint()..color = edgeColor.withValues(alpha: 0.08),
    );

    // Cube outline
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.2;
    for (final (a, b) in _edges) {
      _dashedLine(canvas, toScreen(corners[a]), toScreen(corners[b]), edgePaint);
    }

    // Face labels, just outside the horizontal faces
    for (int f = 0; f < _faceCenters.length && f < faceLabels.length; f++) {
      final at = toScreen(_project(_faceCenters[f].scaled(1.3)));
      final text = TextPainter(
        text: TextSpan(
          text: faceLabels[f],
          style: TextStyle(color: labelColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }

    final center = toScreen(_project(vm.Vector3.zero()));
    final headLength = scale * 0.22;

    // Completed directions, far ones first and fainter
    final completed = completedDirections
        .where((d) => d != currentDirection)
        .map((d) => (direction: d, tip: _project(_tip(d))))
        .toList()
      ..sort((a, b) => b.tip.depth.compareTo(a.tip.depth));
    for (final (direction: _, tip: tip) in completed) {
      final nearness = (1 - tip.depth / math.sqrt(3)) / 2; // 0 far .. 1 near
      _arrow(
        canvas,
        center,
        toScreen(tip),
        CalibrationShotColors.done.withValues(alpha: 0.45 + 0.55 * nearness),
        width: 2.5,
        headLength: headLength * 0.8,
      );
    }

    // Current direction, outlined so it stands out
    final current = currentDirection;
    if (current != null) {
      final tip3 = _tip(current);
      final tip = toScreen(_project(tip3));

      // Bearing on the eye level plane, and the rise or drop from it
      if (tip3.z.abs() > 1e-6) {
        final foot = toScreen(_project(vm.Vector3(tip3.x, tip3.y, 0)));
        final guidePaint = Paint()
          ..color = CalibrationShotColors.currentOutline
          ..strokeWidth = 1.5;
        _dashedLine(canvas, center, foot, guidePaint);
        _dashedLine(canvas, foot, tip, guidePaint);
      }

      _arrow(canvas, center, tip, CalibrationShotColors.currentOutline,
          width: 7, headLength: headLength, outline: 1.5);
      _arrow(canvas, center, tip, CalibrationShotColors.current,
          width: 4.5, headLength: headLength);
    }

    // The person calibrating
    canvas.drawCircle(center, 8, Paint()..color = centerRingColor);
    canvas.drawCircle(center, 6, Paint()..color = centerColor);
  }

  static void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0, gap = 4.0;
    final length = (b - a).distance;
    if (length == 0) return;
    final step = (b - a) / length;
    for (double s = 0; s < length; s += dash + gap) {
      canvas.drawLine(a + step * s, a + step * math.min(s + dash, length), paint);
    }
  }

  /// Arrow from [from] to [to]. [outline] widens the head by that many
  /// pixels on each side, for drawing an outline underneath another arrow.
  static void _arrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    required double width,
    required double headLength,
    double outline = 0,
  }) {
    final length = (to - from).distance;
    if (length < 1) return;
    final along = (to - from) / length;
    final across = Offset(-along.dy, along.dx);
    final head = math.min(headLength, length * 0.6);
    final base = to - along * head;
    final halfWidth = head * 0.45 + outline;

    canvas.drawLine(
      from,
      base,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    final tipPoint = to + along * outline * 2;
    final backPoint = base - along * outline;
    canvas.drawPath(
      Path()
        ..moveTo(tipPoint.dx, tipPoint.dy)
        ..lineTo((backPoint + across * halfWidth).dx,
            (backPoint + across * halfWidth).dy)
        ..lineTo((backPoint - across * halfWidth).dx,
            (backPoint - across * halfWidth).dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CubePainter old) =>
      old.yaw != yaw ||
      old.elevation != elevation ||
      old.currentDirection != currentDirection ||
      !setEquals(old.completedDirections, completedDirections) ||
      !listEquals(old.faceLabels, faceLabels) ||
      old.edgeColor != edgeColor ||
      old.labelColor != labelColor ||
      old.centerColor != centerColor ||
      old.centerRingColor != centerRingColor;
}

/// Cross section of the device as the person aiming it sees it from behind,
/// rotated so its display faces the side given by [rollIndex] (0 up, 1 right,
/// 2 down, 3 left).
class DeviceRollIndicator extends StatelessWidget {
  final int rollIndex;
  final double size;

  const DeviceRollIndicator({
    super.key,
    required this.rollIndex,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _DevicePainter(
        rollIndex: rollIndex,
        bodyColor: scheme.onSurface,
        laserColor: Colors.red,
      ),
    );
  }
}

class _DevicePainter extends CustomPainter {
  final int rollIndex;
  final Color bodyColor;
  final Color laserColor;

  _DevicePainter({
    required this.rollIndex,
    required this.bodyColor,
    required this.laserColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    // Screen y points down, so a positive rotation turns the display from
    // up towards the right.
    canvas.rotate(rollIndex * math.pi / 2);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.8, height: s * 0.42),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Display on the top face
    final display = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.21),
        width: s * 0.56,
        height: s * 0.12,
      ),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(display, Paint()..color = CalibrationShotColors.current);
    canvas.drawRRect(
      display,
      Paint()
        ..color = CalibrationShotColors.currentOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Laser exit, pointing away from the viewer
    canvas.drawCircle(Offset(0, s * 0.03), s * 0.05, Paint()..color = laserColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_DevicePainter old) =>
      old.rollIndex != rollIndex ||
      old.bodyColor != bodyColor ||
      old.laserColor != laserColor;
}
