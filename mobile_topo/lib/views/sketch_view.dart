import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../sketching.dart';
import '../topo.dart';

enum SketchViewMode { outline, sideView }

class SketchView extends StatefulWidget {
  const SketchView({super.key});

  @override
  State<SketchView> createState() => _SketchViewState();
}

class _SketchViewState extends State<SketchView> {
  // Placeholder survey data - will be replaced with actual data management
  final Survey _survey = const Survey(
    stretches: [
      MeasuredDistance(Point(1, 0), Point(1, 1), 5.0, 45.0, -10.0),
      MeasuredDistance(Point(1, 1), Point(1, 2), 4.0, 90.0, 5.0),
      MeasuredDistance(Point(1, 2), Point(1, 3), 6.0, 120.0, -5.0),
      MeasuredDistance(Point(1, 3), Point(1, 4), 3.5, 180.0, 0.0),
      MeasuredDistance(Point(1, 2), Point(2, 0), 4.5, 30.0, -15.0),
      MeasuredDistance(Point(2, 0), Point(2, 1), 5.5, 60.0, -10.0),
    ],
    referencePoints: [
      ReferencePoint(Point(1, 0), 0.0, 0.0, 100.0),
    ],
  );

  late Map<Point, StationPosition> _positions;
  late Map<Point, Offset> _sideViewPositions;

  // View mode
  SketchViewMode _viewMode = SketchViewMode.outline;

  // Sketches for each view
  Sketch _outlineSketch = const Sketch();
  Sketch _sideViewSketch = const Sketch();

  // Undo stacks
  final List<Sketch> _outlineUndoStack = [];
  final List<Sketch> _sideViewUndoStack = [];

  // Drawing state
  SketchMode _sketchMode = SketchMode.move;
  Color _currentColor = SketchColors.black;
  Stroke? _currentStroke;

  // View transformation (separate for each view mode)
  double _outlineScale = 20.0;
  Offset _outlineOffset = Offset.zero;
  double _sideViewScale = 20.0;
  Offset _sideViewOffset = Offset.zero;

  double get _scale => _viewMode == SketchViewMode.outline ? _outlineScale : _sideViewScale;
  set _scale(double value) {
    if (_viewMode == SketchViewMode.outline) {
      _outlineScale = value;
    } else {
      _sideViewScale = value;
    }
  }

  Offset get _offset => _viewMode == SketchViewMode.outline ? _outlineOffset : _sideViewOffset;
  set _offset(Offset value) {
    if (_viewMode == SketchViewMode.outline) {
      _outlineOffset = value;
    } else {
      _sideViewOffset = value;
    }
  }

