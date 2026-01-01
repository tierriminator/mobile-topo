import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../topo.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
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

  // View transformation
  double _scale = 20.0; // pixels per meter
  Offset _offset = Offset.zero;

  // For gesture handling
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  // Selected station
  Point? _selectedStation;

  @override
  void initState() {
    super.initState();
    _positions = _survey.computeStationPositions();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle zoom
      _scale = (_startScale * details.scale).clamp(5.0, 200.0);

      // Handle pan - calculate total delta from start
      final focalPointDelta = details.focalPoint - _startFocalPoint;
      _offset = _startOffset + focalPointDelta;
    });
  }

  // Store the canvas size for tap detection
  Size _canvasSize = Size.zero;

  void _handleTapUp(TapUpDetails details) {
    // Find if a station was tapped
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

    // No station tapped, deselect
    setState(() {
      _selectedStation = null;
    });
  }

  Offset _worldToScreen(double east, double north, Size size) {
    // Convert world coordinates to screen coordinates
    // East goes right (positive X), North goes up (negative Y in screen coords)
    // Center the map in the view
    return Offset(
      east * _scale + _offset.dx + size.width / 2,
      -north * _scale + _offset.dy + size.height / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final depth = _survey.computeDepth(_positions);
    final length = _survey.totalLength;

    // Get selected station info
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapUp: _handleTapUp,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _MapPainter(
                      survey: _survey,
                      positions: _positions,
                      scale: _scale,
                      offset: _offset,
                      selectedStation: _selectedStation,
                    ),
                    size: Size.infinite,
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

class _MapPainter extends CustomPainter {
  final Survey survey;
  final Map<Point, StationPosition> positions;
  final double scale;
  final Offset offset;
  final Point? selectedStation;

  _MapPainter({
    required this.survey,
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

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final stationPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final selectedPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw survey shots (lines between stations)
    for (final stretch in survey.stretches) {
      final fromPos = positions[stretch.from];
      final toPos = positions[stretch.to];

      if (fromPos != null && toPos != null) {
        final from = _worldToScreen(fromPos.east, fromPos.north, size);
        final to = _worldToScreen(toPos.east, toPos.north, size);
        canvas.drawLine(from, to, linePaint);
      }
    }

    // Draw stations
    for (final entry in positions.entries) {
      final pos = entry.value;
      final screenPos = _worldToScreen(pos.east, pos.north, size);

      final isSelected = entry.key == selectedStation;
      final paint = isSelected ? selectedPaint : stationPaint;
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
        oldDelegate.positions != positions;
  }
}
