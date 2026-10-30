import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/selection_state.dart';
import '../controllers/settings_controller.dart';
import '../controllers/view_navigation.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/survey.dart';
import '../services/screen_density.dart';
import 'widgets/station_markers.dart';
import 'widgets/survey_key.dart';
import 'widgets/view_transform.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// The survey data everything below was computed from
  SurveyKey? _surveyKey;

  /// The whole cave's survey, ready for computing positions
  Survey? _caveSurvey;

  /// The selected section's stations
  Set<Point> _sectionStations = {};

  /// Surveyed length and height difference of the whole cave
  double _length = 0, _depth = 0;

  /// The stations drawn and where they are in the plan: of the rest of the
  /// cave and of the selected section
  List<(Point, Offset)> _caveStations = [], _sectionStationPositions = [];

  /// The survey shots drawn, from and to in the plan: of the rest of the
  /// cave and of the selected section
  List<(Offset, Offset)> _caveShots = [], _sectionShots = [];

  Map<Point, StationPosition> _positions = {};

  /// For each station, the first station it is equivalent to
  Map<Point, Point> _equivalentStations = {};

  /// The stations drawn: of equivalent stations, only the first
  Set<Point> _shownStations = {};

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

  late final ViewNavigation _viewNavigation;

  @override
  void initState() {
    super.initState();
    _viewNavigation = context.read<ViewNavigation>()
      ..addListener(_onNavigation);
  }

  @override
  void dispose() {
    _viewNavigation.removeListener(_onNavigation);
    super.dispose();
  }

  /// Centres on and selects a station another view asked to show here
  void _onNavigation() {
    final request = _viewNavigation.take({NavigationTarget.map});
    if (request == null) return;
    final station = _equivalentStations[request.station] ?? request.station;
    final position = _positions[station];
    if (position == null) return;
    setState(() {
      _selectedStation = station;
      _transform = _transform.centeredOn([position.plan]);
    });
  }

  void _updateFromSection(Cave? cave, Section? section) {
    // Computing positions takes a while for large caves, so it is only done
    // when the survey data has changed
    final key = SurveyKey(cave, section);
    if (key == _surveyKey) return;
    _surveyKey = key;

    if (section == null || cave == null) {
      _caveSurvey = null;
      _sectionStations = {};
      _caveStations = [];
      _sectionStationPositions = [];
      _caveShots = [];
      _sectionShots = [];
      _positions = {};
      _equivalentStations = {};
      _shownStations = {};
      _currentSectionId = null;
      return;
    }

    final caveSurvey = cave.combinedSurvey;
    _caveSurvey = caveSurvey;
    _sectionStations = section.survey.stations;
    _positions = caveSurvey.computeStationPositions();
    _equivalentStations = caveSurvey.equivalentStations;
    final shownStations = _shownStations = {
      for (final station in caveSurvey.distinctStations)
        if (_positions.containsKey(station)) station,
    };
    // A station drawn for an equivalent one in the section belongs to it too
    final drawnSectionStations = {
      for (final station in _sectionStations)
        _equivalentStations[station] ?? station,
    };
    _caveStations = [
      for (final station in shownStations)
        if (!drawnSectionStations.contains(station))
          (station, _positions[station]!.plan),
    ];
    _sectionStationPositions = [
      for (final station in shownStations)
        if (drawnSectionStations.contains(station))
          (station, _positions[station]!.plan),
    ];
    _caveShots = _shots([
      for (final s in cave.allSections)
        if (s.id != section.id) ...s.survey.stretches,
    ]);
    _sectionShots = _shots(section.survey.stretches);
    _length = caveSurvey.totalLength;
    _depth = caveSurvey.computeDepth(_positions);

    // Only recenter when switching to a different section
    if (section.id != _currentSectionId) {
      _currentSectionId = section.id;
      _centerView(_sectionStations);
    }
  }

  /// The survey shots of [stretches] whose stations both have a position,
  /// from and to in the plan
  List<(Offset, Offset)> _shots(List<MeasuredDistance> stretches) => [
        for (final stretch in stretches)
          if ((_positions[stretch.from], _positions[stretch.to])
              case (final from?, final to?))
            (from.plan, to.plan),
      ];

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
      _transform = _gestureStart.pinched(_gestureFocalPoint,
          details.localFocalPoint, details.scale, _canvasSize);
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() => _transform = _transform.scrolled(event, _canvasSize));
    }
  }

  Point? _stationAt(Offset localPosition) => stationAt(
        {for (final s in _shownStations) s: _positions[s]!.plan},
        localPosition,
        _transform,
        _canvasSize,
      );

  void _handleTapUp(TapUpDetails details) {
    setState(() => _selectedStation = _stationAt(details.localPosition));
  }

  /// Opens the context menu of the station at [localPosition], if any, to
  /// show it in the other views. The sketch only shows the selected
  /// section's stations, so only those can be shown there.
  Future<void> _openStationMenu(
      Offset localPosition, Offset globalPosition) async {
    final station = _stationAt(localPosition);
    final section = context.read<SelectionState>().selectedSection;
    if (station == null || section == null) return;
    setState(() => _selectedStation = station);

    final l10n = AppLocalizations.of(context)!;
    final inSection = section.survey.stations.contains(station);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final target = await showMenu<NavigationTarget>(
      context: context,
      position: RelativeRect.fromRect(
          globalPosition & Size.zero, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: NavigationTarget.data,
          child: Text(l10n.navigateToData),
        ),
        PopupMenuItem(
          value: NavigationTarget.outline,
          enabled: inSection,
          child: Text(l10n.navigateToOutline),
        ),
        PopupMenuItem(
          value: NavigationTarget.sideView,
          enabled: inSection,
          child: Text(l10n.navigateToSideView),
        ),
      ],
    );
    if (target != null) _viewNavigation.show(station, target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionState = context.watch<SelectionState>();
    final section = selectionState.selectedSection;

    // Update positions when the survey data changes
    _updateFromSection(selectionState.selectedCave, section);

    if (section == null || _caveSurvey == null) {
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

    final lengthUnit = context.watch<SettingsController>().lengthUnit;

    String statusText;
    if (_positions[_selectedStation] case final pos?) {
      statusText = stationStatus(l10n, pos, lengthUnit);
    } else {
      statusText = l10n.mapStatusOverview(
        lengthUnit.fromMeters(_length).toStringAsFixed(1),
        lengthUnit.fromMeters(_depth).toStringAsFixed(1),
        lengthUnit.symbol,
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
                        onLongPressStart: (d) =>
                            _openStationMenu(d.localPosition, d.globalPosition),
                        onSecondaryTapUp: (d) =>
                            _openStationMenu(d.localPosition, d.globalPosition),
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _MapPainter(
                              caveShots: _caveShots,
                              sectionShots: _sectionShots,
                              caveStations: _caveStations,
                              sectionStations: _sectionStationPositions,
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
  /// Survey shots and stations in the plan, of the rest of the cave and of
  /// the selected section
  final List<(Offset, Offset)> caveShots, sectionShots;
  final List<(Point, Offset)> caveStations, sectionStations;
  final ViewTransform transform;
  final Point? selectedStation;

  _MapPainter({
    required this.caveShots,
    required this.sectionShots,
    required this.caveStations,
    required this.sectionStations,
    required this.transform,
    this.selectedStation,
  });

  void _drawShots(Canvas canvas, Size size, List<(Offset, Offset)> shots,
      Color color) {
    paintLines(
      canvas,
      [
        for (final (from, to) in shots)
          (
            transform.worldToScreen(from, size),
            transform.worldToScreen(to, size)
          ),
      ],
      Paint()
        ..color = color
        ..strokeWidth = 2.0,
    );
  }

  void _drawStations(Canvas canvas, Size size, List<(Point, Offset)> stations,
      Color color) {
    paintStations(
      canvas,
      size,
      [
        for (final (station, position) in stations)
          (station, transform.worldToScreen(position, size)),
      ],
      color: color,
      selected: selectedStation,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw survey shots: the rest of the cave first, the section on top
    _drawShots(canvas, size, caveShots, Colors.black);
    _drawShots(canvas, size, sectionShots, Colors.red);

    // Draw stations, again with the section's stations on top
    _drawStations(canvas, size, caveStations, Colors.black);
    _drawStations(canvas, size, sectionStations, Colors.red);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.selectedStation != selectedStation ||
        oldDelegate.caveShots != caveShots ||
        oldDelegate.sectionShots != sectionShots ||
        oldDelegate.caveStations != caveStations ||
        oldDelegate.sectionStations != sectionStations;
  }
}
