import 'package:flutter/foundation.dart';
import '../controllers/settings_controller.dart';
import '../models/settings.dart';
import '../models/survey.dart';
import 'distox_protocol.dart';
import 'distox_service.dart';
import 'smart_mode_detector.dart';

/// Manages incoming measurements and applies smart mode detection.
///
/// In smart mode:
/// - Three identical cross-section measurements (same From, empty To) are
///   averaged into a single cross-section
/// - Three identical stretch measurements are averaged into a single survey shot
///
/// When smart mode is disabled, each measurement is added individually.
class MeasurementService extends ChangeNotifier {
  final SettingsController _settings;
  DistoXService? _distoXService;

  /// Detector for cross-section measurements (same station)
  SmartModeDetector? _crossSectionDetector;

  /// Detector for stretch measurements
  SmartModeDetector? _stretchDetector;

  /// Current "From" station for new measurements
  Point _currentStation = const Point(1, 0);

  /// Next "To" station ID (incremented after each survey shot)
  Point _nextStation = const Point(1, 1);

  /// Callback when a cross-section measurement is ready to be added
  void Function(MeasuredDistance crossSection)? onCrossSectionReady;

  /// Callback when a stretch (survey shot) is ready to be added
  void Function(MeasuredDistance stretch)? onStretchReady;

  /// Callback when last 3 cross-sections should be replaced with a survey shot
  /// The int is the number of cross-sections to remove (always 3)
  void Function(int removeCount, MeasuredDistance stretch)? onTripleReplace;

  MeasurementService(this._settings) {
    _initDetectors();
  }

  /// Connect to a DistoXService to receive measurements
  void connectDistoX(DistoXService distoXService) {
    _distoXService = distoXService;
    _distoXService!.onMeasurement = _onDistoXMeasurement;
  }

  /// Handle incoming measurement from DistoX device.
  ///
  /// In smart mode, all measurements are processed through the stretch
  /// detector. Triples become survey shots, singles become splays.
  /// This matches PocketTopo behavior where smart mode auto-detects
  /// survey shots from identical triples.
  void _onDistoXMeasurement(DistoXMeasurement m) {
    debugPrint('DistoX measurement received: $m');
    addMeasurement(
      distance: m.distance,
      azimuth: m.azimuth,
      inclination: m.inclination,
      isStretch: true, // In smart mode, detector will categorize as splay or survey
    );
  }

  /// Get the connected DistoX service (if any)
  DistoXService? get distoXService => _distoXService;

  void _initDetectors() {
    _crossSectionDetector = SmartModeDetector();
    _stretchDetector = SmartModeDetector();

    _crossSectionDetector!.onShotDetected = _onCrossSectionDetected;
    _stretchDetector!.onShotDetected = _onStretchSplayDetected;
    _stretchDetector!.onTripleDetected = _onTripleDetected;
  }

  /// Current station where measurements originate
  Point get currentStation => _currentStation;

  /// Set the current station (e.g., when user selects "Start Here")
  set currentStation(Point station) {
    if (_currentStation != station) {
      // Flush pending measurements when station changes
      flush();
      _currentStation = station;
      notifyListeners();
    }
  }

  /// Next station ID for survey shots
  Point get nextStation => _nextStation;

  /// Set the next station ID
  set nextStation(Point station) {
    _nextStation = station;
    notifyListeners();
  }

  /// Add an incoming measurement.
  ///
  /// If [isStretch] is true, this is a survey shot (From→To).
  /// If false, this is a cross-section measurement (From only).
  void addMeasurement({
    required double distance,
    required double azimuth,
    required double inclination,
    required bool isStretch,
  }) {
    final raw = RawMeasurement(
      distance: distance,
      azimuth: azimuth,
      inclination: inclination,
      timestamp: DateTime.now(),
    );

    debugPrint('MeasurementService: addMeasurement called, smartMode=${_settings.smartModeEnabled}, isStretch=$isStretch');

    if (_settings.smartModeEnabled) {
      // Use smart mode detection
      if (isStretch) {
        debugPrint('MeasurementService: adding to stretch detector, pending=${_stretchDetector!.pendingCount}');
        _stretchDetector!.addMeasurement(raw);
        debugPrint('MeasurementService: after add, pending=${_stretchDetector!.pendingCount}');
      } else {
        _crossSectionDetector!.addMeasurement(raw);
      }
    } else {
      // No smart mode - add measurement directly
      debugPrint('MeasurementService: emitting directly (no smart mode)');
      if (isStretch) {
        _emitStretch(distance, azimuth, inclination);
      } else {
        _emitCrossSection(distance, azimuth, inclination);
      }
    }
  }