  // Gesture handling
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _positions = _survey.computeStationPositions();
    _sideViewPositions = _computeSideViewPositions();
    _centerViews();
  }

  /// Center both views on their data
  void _centerViews() {
    // Center outline view
    final outlineBounds = _computeBounds(
      _positions.values.map((p) => Offset(p.east, -p.north)).toList(),
    );
    if (outlineBounds != null) {
      _outlineOffset = -outlineBounds.center * _outlineScale;
    }

    // Center side view
    final sideBounds = _computeBounds(_sideViewPositions.values.toList());
    if (sideBounds != null) {
      _sideViewOffset = -sideBounds.center * _sideViewScale;
    }
  }

  Rect? _computeBounds(List<Offset> points) {
    if (points.isEmpty) return null;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Compute positions for side view (developed profile)
  Map<Point, Offset> _computeSideViewPositions() {
    final sidePositions = <Point, Offset>{};
    final visited = <Point>{};

    // Start from reference points
    for (final ref in _survey.referencePoints) {
      sidePositions[ref.id] = Offset(0, -ref.altitude.toDouble());
      _buildSideViewFromStation(ref.id, 0, sidePositions, visited);
    }

    return sidePositions;
  }

  void _buildSideViewFromStation(
    Point station,
    double horizontalPos,
    Map<Point, Offset> positions,
    Set<Point> visited,
  ) {
    if (visited.contains(station)) return;
    visited.add(station);

    for (final stretch in _survey.stretches) {
      Point? nextStation;
      double distance = stretch.distance.toDouble();
      double inclination = stretch.inclination.toDouble();
      bool forward = true;

      if (stretch.from == station && !visited.contains(stretch.to)) {
        nextStation = stretch.to;
      } else if (stretch.to == station && !visited.contains(stretch.from)) {
        nextStation = stretch.from;
        forward = false;
      }

      if (nextStation != null) {
        final inclinationRad = inclination * math.pi / 180.0;
        final horizDist = distance * math.cos(inclinationRad);
        final vertDist = distance * math.sin(inclinationRad);

        final currentPos = positions[station]!;
        final sign = forward ? 1.0 : -1.0;
        final nextHorizPos = currentPos.dx + sign * horizDist;
        final nextVertPos = currentPos.dy - sign * vertDist;

        positions[nextStation] = Offset(nextHorizPos, nextVertPos);
        _buildSideViewFromStation(nextStation, nextHorizPos, positions, visited);
      }
    }
  }

  Sketch get _currentSketch =>
      _viewMode == SketchViewMode.outline ? _outlineSketch : _sideViewSketch;

  set _currentSketch(Sketch sketch) {
    if (_viewMode == SketchViewMode.outline) {
      _outlineSketch = sketch;
    } else {
      _sideViewSketch = sketch;
    }
  }

  List<Sketch> get _currentUndoStack =>
      _viewMode == SketchViewMode.outline ? _outlineUndoStack : _sideViewUndoStack;

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocalPoint = details.localFocalPoint;

    if (details.pointerCount == 1) {
      if (_sketchMode == SketchMode.draw) {
        // Start drawing
        final worldPos = _screenToWorld(details.localFocalPoint);
        setState(() {
          _currentUndoStack.add(_currentSketch);
          _currentStroke = Stroke(
            points: [worldPos],
            color: _currentColor,
          );
        });
      } else if (_sketchMode == SketchMode.erase) {
        // Save state for undo before erasing
        _currentUndoStack.add(_currentSketch);
        _eraseAt(details.localFocalPoint);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_sketchMode == SketchMode.draw && details.pointerCount == 1 && _currentStroke != null) {
      // Continue drawing
      final worldPos = _screenToWorld(details.localFocalPoint);
      setState(() {
        _currentStroke = _currentStroke!.addPoint(worldPos);
      });
    } else if (_sketchMode == SketchMode.erase && details.pointerCount == 1) {
      // Continue erasing while dragging
      _eraseAt(details.localFocalPoint);
    } else if (_sketchMode == SketchMode.move || details.pointerCount > 1) {
      // Pan/zoom
      setState(() {
        _scale = (_startScale * details.scale).clamp(5.0, 200.0);
        final focalPointDelta = details.localFocalPoint - _startFocalPoint;
        _offset = _startOffset + focalPointDelta;
      });
    }
  }

  void _eraseAt(Offset screenPos) {
    final worldPos = _screenToWorld(screenPos);
    final newSketch = _currentSketch.eraseAt(worldPos, 15 / _scale);
    if (newSketch != null) {
      setState(() {
        _currentSketch = newSketch;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // End drawing if there's a stroke in progress
    if (_currentStroke != null) {
      setState(() {
        _currentSketch = _currentSketch.addStroke(_currentStroke!);
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_currentUndoStack.isNotEmpty) {
      setState(() {
        _currentSketch = _currentUndoStack.removeLast();
      });
    }
  }

  Offset _screenToWorld(Offset screenPos) {
    return Offset(
      (screenPos.dx - _canvasSize.width / 2 - _offset.dx) / _scale,
      (screenPos.dy - _canvasSize.height / 2 - _offset.dy) / _scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // View mode toggle and tools
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // View mode toggle
              SegmentedButton<SketchViewMode>(
                segments: [
                  ButtonSegment(
                    value: SketchViewMode.outline,
                    label: Text(l10n.sketchOutline),
                  ),
                  ButtonSegment(
                    value: SketchViewMode.sideView,
                    label: Text(l10n.sketchSideView),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _viewMode = selection.first;
                  });
                },
              ),
              const Spacer(),
              // Undo button
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _currentUndoStack.isNotEmpty ? _undo : null,
                tooltip: l10n.undo,
              ),
            ],
          ),
        ),
        // Drawing tools
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Move mode
              _buildModeButton(
                icon: Icons.pan_tool,
                mode: SketchMode.move,
                tooltip: l10n.sketchModeMove,
              ),
              const SizedBox(width: 8),
              // Color buttons
              for (final color in SketchColors.all)
                _buildColorButton(color),
              const SizedBox(width: 8),
              // Eraser
              _buildModeButton(
                icon: Icons.auto_fix_high,
                mode: SketchMode.erase,
                tooltip: l10n.sketchModeErase,
              ),
            ],
          ),
        ),
        // Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _SketchPainter(
                      survey: _survey,
                      stationPositions: _viewMode == SketchViewMode.outline
                          ? _positions.map((k, v) => MapEntry(k, Offset(v.east, -v.north)))
                          : _sideViewPositions,
                      sketch: _currentSketch,
                      currentStroke: _currentStroke,
                      scale: _scale,
                      offset: _offset,
                      isOutlineView: _viewMode == SketchViewMode.outline,
                    ),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
        // Status bar
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                l10n.sketchScale('1:${(1000 / _scale).round()}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required SketchMode mode,
    required String tooltip,
  }) {
    final isSelected = _sketchMode == mode;
    return IconButton(
      icon: Icon(icon),
      onPressed: () {
        setState(() {
          _sketchMode = mode;
        });
      },
      tooltip: tooltip,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _sketchMode == SketchMode.draw && _currentColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sketchMode = SketchMode.draw;
          _currentColor = color;
        });
      },
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final Survey survey;
  final Map<Point, Offset> stationPositions;
  final Sketch sketch;
  final Stroke? currentStroke;
  final double scale;
  final Offset offset;
  final bool isOutlineView;

  _SketchPainter({
    required this.survey,
    required this.stationPositions,
    required this.sketch,
    this.currentStroke,
    required this.scale,
    required this.offset,
    required this.isOutlineView,
  });

  Offset _worldToScreen(Offset worldPos, Size size) {
    return Offset(
      worldPos.dx * scale + offset.dx + size.width / 2,
      worldPos.dy * scale + offset.dy + size.height / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw survey shots
    final shotPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final stationPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (final stretch in survey.stretches) {
      final fromPos = stationPositions[stretch.from];
      final toPos = stationPositions[stretch.to];

      if (fromPos != null && toPos != null) {
        final from = _worldToScreen(fromPos, size);
        final to = _worldToScreen(toPos, size);
        canvas.drawLine(from, to, shotPaint);
      }
    }

    // Draw stations
    for (final entry in stationPositions.entries) {
      final screenPos = _worldToScreen(entry.value, size);
      canvas.drawCircle(screenPos, 3, stationPaint);
    }

    // Draw sketched strokes
    for (final stroke in sketch.strokes) {
      _drawStroke(canvas, size, stroke);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, size, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Size size, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final firstPoint = _worldToScreen(stroke.points.first, size);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      final point = _worldToScreen(stroke.points[i], size);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.sketch != sketch ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.isOutlineView != isOutlineView;
  }
}
