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
///
/// The service keeps no station of its own: as in PocketTopo, the station new
/// measurements start from is determined by the last row of the data table,
/// which [stationProvider] supplies.
class MeasurementService extends ChangeNotifier {
  final SettingsController _settings;
  DistoXService? _distoXService;

  /// Detector for cross-section measurements (same station)
  SmartModeDetector? _crossSectionDetector;

  /// Detector for stretch measurements
  SmartModeDetector? _stretchDetector;

  /// Supplies the station new measurements start from
  Point Function()? stationProvider;

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

  /// Station where new measurements originate
  Point get currentStation => stationProvider?.call() ?? const Point(1, 0);

  /// Station a new survey shot leads to: the next point in the series
  Point get nextStation => currentStation.next;

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
    // Cross-section/splay: From station with null To
    final crossSection = MeasuredDistance(
      currentStation,
      null, // null "To" indicates splay shot
      distance,
      azimuth,
      inclination,
    );
    debugPrint('MeasurementService: calling onCrossSectionReady (${onCrossSectionReady != null})');
    onCrossSectionReady?.call(crossSection);
  }

  /// A survey shot from the current to the next station, swapped for
  /// backward shots
  MeasuredDistance _surveyShot(
      double distance, double azimuth, double inclination) {
    final backward = _settings.shotDirection == ShotDirection.backward;
    final current = currentStation;
    final next = nextStation;
    return MeasuredDistance(
      backward ? next : current,
      backward ? current : next,
      distance,
      azimuth,
      inclination,
    );
  }

  void _emitStretch(double distance, double azimuth, double inclination) {
    debugPrint('MeasurementService: _emitStretch called');
    final stretch = _surveyShot(distance, azimuth, inclination);
    debugPrint('MeasurementService: calling onStretchReady (${onStretchReady != null}), stretch=$stretch');
    onStretchReady?.call(stretch);
  }

  void _emitTripleReplacement(double distance, double azimuth, double inclination) {
    debugPrint('MeasurementService: _emitTripleReplacement called');
    final stretch = _surveyShot(distance, azimuth, inclination);
    debugPrint('MeasurementService: calling onTripleReplace (${onTripleReplace != null}), remove 3, add $stretch');
    onTripleReplace?.call(3, stretch);
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
}
