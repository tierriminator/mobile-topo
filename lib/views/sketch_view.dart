import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/history.dart';
import '../controllers/selection_state.dart';
import '../data/cave_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/sketch.dart';
import '../models/survey.dart';
import '../services/screen_density.dart';
import 'widgets/view_transform.dart';

enum SketchViewMode { outline, sideView }

class SketchView extends StatefulWidget {
  const SketchView({super.key});

  @override
  State<SketchView> createState() => _SketchViewState();
}

class _SketchViewState extends State<SketchView> {
  Map<Point, StationPosition> _positions = {};
  Map<Point, Offset> _sideViewPositions = {};

  // View mode
  SketchViewMode _viewMode = SketchViewMode.outline;

  // Sketches for each view (from section)
  Sketch _outlineSketch = const Sketch();
  Sketch _sideViewSketch = const Sketch();

  // Undo/redo history for each view
  final History<Sketch> _outlineHistory = History<Sketch>();
  final History<Sketch> _sideViewHistory = History<Sketch>();

  // Drawing state
  SketchMode _sketchMode = SketchMode.move;
  Color _currentColor = SketchColors.black;
  Stroke? _currentStroke;

  // View transformation (separate for each view mode)
  ViewTransform _outlineTransform = const ViewTransform();
  ViewTransform _sideViewTransform = const ViewTransform();

  // Transform and focal point at the start of a pan or pinch gesture
  ViewTransform _gestureStart = const ViewTransform();
  Offset _gestureFocalPoint = Offset.zero;

  // Save lock to prevent concurrent writes
  Future<void>? _pendingSave;

  Size _canvasSize = Size.zero;

  // Track current section to detect changes
  String? _currentSectionId;

  ViewTransform get _transform => _viewMode == SketchViewMode.outline
      ? _outlineTransform
      : _sideViewTransform;
  set _transform(ViewTransform value) {
    if (_viewMode == SketchViewMode.outline) {
      _outlineTransform = value;
    } else {
      _sideViewTransform = value;
    }
  }

  void _updateFromSection(Section? section, Cave? cave) {
    if (section == null) {
      if (_currentSectionId != null) {
        _positions = {};
        _sideViewPositions = {};
        _outlineSketch = const Sketch();
        _sideViewSketch = const Sketch();
        _currentSectionId = null;
      }
      return;
    }

    // Always recompute positions (survey data may have changed). They are
    // computed over the whole cave, so a section without its own reference
    // point is placed relative to the sections it continues from; only the
    // section's own stations are kept.
    final survey = cave?.combinedSurvey ?? section.survey;
    final stations = section.survey.stations;
    _positions = Map.fromEntries(survey
        .computeStationPositions()
        .entries
        .where((e) => stations.contains(e.key)));
    _sideViewPositions = Map.fromEntries(_computeSideViewPositions(survey)
        .entries
        .where((e) => stations.contains(e.key)));

    // Only reset sketches and recenter when switching to a different section
    if (section.id != _currentSectionId) {
      _outlineSketch = section.outlineSketch;
      _sideViewSketch = section.sideViewSketch;
      _outlineHistory.clear();
      _sideViewHistory.clear();
      _currentSectionId = section.id;
      _centerViews();
    }
  }

  void _centerViews() {
    _outlineTransform =
        _outlineTransform.centeredOn(_positions.values.map((p) => p.plan));
    _sideViewTransform =
        _sideViewTransform.centeredOn(_sideViewPositions.values);
  }

  Map<Point, Offset> _computeSideViewPositions(Survey survey) {
    final sidePositions = <Point, Offset>{};
    final visited = <Point>{};

    for (final ref in survey.referencePoints) {
      sidePositions[ref.id] = Offset(0, -ref.altitude.toDouble());
      _buildSideViewFromStation(survey, ref.id, 0, sidePositions, visited);
    }

    return sidePositions;
  }