  void _onCrossSectionDetected(DetectedShot shot) {
    // Cross-sections are always added immediately
    _emitCrossSection(shot.distance, shot.azimuth, shot.inclination);
  }

  void _onStretchSplayDetected(DetectedShot shot) {
    // In smart mode, every measurement is first added as a cross-section (splay)
    debugPrint('MeasurementService: _onStretchSplayDetected called');
    _emitCrossSection(shot.distance, shot.azimuth, shot.inclination);
  }

  void _onTripleDetected(DetectedShot shot) {
    // Triple detected - replace last 3 cross-sections with a survey shot
    debugPrint('MeasurementService: _onTripleDetected called');
    _emitTripleReplacement(shot.distance, shot.azimuth, shot.inclination);
  }

  void _emitCrossSection(double distance, double azimuth, double inclination) {
    debugPrint('MeasurementService: _emitCrossSection called');
    // Cross-section: From station with empty To (Point(0,0) means empty)
    final crossSection = MeasuredDistance(
      _currentStation,
      const Point(0, 0), // Empty "To" indicates cross-section
      distance,
      azimuth,
      inclination,
    );
    debugPrint('MeasurementService: calling onCrossSectionReady (${onCrossSectionReady != null})');
    onCrossSectionReady?.call(crossSection);
  }

  void _emitStretch(double distance, double azimuth, double inclination) {
    debugPrint('MeasurementService: _emitStretch called');
    Point from = _currentStation;
    Point to = _nextStation;

    // Handle shot direction (backward shots swap from/to)
    if (_settings.shotDirection == ShotDirection.backward) {
      final temp = from;
      from = to;
      to = temp;
    }

    final stretch = MeasuredDistance(
      from,
      to,
      distance,
      azimuth,
      inclination,
    );

    debugPrint('MeasurementService: calling onStretchReady (${onStretchReady != null}), stretch=$stretch');
    onStretchReady?.call(stretch);

    // Advance to next station
    _currentStation = to;
    _nextStation = Point(to.corridorId, to.pointId.toInt() + 1);
    notifyListeners();
  }

  void _emitTripleReplacement(double distance, double azimuth, double inclination) {
    debugPrint('MeasurementService: _emitTripleReplacement called');
    Point from = _currentStation;
    Point to = _nextStation;

    // Handle shot direction (backward shots swap from/to)
    if (_settings.shotDirection == ShotDirection.backward) {
      final temp = from;
      from = to;
      to = temp;
    }

    final stretch = MeasuredDistance(
      from,
      to,
      distance,
      azimuth,
      inclination,
    );

    debugPrint('MeasurementService: calling onTripleReplace (${onTripleReplace != null}), remove 3, add $stretch');
    onTripleReplace?.call(3, stretch);

    // Advance to next station
    _currentStation = to;
    _nextStation = Point(to.corridorId, to.pointId.toInt() + 1);
    notifyListeners();
  }

  /// Flush any pending measurements as individual shots
  void flush() {
    _crossSectionDetector?.flush();
    _stretchDetector?.flush();
  }

  /// Clear pending measurements without emitting them
  void clear() {
    _crossSectionDetector?.clear();
    _stretchDetector?.clear();
  }

  /// Number of pending cross-section measurements
  int get pendingCrossSections => _crossSectionDetector?.pendingCount ?? 0;

  /// Number of pending stretch measurements
  int get pendingStretches => _stretchDetector?.pendingCount ?? 0;

  /// Start a new series at a given station
  void startNewSeries(Point station, {int nextCorridorId = 1}) {
    flush();
    _currentStation = station;
    _nextStation = Point(nextCorridorId, 1);
    notifyListeners();
  }

  /// Continue from an existing station
  void continueFrom(Point station) {
    flush();
    _currentStation = station;
    _nextStation = Point(station.corridorId, station.pointId.toInt() + 1);
    notifyListeners();
  }
}
