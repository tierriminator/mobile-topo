import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/selection_state.dart';
import '../l10n/app_localizations.dart';
import '../models/survey.dart';
import '../services/screen_density.dart';
import 'widgets/view_transform.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  Map<Point, StationPosition> _positions = {};

  ViewTransform _transform = const ViewTransform();

  // Transform and focal point at the start of a pan or pinch gesture
  ViewTransform _gestureStart = const ViewTransform();
  Offset _gestureFocalPoint = Offset.zero;

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
    final sectionPositions = [
      for (final station in sectionStations)
        if (_positions[station] case final pos?) pos.plan,
    ];
    _transform = _transform.centeredOn(sectionPositions.isNotEmpty
        ? sectionPositions
        : _positions.values.map((p) => p.plan));
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = _transform;
    _gestureFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _transform = _gestureStart.pinched(
          details.scale, details.localFocalPoint - _gestureFocalPoint);
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() => _transform = _transform.scrolled(event, _canvasSize));
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final tapPos = details.localPosition;

    for (final entry in _positions.entries) {
      final screenPos =
          _transform.worldToScreen(entry.value.plan, _canvasSize);

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
        _transform.scaleLabel(
            context.watch<ScreenDensity>().logicalPixelsPerMm),
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
                              transform: _transform,
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
  final ViewTransform transform;
  final Point? selectedStation;

  _MapPainter({
    required this.caveSurvey,
    required this.sectionSurvey,
    required this.sectionStations,
    required this.positions,
    required this.transform,
    this.selectedStation,
  });

  Offset _toScreen(StationPosition pos, Size size) =>
      transform.worldToScreen(pos.plan, size);

  void _drawStretches(
      Canvas canvas, Size size, Iterable<MeasuredDistance> stretches, Paint paint) {
    for (final stretch in stretches) {
      final fromPos = positions[stretch.from];
      final toPos = positions[stretch.to];

      if (fromPos != null && toPos != null) {
        final from = _toScreen(fromPos, size);
        final to = _toScreen(toPos, size);
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
      final screenPos = _toScreen(entry.value, size);

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
      final screenPos = _toScreen(entry.value, size);

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
    return oldDelegate.transform != transform ||
        oldDelegate.selectedStation != selectedStation ||
        oldDelegate.positions != positions ||
        oldDelegate.sectionSurvey != sectionSurvey;
  }
}
