import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/history.dart';
import '../controllers/selection_state.dart';
import '../controllers/settings_controller.dart';
import '../controllers/view_navigation.dart';
import '../data/cave_repository.dart';
import '../data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/cross_section.dart';
import '../models/settings.dart';
import '../models/side_view.dart';
import '../models/sketch.dart';
import '../models/survey.dart';
import '../services/screen_density.dart';
import 'widgets/station_markers.dart';
import 'widgets/view_transform.dart';

enum SketchViewMode { outline, sideView }

class SketchView extends StatefulWidget {
  const SketchView({super.key});

  @override
  State<SketchView> createState() => _SketchViewState();
}

class _SketchViewState extends State<SketchView> {
  // Positions of the section's stations
  Map<Point, StationPosition> _positions = {};

  // The section's survey data as drawn in each view
  _SurveyDrawing _outlineDrawing = const _SurveyDrawing();
  _SurveyDrawing _sideViewDrawing = const _SurveyDrawing();

  // The survey data of the rest of the cave in the outline, drawn with
  // "Show All"
  _SurveyDrawing _outlineRestDrawing = const _SurveyDrawing();
  bool _showAll = false;

  // Survey data cross sections are drawn from: the section's own
  // measurements, oriented along the whole cave's survey shots
  Survey _sectionSurvey = const Survey(stretches: [], referencePoints: []);
  Survey _caveSurvey = const Survey(stretches: [], referencePoints: []);

  // Cross section chosen from the station menu, placed by the next tap
  ({Point station, CrossSectionKind kind})? _pendingCrossSection;

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

  Size _canvasSize = Size.zero;

  // Station tapped in move mode, shown in the status bar
  Point? _selectedStation;

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