  void _buildSideViewFromStation(
    Survey survey,
    Point station,
    double horizontalPos,
    Map<Point, Offset> positions,
    Set<Point> visited,
  ) {
    if (visited.contains(station)) return;
    visited.add(station);

    for (final stretch in survey.stretches) {
      Point? nextStation;
      double distance = stretch.distance.toDouble();
      double inclination = stretch.inclination.toDouble();
      bool forward = true;

      // Skip splay shots (no destination)
      final stretchTo = stretch.to;
      if (stretchTo == null) continue;

      if (stretch.from == station && !visited.contains(stretchTo)) {
        nextStation = stretchTo;
      } else if (stretchTo == station && !visited.contains(stretch.from)) {
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
        _buildSideViewFromStation(survey, nextStation, nextHorizPos, positions, visited);
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

  History<Sketch> get _currentHistory =>
      _viewMode == SketchViewMode.outline ? _outlineHistory : _sideViewHistory;

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = _transform;
    _gestureFocalPoint = details.localFocalPoint;

    if (details.pointerCount == 1) {
      if (_sketchMode == SketchMode.draw) {
        final worldPos = _screenToWorld(details.localFocalPoint);
        _currentHistory.record(_currentSketch);
        setState(() {
          _currentStroke = Stroke(
            points: [worldPos],
            color: _currentColor,
          );
        });
      } else if (_sketchMode == SketchMode.erase) {
        _currentHistory.record(_currentSketch);
        _eraseAt(details.localFocalPoint);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_sketchMode == SketchMode.draw && details.pointerCount == 1 && _currentStroke != null) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      setState(() {
        _currentStroke = _currentStroke!.addPoint(worldPos);
      });
    } else if (_sketchMode == SketchMode.erase && details.pointerCount == 1) {
      _eraseAt(details.localFocalPoint);
    } else if (_sketchMode == SketchMode.move || details.pointerCount > 1) {
      setState(() {
        _transform = _gestureStart.pinched(
            details.scale, details.localFocalPoint - _gestureFocalPoint);
      });
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() => _transform = _transform.scrolled(event, _canvasSize));
    }
  }

  void _eraseAt(Offset screenPos) {
    final worldPos = _screenToWorld(screenPos);
    final newSketch = _currentSketch.eraseAt(worldPos, 15 / _transform.scale);
    if (newSketch != null) {
      setState(() {
        _currentSketch = newSketch;
      });
      _saveSketch();
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_currentStroke != null) {
      setState(() {
        _currentSketch = _currentSketch.addStroke(_currentStroke!);
        _currentStroke = null;
      });
      _saveSketch();
    }
  }

  void _saveSketch() {
    // Chain saves to prevent concurrent writes that can corrupt files
    _pendingSave = _pendingSave?.then((_) => _doSave()) ?? _doSave();
  }

  Future<void> _doSave() async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final section = selectionState.selectedSection;
    final caveId = selectionState.selectedCaveId;

    if (section == null || caveId == null) return;

    final updatedSection = section.copyWith(
      outlineSketch: _outlineSketch,
      sideViewSketch: _sideViewSketch,
      modifiedAt: DateTime.now(),
    );

    await repository.saveSection(caveId, updatedSection);
    selectionState.updateSection(updatedSection);
  }

  void _undo() {
    final previousSketch = _currentHistory.undo(_currentSketch);
    if (previousSketch != null) {
      setState(() {
        _currentSketch = previousSketch;
      });
      _saveSketch();
    }
  }

  void _redo() {
    final nextSketch = _currentHistory.redo(_currentSketch);
    if (nextSketch != null) {
      setState(() {
        _currentSketch = nextSketch;
      });
      _saveSketch();
    }
  }

  Offset _screenToWorld(Offset screenPos) =>
      _transform.screenToWorld(screenPos, _canvasSize);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionState = context.watch<SelectionState>();
    final section = selectionState.selectedSection;

    // Update positions when section changes
    _updateFromSection(section, selectionState.selectedCave);

