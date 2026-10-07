import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/selection_state.dart';
import '../l10n/app_localizations.dart';
import '../models/survey.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  Map<Point, StationPosition> _positions = {};

  // View transformation
  double _scale = 20.0; // pixels per meter
  Offset _offset = Offset.zero;

  // For gesture handling
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  // Selected station
  Point? _selectedStation;

  // Store the canvas size for tap detection
  Size _canvasSize = Size.zero;

  // Track current section to detect changes
  String? _currentSectionId;

  void _updateFromSection(String? sectionId, Survey? caveSurvey,
      Set<Point> sectionStations) {
    if (sectionId == null || caveSurvey == null) {
      if (_currentSectionId != null) {
        _positions = {};
        _currentSectionId = null;
      }
      return;
    }

    // Always recompute positions (survey data may have changed)
    _positions = caveSurvey.computeStationPositions();

    // Only recenter when switching to a different section
    if (sectionId != _currentSectionId) {
      _currentSectionId = sectionId;
      _centerView(sectionStations);
    }
  }

  /// Centers on the selected section, or on the whole cave if none of the
  /// section's stations have a position.
  void _centerView(Set<Point> sectionStations) {
    if (_positions.isEmpty) return;

    var centerOn = [
      for (final station in sectionStations)
        if (_positions[station] case final pos?) pos,
    ];
    if (centerOn.isEmpty) centerOn = _positions.values.toList();

    // Compute bounds
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final pos in centerOn) {
      if (pos.east < minX) minX = pos.east;
      if (-pos.north < minY) minY = -pos.north;
      if (pos.east > maxX) maxX = pos.east;
      if (-pos.north > maxY) maxY = -pos.north;
    }

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    _offset = Offset(-centerX * _scale, -centerY * _scale);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(5.0, 200.0);
      final focalPointDelta = details.focalPoint - _startFocalPoint;
      _offset = _startOffset + focalPointDelta;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      final newScale = (_scale * zoomFactor).clamp(5.0, 200.0);

      if (newScale != _scale) {
        // Zoom towards cursor position
        final cursorPos = event.localPosition;
        final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
        final cursorFromCenter = cursorPos - center;

        setState(() {
          // Adjust offset to keep cursor position stable
          _offset = cursorFromCenter - (cursorFromCenter - _offset) * (newScale / _scale);
          _scale = newScale;
        });
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final tapPos = details.localPosition;

    for (final entry in _positions.entries) {
      final station = entry.value;
      final screenPos = _worldToScreen(station.east, station.north, _canvasSize);

      if ((screenPos - tapPos).distance < 20) {
        setState(() {
          _selectedStation = entry.key;
        });
        return;
      }
    }

    setState(() {
      _selectedStation = null;
    });
  }

  Offset _worldToScreen(double east, double north, Size size) {
    return Offset(
      east * _scale + _offset.dx + size.width / 2,
      -north * _scale + _offset.dy + size.height / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionState = context.watch<SelectionState>();
    final section = selectionState.selectedSection;
    final cave = selectionState.selectedCave;
    final caveSurvey = cave?.combinedSurvey;
    final sectionStations = section?.survey.stations ?? const <Point>{};

    // Update positions when section changes
    _updateFromSection(section?.id, caveSurvey, sectionStations);

    if (section == null || caveSurvey == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.mapViewNoSection,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    final depth = caveSurvey.computeDepth(_positions);
    final length = caveSurvey.totalLength;

    String statusText;
    if (_selectedStation != null && _positions.containsKey(_selectedStation)) {
      final pos = _positions[_selectedStation]!;
      statusText = l10n.mapStatusStation(
        _selectedStation.toString(),
        pos.east.toStringAsFixed(1),
        pos.north.toStringAsFixed(1),
        pos.altitude.toStringAsFixed(1),
      );
    } else {
      statusText = l10n.mapStatusOverview(
        length.toStringAsFixed(1),
        depth.toStringAsFixed(1),
        '1:${(1000 / _scale).round()}',
      );
    }

    return Column(
      children: [
        // Section name header
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.description, size: 20),
              const SizedBox(width: 8),
              Text(
                section.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: _positions.isEmpty
              ? Center(
                  child: Text(
                    l10n.mapViewNoData,
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
                        onTapUp: _handleTapUp,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _MapPainter(
                              caveSurvey: caveSurvey,
                              sectionSurvey: section.survey,
                              sectionStations: sectionStations,
                              positions: _positions,
                              scale: _scale,
                              offset: _offset,
                              selectedStation: _selectedStation,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws the whole cave in black, with the selected section in red on top.
class _MapPainter extends CustomPainter {
  final Survey caveSurvey;
  final Survey sectionSurvey;
  final Set<Point> sectionStations;
  final Map<Point, StationPosition> positions;
  final double scale;
  final Offset offset;
  final Point? selectedStation;

  _MapPainter({
    required this.caveSurvey,
    required this.sectionSurvey,
    required this.sectionStations,
    required this.positions,
    required this.scale,
    required this.offset,
    this.selectedStation,
  });

  Offset _worldToScreen(double east, double north, Size size) {
    return Offset(
      east * scale + offset.dx + size.width / 2,
      -north * scale + offset.dy + size.height / 2,
    );
  }

  void _drawStretches(
      Canvas canvas, Size size, Iterable<MeasuredDistance> stretches, Paint paint) {
    for (final stretch in stretches) {
      final fromPos = positions[stretch.from];
      final toPos = positions[stretch.to];

      if (fromPos != null && toPos != null) {
        final from = _worldToScreen(fromPos.east, fromPos.north, size);
        final to = _worldToScreen(toPos.east, toPos.north, size);
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final caveLinePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final sectionLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final caveStationPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final sectionStationPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final selectedPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw survey shots: the rest of the cave first, the section on top
    final sectionStretches = Set<MeasuredDistance>.identity()
      ..addAll(sectionSurvey.stretches);
    _drawStretches(
      canvas,
      size,
      caveSurvey.stretches.where((s) => !sectionStretches.contains(s)),
      caveLinePaint,
    );
    _drawStretches(canvas, size, sectionSurvey.stretches, sectionLinePaint);

    // Draw stations, again with the section's stations on top
    final orderedStations = positions.entries.toList()
      ..sort((a, b) {
        final aInSection = sectionStations.contains(a.key) ? 1 : 0;
        final bInSection = sectionStations.contains(b.key) ? 1 : 0;
        return aInSection - bInSection;
      });
    for (final entry in orderedStations) {
      final pos = entry.value;
      final screenPos = _worldToScreen(pos.east, pos.north, size);

      final isSelected = entry.key == selectedStation;
      final paint = isSelected
          ? selectedPaint
          : sectionStations.contains(entry.key)
              ? sectionStationPaint
              : caveStationPaint;
      final radius = isSelected ? 6.0 : 4.0;

      canvas.drawCircle(screenPos, radius, paint);
    }

    // Draw station labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final entry in positions.entries) {
      final pos = entry.value;
      final screenPos = _worldToScreen(pos.east, pos.north, size);

      textPainter.text = TextSpan(
        text: entry.key.toString(),
        style: TextStyle(
          color: entry.key == selectedStation ? Colors.blue : Colors.black87,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, screenPos + const Offset(6, -12));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.selectedStation != selectedStation ||
        oldDelegate.positions != positions ||
        oldDelegate.sectionSurvey != sectionSurvey;
  }
}