  /// Switches to the outline or side view another view asked for, and
  /// centres on and selects the station if it belongs to the section
  void _onNavigation() {
    final request = _viewNavigation
        .take({NavigationTarget.outline, NavigationTarget.sideView});
    if (request == null) return;
    setState(() {
      _viewMode = request.target == NavigationTarget.outline
          ? SketchViewMode.outline
          : SketchViewMode.sideView;
      _pendingCrossSection = null;
      final station =
          _sectionSurvey.equivalentStations[request.station] ?? request.station;
      final position = _stationPositions[station];
      if (position != null) {
        _selectedStation = station;
        _transform = _transform.centeredOn([position]);
      }
    });
  }

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
        _outlineDrawing = const _SurveyDrawing();
        _sideViewDrawing = const _SurveyDrawing();
        _outlineRestDrawing = const _SurveyDrawing();
        _outlineSketch = const Sketch();
        _sideViewSketch = const Sketch();
        _sectionSurvey = const Survey(stretches: [], referencePoints: []);
        _caveSurvey = const Survey(stretches: [], referencePoints: []);
        _selectedStation = null;
        _pendingCrossSection = null;
        _currentSectionId = null;
      }
      return;
    }

    // Always recompute positions (survey data may have changed). They are
    // computed over the whole cave, so a section without its own reference
    // point is placed relative to the sections it continues from; only the
    // section's own stations are drawn.
    final caveSurvey = cave?.combinedSurvey ?? section.survey;
    final sectionSurvey = cave?.corrected(section.survey) ?? section.survey;
    final stations = sectionSurvey.stations;
    final allPositions = caveSurvey.computeStationPositions();
    _positions = Map.fromEntries(
        allPositions.entries.where((e) => stations.contains(e.key)));

    final planPositions = allPositions.map((k, v) => MapEntry(k, v.plan));
    Offset? planSplayEnd(MeasuredDistance splay) =>
        _planSplayEnd(allPositions, splay);
    _outlineDrawing =
        _SurveyDrawing.of(sectionSurvey, planPositions, planSplayEnd);
    final otherSections = [
      ...?cave?.allSections.where((s) => s.id != section.id),
    ];
    final restSurvey = Survey(
      stretches: [for (final s in otherSections) ...s.survey.stretches],
      referencePoints: [
        for (final s in otherSections) ...s.survey.referencePoints,
      ],
    );
    // Stations the section draws, or equivalent to them, are left out of the
    // rest of the cave so each is drawn only once
    final equivalents = caveSurvey.equivalentStations;
    final sectionDrawn = {
      for (final station in _outlineDrawing.stations.keys)
        equivalents[station] ?? station,
    };
    _outlineRestDrawing = _SurveyDrawing.of(
            cave?.corrected(restSurvey) ?? restSurvey,
            planPositions,
            planSplayEnd)
        .withoutStations((station) =>
            sectionDrawn.contains(equivalents[station] ?? station));
    final sideView = SideView.of(caveSurvey, allPositions);
    _sideViewDrawing = _SurveyDrawing.of(
      sectionSurvey,
      sideView.stationPositions,
      sideView.splayEnd,
    );
    _sectionSurvey = sectionSurvey;
    _caveSurvey = caveSurvey;

    // Only reset sketches and recenter when switching to a different section
    if (section.id != _currentSectionId) {
      _outlineSketch = section.outlineSketch;
      _sideViewSketch = section.sideViewSketch;
      _outlineHistory.clear();
      _sideViewHistory.clear();
      _selectedStation = null;
      _pendingCrossSection = null;
      _currentSectionId = section.id;
      _centerViews();
    }
  }

  /// The end of a splay or cross section shot in the plan view
  static Offset? _planSplayEnd(
      Map<Point, StationPosition> positions, MeasuredDistance splay) {
    final from = positions[splay.from];
    if (from == null) return null;
    final azimuth = splay.azimut.toDouble() * math.pi / 180;
    final horizontal = splay.distance.toDouble() *
        math.cos(splay.inclination.toDouble() * math.pi / 180);
    return from.plan +
        Offset(horizontal * math.sin(azimuth), -horizontal * math.cos(azimuth));
  }

  _SurveyDrawing get _drawing => _viewMode == SketchViewMode.outline
      ? _outlineDrawing
      : _sideViewDrawing;

  /// Where the section's stations appear in the current view, in world
  /// coordinates
  Map<Point, Offset> get _stationPositions => _drawing.stations;

  /// Places a cross section chosen from the station menu at a tap in move
  /// mode. Otherwise selects the station at the tap, or clears the
  /// selection when no station is near.
  void _onTapUp(TapUpDetails details) {
    if (_pendingCrossSection case final pending?) {
      _currentHistory.record(_currentSketch);
      setState(() {
        _currentSketch = _currentSketch.addCrossSection(CrossSection(
          station: pending.station,
          position: _screenToWorld(details.localPosition),
          kind: pending.kind,
        ));
        _pendingCrossSection = null;
      });
      _saveSketch();
      return;
    }
    final tapped = stationAt(
        _stationPositions, details.localPosition, _transform, _canvasSize);
    setState(() => _selectedStation = tapped);
  }

  /// The cross sections of the current sketch as drawn: the station copy
  /// and the ends of the station's cross section measurements
  List<_CrossSectionDrawing> get _crossSectionDrawings => [
        for (final c in _currentSketch.crossSections)
          _crossSectionDrawing(c),
      ];

  _CrossSectionDrawing _crossSectionDrawing(CrossSection crossSection) {
    final station = crossSection.station;
    return (
      station: station,
      position: crossSection.position,
      // Only the section's own measurements, like the splays drawn at the
      // station. The passage direction is taken from the whole cave, as the
      // shot leading on may be in another section; without one, a vertical
      // cross section looks north.
      ends: crossSection.splayEnds(
        _sectionSurvey.splaysAt(station),
        azimuth: _caveSurvey.passageAzimuth(station) ?? 0,
      ),
    );
  }

  /// Opens the context menu of the station at [localPosition], if any
  Future<void> _openStationMenu(
      Offset localPosition, Offset globalPosition) async {
    final station =
        stationAt(_stationPositions, localPosition, _transform, _canvasSize);
    final survey = context.read<SelectionState>().selectedSection?.survey;
    if (station == null || survey == null) return;

    final items = _stationMenuItems(station, survey);
    if (items.isEmpty) return;
    setState(() => _selectedStation = station);

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromRect(
          globalPosition & Size.zero, Offset.zero & overlay.size),
      items: items,
    );
    action?.call();
  }

  List<PopupMenuEntry<VoidCallback>> _stationMenuItems(
      Point station, Survey survey) {
    final l10n = AppLocalizations.of(context)!;
    PopupMenuItem<VoidCallback> crossSectionItem(
            CrossSectionKind kind, String label) =>
        PopupMenuItem(
          value: () => setState(() =>
              _pendingCrossSection = (station: station, kind: kind)),
          child: Text(label),
        );

    return [
      if (_viewMode == SketchViewMode.sideView) ...[
        // No undo for flipping, as in PocketTopo: flipping again reverts it
        PopupMenuItem(
          value: () => _updateSurvey((s) => s.flip(station)),
          enabled: survey.canFlip(station),
          child: Text(l10n.sketchFlip),
        ),
        PopupMenuItem(
          value: () => _updateSurvey((s) => s.flipAll(station)),
          child: Text(l10n.sketchFlipAll),
        ),
      ],
      crossSectionItem(
          CrossSectionKind.vertical, l10n.sketchCrossSectionVertical),
      // As in PocketTopo, only the side view offers horizontal ones
      if (_viewMode == SketchViewMode.sideView)
        crossSectionItem(
            CrossSectionKind.horizontal, l10n.sketchCrossSectionHorizontal),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: () => _viewNavigation.show(station, NavigationTarget.data),
        child: Text(l10n.navigateToData),
      ),
      PopupMenuItem(
        value: () => _viewNavigation.show(station, NavigationTarget.map),
        child: Text(l10n.navigateToMap),
      ),
      if (_viewMode == SketchViewMode.outline)
        PopupMenuItem(
          value: () =>
              _viewNavigation.show(station, NavigationTarget.sideView),
          child: Text(l10n.navigateToSideView),
        )
      else
        PopupMenuItem(
          value: () => _viewNavigation.show(station, NavigationTarget.outline),
          child: Text(l10n.navigateToOutline),
        ),
    ];
  }

  /// Changes the selected section's survey data and saves it
  void _updateSurvey(Survey Function(Survey survey) change) {
    _changeSection((section) => section.copyWith(
          survey: change(section.survey),
          modifiedAt: DateTime.now(),
        ));
  }

  void _centerViews() {
    _outlineTransform =
        _outlineTransform.centeredOn(_outlineDrawing.stations.values);
    _sideViewTransform =
        _sideViewTransform.centeredOn(_sideViewDrawing.stations.values);
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

  /// Puts both sketches into the latest state of the selected section and
  /// saves it
  void _saveSketch() {
    _changeSection((section) => section.copyWith(
          outlineSketch: _outlineSketch,
          sideViewSketch: _sideViewSketch,
          modifiedAt: DateTime.now(),
        ));
  }

  /// Applies [change] to the latest state of the selected section and saves
  /// it
  void _changeSection(Section Function(Section section) change) {
    final selectionState = context.read<SelectionState>();
    final sectionId = _currentSectionId;
    final caveId = selectionState.selectedCaveId;
    if (sectionId == null || caveId == null) return;

    final changed = selectionState.changeSection(sectionId, change);
    if (changed != null) {
      context.read<CaveRepository>().saveSection(caveId, changed);
    }
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

  /// Grid line spacing in metres: 1 m, or 5 ft when lengths are in feet.
  /// Null when the grid is turned off or the scale is 1:1000 or smaller,
  /// where a metre takes up no more than a millimetre on the screen.
  double? _gridSpacing(SettingsController settings, double pixelsPerMm) {
    if (!settings.showGrid || _transform.scale <= pixelsPerMm) return null;
    return settings.lengthUnit == LengthUnit.feet
        ? LengthUnit.feet.toMeters(5)
        : 1.0;
  }

  /// What to do to place a chosen cross section, the selected station's ID
  /// and coordinates, or else the scale
  String _statusText(
      AppLocalizations l10n, double pixelsPerMm, LengthUnit lengthUnit) {
    if (_pendingCrossSection case final pending?) {
      return l10n.sketchPlaceCrossSection(pending.station.toString());
    }
    final pos = _positions[_selectedStation];
    if (pos == null) {
      return l10n.sketchScale(_transform.scaleLabel(pixelsPerMm));
    }
    return stationStatus(l10n, pos, lengthUnit);
  }

  void _toggleGrid() {
    final settings = context.read<SettingsController>();
    settings.showGrid = !settings.showGrid;
    context.read<SettingsRepository>().save(settings.settings);
  }

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

    final settings = context.watch<SettingsController>();
    final pixelsPerMm = context.watch<ScreenDensity>().logicalPixelsPerMm;

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
                    _pendingCrossSection = null;
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
              PopupMenuButton<VoidCallback>(
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: _toggleGrid,
                    checked: settings.showGrid,
                    child: Text(l10n.optionsShowGrid),
                  ),
                  // As in PocketTopo, only the outline can show the rest of
                  // the cave
                  if (_viewMode == SketchViewMode.outline)
                    CheckedPopupMenuItem(
                      value: () => setState(() => _showAll = !_showAll),
                      checked: _showAll,
                      child: Text(l10n.sketchShowAll),
                    ),
                ],
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
                        // Stations are tapped and their menu opened only in
                        // move mode, as in PocketTopo
                        onTapUp: _sketchMode == SketchMode.move ? _onTapUp : null,
                        onLongPressStart: _sketchMode == SketchMode.move
                            ? (d) => _openStationMenu(
                                d.localPosition, d.globalPosition)
                            : null,
                        onSecondaryTapUp: _sketchMode == SketchMode.move
                            ? (d) => _openStationMenu(
                                d.localPosition, d.globalPosition)
                            : null,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _SketchPainter(
                              drawing: _drawing,
                              background: _showAll &&
                                      _viewMode == SketchViewMode.outline
                                  ? _outlineRestDrawing
                                  : null,
                              selectedStation: _selectedStation,
                              sketch: _currentSketch,
                              crossSections: _crossSectionDrawings,
                              currentStroke: _currentStroke,
                              transform: _transform,
                              gridSpacing: _gridSpacing(settings, pixelsPerMm),
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
              Expanded(
                child: Text(
                  _statusText(l10n, pixelsPerMm, settings.lengthUnit),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
          _pendingCrossSection = null;
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
          _pendingCrossSection = null;
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

/// The survey data of a section as drawn in one of the sketch views, in
/// world coordinates
/// A cross section as drawn, in world coordinates: a copy of [station] at
/// [position] with lines to the [ends] of its cross section measurements
typedef _CrossSectionDrawing = ({
  Point station,
  Offset position,
  List<Offset> ends,
});

class _SurveyDrawing {
  /// The section's stations
  final Map<Point, Offset> stations;

  /// Survey shots between two stations
  final List<(Offset, Offset)> shots;

  /// Splays and cross section shots
  final List<(Offset, Offset)> splays;

  const _SurveyDrawing({
    this.stations = const {},
    this.shots = const [],
    this.splays = const [],
  });

  /// Draws [survey] given where all stations of the cave appear in the view
  /// and where splays end. Shots to stations of other sections are drawn
  /// too, so the section connects to them. Of equivalent stations, only the
  /// first is drawn.
  factory _SurveyDrawing.of(
    Survey survey,
    Map<Point, Offset> stationPositions,
    Offset? Function(MeasuredDistance splay) splayEnd,
  ) {
    final shots = <(Offset, Offset)>[];
    final splays = <(Offset, Offset)>[];
    for (final stretch in survey.stretches) {
      final from = stationPositions[stretch.from];
      if (from == null) continue;
      final to = stretch.to == null
          ? splayEnd(stretch)
          : stationPositions[stretch.to];
      if (to == null) continue;
      (stretch.to == null ? splays : shots).add((from, to));
    }
    return _SurveyDrawing(
      stations: {
        for (final station in survey.distinctStations)
          if (stationPositions[station] case final position?)
            station: position,
      },
      shots: shots,
      splays: splays,
    );
  }

  /// This drawing without the stations for which [hidden] is true
  _SurveyDrawing withoutStations(bool Function(Point station) hidden) =>
      _SurveyDrawing(
        stations: {
          for (final MapEntry(:key, :value) in stations.entries)
            if (!hidden(key)) key: value,
        },
        shots: shots,
        splays: splays,
      );
}

class _SketchPainter extends CustomPainter {
  final _SurveyDrawing drawing;

  /// Survey data drawn underneath [drawing], for "Show All"
  final _SurveyDrawing? background;

  final Point? selectedStation;
  final Sketch sketch;
  final List<_CrossSectionDrawing> crossSections;
  final Stroke? currentStroke;
  final ViewTransform transform;

  /// Distance between grid lines in metres, or null for no grid
  final double? gridSpacing;

  _SketchPainter({
    required this.drawing,
    this.background,
    this.selectedStation,
    required this.sketch,
    this.crossSections = const [],
    this.currentStroke,
    required this.transform,
    this.gridSpacing,
  });

  Offset _worldToScreen(Offset worldPos, Size size) =>
      transform.worldToScreen(worldPos, size);

  void _drawGrid(Canvas canvas, Size size, double spacing) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;
    final topLeft = transform.screenToWorld(Offset.zero, size);
    final bottomRight = transform.screenToWorld(size.bottomRight(Offset.zero), size);

    for (var i = (topLeft.dx / spacing).ceil();
        i * spacing <= bottomRight.dx;
        i++) {
      final x = _worldToScreen(Offset(i * spacing, 0), size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = (topLeft.dy / spacing).ceil();
        i * spacing <= bottomRight.dy;
        i++) {
      final y = _worldToScreen(Offset(0, i * spacing), size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawSurvey(
    Canvas canvas,
    Size size,
    _SurveyDrawing drawing, {
    required Color color,
    required Color splayColor,
  }) {
    final shotPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final splayPaint = Paint()
      ..color = splayColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final (from, to) in drawing.splays) {
      canvas.drawLine(
          _worldToScreen(from, size), _worldToScreen(to, size), splayPaint);
    }
    for (final (from, to) in drawing.shots) {
      canvas.drawLine(
          _worldToScreen(from, size), _worldToScreen(to, size), shotPaint);
    }

    for (final entry in drawing.stations.entries) {
      paintStation(
        canvas,
        _worldToScreen(entry.value, size),
        entry.key,
        color: color,
        selected: entry.key == selectedStation,
        radius: 3,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (gridSpacing case final spacing?) _drawGrid(canvas, size, spacing);

    // The rest of the cave in black, as in the map view
    if (background case final background?) {
      _drawSurvey(canvas, size, background,
          color: Colors.black, splayColor: Colors.grey);
    }
    _drawSurvey(canvas, size, drawing,
        color: Colors.red, splayColor: Colors.orange);

    final crossSectionPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (final crossSection in crossSections) {
      final center = _worldToScreen(crossSection.position, size);
      for (final end in crossSection.ends) {
        canvas.drawLine(
            center, _worldToScreen(end, size), crossSectionPaint);
      }
      paintStation(canvas, center, crossSection.station,
          color: Colors.red, selected: false, radius: 3);
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
        oldDelegate.crossSections != crossSections ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.selectedStation != selectedStation ||
        oldDelegate.drawing != drawing ||
        oldDelegate.background != background;
  }
}