    if (section == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.sketchViewNoSection,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with view mode toggle
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ToggleButtons(
                isSelected: [
                  _viewMode == SketchViewMode.outline,
                  _viewMode == SketchViewMode.sideView,
                ],
                onPressed: (index) {
                  setState(() {
                    _viewMode = index == 0
                        ? SketchViewMode.outline
                        : SketchViewMode.sideView;
                  });
                },
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                borderRadius: BorderRadius.circular(8),
                children: [
                  Tooltip(
                    message: l10n.sketchOutline,
                    child: const Icon(Icons.polyline, size: 20),
                  ),
                  Tooltip(
                    message: l10n.sketchSideView,
                    child: const Icon(Icons.terrain, size: 20),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _currentHistory.canUndo ? _undo : null,
                tooltip: l10n.undo,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _currentHistory.canRedo ? _redo : null,
                tooltip: l10n.redo,
              ),
            ],
          ),
        ),
        // Drawing tools
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              _buildModeButton(
                icon: Icons.pan_tool,
                mode: SketchMode.move,
                tooltip: l10n.sketchModeMove,
              ),
              for (final color in SketchColors.all)
                _buildColorButton(color),
              _buildModeButton(
                icon: Icons.cleaning_services,
                mode: SketchMode.erase,
                tooltip: l10n.sketchModeErase,
              ),
            ],
          ),
        ),
        // Canvas
        Expanded(
          child: _positions.isEmpty
              ? Center(
                  child: Text(
                    l10n.sketchViewNoData,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return Listener(
                      onPointerSignal: _onPointerSignal,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _SketchPainter(
                              survey: section.survey,
                              stationPositions: _viewMode == SketchViewMode.outline
                                  ? _positions.map((k, v) => MapEntry(k, v.plan))
                                  : _sideViewPositions,
                              sketch: _currentSketch,
                              currentStroke: _currentStroke,
                              transform: _transform,
                              isOutlineView: _viewMode == SketchViewMode.outline,
                            ),
                            size: Size.infinite,
                          ),
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
                l10n.sketchScale(_transform.scaleLabel(
                    context.watch<ScreenDensity>().logicalPixelsPerMm)),
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
    // Use light outline for dark colors, dark outline for light colors
    final isDark = color.computeLuminance() < 0.5;
    final selectedBorderColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sketchMode = SketchMode.draw;
          _currentColor = color;
        });
      },
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? selectedBorderColor : Colors.grey.shade400,
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
  final ViewTransform transform;
  final bool isOutlineView;

  _SketchPainter({
    required this.survey,
    required this.stationPositions,
    required this.sketch,
    this.currentStroke,
    required this.transform,
    required this.isOutlineView,
  });

  Offset _worldToScreen(Offset worldPos, Size size) =>
      transform.worldToScreen(worldPos, size);

  /// Calculate splay shot endpoint in world coordinates
  Offset _calculateSplayEndpoint(Offset from, MeasuredDistance stretch) {
    final azimuthRad = stretch.azimut.toDouble() * math.pi / 180.0;
    final inclinationRad = stretch.inclination.toDouble() * math.pi / 180.0;
    final distance = stretch.distance.toDouble();

    // Horizontal distance (plan view) and vertical distance
    final horizDist = distance * math.cos(inclinationRad);
    final vertDist = distance * math.sin(inclinationRad);

    if (isOutlineView) {
      // Plan view: X is east, Y is -north
      // Azimuth 0 = north (negative Y), 90 = east (positive X)
      final eastOffset = horizDist * math.sin(azimuthRad);
      final northOffset = horizDist * math.cos(azimuthRad);
      return Offset(from.dx + eastOffset, from.dy - northOffset);
    } else {
      // Side view: X is horizontal distance, Y is -altitude
      // Show splay extending horizontally with altitude change
      return Offset(from.dx + horizDist, from.dy - vertDist);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shotPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final splayPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final stationPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (final stretch in survey.stretches) {
      final fromPos = stationPositions[stretch.from];

      if (stretch.to != null) {
        // Survey shot - draw line to destination station
        final toPos = stationPositions[stretch.to];
        if (fromPos != null && toPos != null) {
          final from = _worldToScreen(fromPos, size);
          final to = _worldToScreen(toPos, size);
          canvas.drawLine(from, to, shotPaint);
        }
      } else if (fromPos != null) {
        // Splay shot - calculate endpoint from measurement
        final splayEnd = _calculateSplayEndpoint(fromPos, stretch);
        final from = _worldToScreen(fromPos, size);
        final to = _worldToScreen(splayEnd, size);
        canvas.drawLine(from, to, splayPaint);
      }
    }

    for (final entry in stationPositions.entries) {
      final screenPos = _worldToScreen(entry.value, size);
      canvas.drawCircle(screenPos, 3, stationPaint);
    }

    for (final stroke in sketch.strokes) {
      _drawStroke(canvas, size, stroke);
    }

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
    return oldDelegate.transform != transform ||
        oldDelegate.sketch != sketch ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.isOutlineView != isOutlineView ||
        oldDelegate.survey != survey ||
        oldDelegate.stationPositions != stationPositions;
  }
}
