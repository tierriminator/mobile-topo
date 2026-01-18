import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/calibration.dart';
import 'calibration_algorithm.dart';
import 'distox_protocol.dart';
import 'distox_service.dart';

/// State of the calibration process.
enum CalibrationState {
  /// Not actively calibrating.
  idle,

  /// Device is in calibration mode, collecting measurements.
  measuring,

  /// Computing calibration coefficients.
  computing,

  /// Writing coefficients to device memory.
  writing,

  /// Reading coefficients from device memory.
  reading,
}

/// Service for managing DistoX calibration.
///
/// Handles:
/// - Putting device in/out of calibration mode
/// - Collecting calibration measurements
/// - Computing calibration coefficients
/// - Writing coefficients to device memory
/// - Auto-detecting which position each shot belongs to
class CalibrationService extends ChangeNotifier {
  final DistoXService _distoX;
  final DistoXProtocol _protocol = DistoXProtocol();
  final CalibrationAlgorithm _algorithm = CalibrationAlgorithm();

  CalibrationState _state = CalibrationState.idle;
  List<CalibrationMeasurement> _measurements = [];
  List<CalibrationResult?>? _results;
  CalibrationCoefficients? _coefficients;
  double? _rmsError;
  int? _iterations;
  String? _error;

  /// Index of measurement to replace (for retakes after all 56 are done).
  /// If null, append to end (or insert at _insertPosition).
  int? _retakeIndex;

  /// Position to insert next measurement (when deleted manually).
  /// If null, append to end.
  int? _insertPosition;

  /// Pending acceleration packet waiting for matching magnetic packet.
  CalibrationAccelPacket? _pendingAccel;

  /// Memory read state for reading coefficients.
  final List<int> _memoryBuffer = [];
  int _memoryBytesExpected = 0;
  Completer<Uint8List>? _memoryReadCompleter;

  /// Memory write state.
  int _writtenBytes = 0;
  Completer<void>? _memoryWriteCompleter;

  /// Whether auto-detection mode is enabled.
  bool _autoDetectEnabled = true;

  /// Minimum measurements needed before auto-detection becomes reliable.
  static const int minForAutoDetect = 16;

  /// Which position slots (0-55) are filled, and by which measurement index.
  /// Key: slot index, Value: measurement list index.
  final Map<int, int> _filledSlots = {};

  /// Detected position for each measurement (null if not detected yet).
  List<CalibrationPosition?> _detectedPositions = [];

  /// The suggested next position to take.
  CalibrationPosition? _suggestedNext;

  CalibrationService(this._distoX);

  // Getters
  CalibrationState get state => _state;
  List<CalibrationMeasurement> get measurements =>
      List.unmodifiable(_measurements);
  List<CalibrationResult?>? get results => _results;
  CalibrationCoefficients? get coefficients => _coefficients;
  double? get rmsError => _rmsError;
  int? get iterations => _iterations;
  String? get error => _error;
  bool get hasResults => _results != null && _results!.isNotEmpty;
  int get measurementCount => _measurements.length;

  /// Check if connected to DistoX.
  bool get isConnected => _distoX.isConnected;

  /// Whether auto-detection is enabled.
  bool get autoDetectEnabled => _autoDetectEnabled;
  set autoDetectEnabled(bool value) {
    if (_autoDetectEnabled != value) {
      _autoDetectEnabled = value;
      if (value && _coefficients != null) {
        _runAutoDetection();
      }
      notifyListeners();
    }
  }

  /// Whether auto-detection is currently possible (enough measurements).
  bool get canAutoDetect =>
      _measurements.length >= minForAutoDetect && _coefficients != null;

  /// Detected positions for each measurement.
  List<CalibrationPosition?> get detectedPositions =>
      List.unmodifiable(_detectedPositions);

  /// Which slots are filled (0-55).
  Set<int> get filledSlots => _filledSlots.keys.toSet();

  /// Number of filled slots.
  int get filledSlotCount => _filledSlots.length;

  /// The suggested next position to take.
  CalibrationPosition? get suggestedNext => _suggestedNext;

  /// Get list of missing positions (not yet filled).
  List<CalibrationPosition> get missingPositions {
    final all = CalibrationPositions.all;
    return all.where((p) => !_filledSlots.containsKey(p.slotIndex)).toList();
  }

  /// Get progress by direction (how many of 4 rolls are filled for each).
  Map<int, int> get progressByDirection {
    final progress = <int, int>{};
    for (int d = 0; d < 14; d++) {
      int count = 0;
      for (int r = 0; r < 4; r++) {
        if (_filledSlots.containsKey(d * 4 + r)) count++;
      }
      progress[d] = count;
    }
    return progress;
  }

  /// Start calibration mode on the device.
  ///
  /// The device will begin sending calibration packets instead of
  /// measurement packets.
  Future<void> startCalibration() async {
    if (!isConnected) {
      _error = 'Not connected to DistoX';
      notifyListeners();
      return;
    }

    _state = CalibrationState.measuring;
    _error = null;
    notifyListeners();

    try {
      await _distoX.sendCommand(_protocol.buildStartCalibrationCommand());
    } catch (e) {
      _error = 'Failed to start calibration: $e';
      _state = CalibrationState.idle;
      notifyListeners();
    }
  }

  /// Stop calibration mode on the device.
  Future<void> stopCalibration() async {
    try {
      await _distoX.sendCommand(_protocol.buildStopCalibrationCommand());
    } catch (e) {
      debugPrint('Failed to stop calibration: $e');
    }

    _state = CalibrationState.idle;
    notifyListeners();
  }

  /// Clear all measurements and results.
  void clear() {
    _measurements = [];
    _results = null;
    _coefficients = null;
    _rmsError = null;
    _iterations = null;
    _error = null;
    _pendingAccel = null;
    _retakeIndex = null;
    _insertPosition = null;
    _filledSlots.clear();
    _detectedPositions = [];
    _suggestedNext = _getFirstNeededPosition();
    notifyListeners();
  }

  /// Delete a specific measurement.
  /// Sets insert position so the next measurement fills the gap.
  void deleteMeasurement(int index) {
    if (index < 0 || index >= _measurements.length) return;

    // Remove from filled slots if it was detected
    if (index < _detectedPositions.length && _detectedPositions[index] != null) {
      final slot = _detectedPositions[index]!.slotIndex;
      if (_filledSlots[slot] == index) {
        _filledSlots.remove(slot);
      }
    }

    _measurements.removeAt(index);
    _detectedPositions.removeAt(index);

    // Update filled slots indices (shift down)
    final updatedSlots = <int, int>{};
    for (final entry in _filledSlots.entries) {
      if (entry.value > index) {
        updatedSlots[entry.key] = entry.value - 1;
      } else {
        updatedSlots[entry.key] = entry.value;
      }
    }
    _filledSlots
      ..clear()
      ..addAll(updatedSlots);

    // Set insert position so next measurement goes here
    _insertPosition = index;
    // Clear retake index since we manually deleted
    _retakeIndex = null;

    _updateSuggestedNext();
    notifyListeners();
    _tryAutoEvaluate();
  }

  /// Toggle whether a measurement is enabled.
  void toggleEnabled(int index) {
    if (index < 0 || index >= _measurements.length) return;
    final m = _measurements[index];
    _measurements[index] = m.copyWith(enabled: !m.enabled);
    notifyListeners();
    _tryAutoEvaluate();
  }

  /// Toggle group assignment between default and null.
  /// For calibration, groups are numeric ("0"-"13") based on position.
  /// Cycling removes the group (null) or restores the default.
  void cycleGroup(int index) {
    if (index < 0 || index >= _measurements.length) return;
    final m = _measurements[index];
    String? newGroup;
    if (m.group != null) {
      // Has a group → remove it
      newGroup = null;
    } else {
      // No group → restore default based on position
      newGroup = CalibrationData.defaultGroup(index + 1);
    }
    _measurements[index] =
        newGroup == null ? m.copyWith(clearGroup: true) : m.copyWith(group: newGroup);
    notifyListeners();
    _tryAutoEvaluate();
  }

  /// Auto-evaluate if we have enough enabled measurements.
  void _tryAutoEvaluate() {
    final enabledCount = _measurements.where((m) => m.enabled).length;
    if (enabledCount >= CalibrationAlgorithm.minMeasurements) {
      evaluate();
    }
  }

  /// Called when a calibration acceleration packet is received.
  void onCalibrationAccelPacket(CalibrationAccelPacket packet) {
    debugPrint('CalibrationService: received accel packet $packet');
    _pendingAccel = packet;
  }

  /// Called when a calibration magnetic packet is received.
  void onCalibrationMagPacket(CalibrationMagPacket packet) {
    debugPrint('CalibrationService: received mag packet $packet');

    if (_pendingAccel == null) {
      debugPrint('CalibrationService: no pending accel packet');
      return;
    }

    // Verify measurement numbers match
    if (_pendingAccel!.measurementNumber != packet.measurementNumber) {
      debugPrint('CalibrationService: measurement number mismatch');
      _pendingAccel = null;
      return;
    }

    // Determine what to do: replace, insert, or append
    int position;
    bool isReplace = false;

    if (_retakeIndex != null) {
      // Replace a bad measurement (automatic retake after 56)
      position = _retakeIndex!;
      isReplace = true;
    } else if (_insertPosition != null) {
      // Insert at deleted position
      position = _insertPosition!;
    } else {
      // Append to end
      position = _measurements.length;
    }

    // Combine into full measurement
    // Use position-based group (1-indexed for defaultGroup)
    final measurement = CalibrationMeasurement(
      gx: _pendingAccel!.gx,
      gy: _pendingAccel!.gy,
      gz: _pendingAccel!.gz,
      mx: packet.mx,
      my: packet.my,
      mz: packet.mz,
      index: position + 1, // Use list position as index (1-indexed)
      enabled: true,
      group: CalibrationData.defaultGroup(position + 1),
    );

    if (isReplace) {
      // Replace the bad measurement
      _measurements[position] = measurement;
      _retakeIndex = null;
      debugPrint('CalibrationService: replaced measurement at position $position');
    } else if (_insertPosition != null) {
      // Insert at deleted position
      _measurements.insert(position, measurement);
      _insertPosition = null;
      debugPrint('CalibrationService: inserted measurement at position $position');
    } else {
      // Append
      _measurements.add(measurement);
      debugPrint('CalibrationService: added measurement #${measurement.index}');
    }

    _pendingAccel = null;
    notifyListeners();

    // Auto-evaluate when we have enough measurements
    _tryAutoEvaluate();
  }

  /// Called when a memory reply packet is received.
  void onMemoryReply(DistoXMemoryReply reply) {
    debugPrint(
        'CalibrationService: memory reply addr=0x${reply.address.toRadixString(16)}, '
        'data=${reply.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    if (_memoryReadCompleter != null && !_memoryReadCompleter!.isCompleted) {
      _memoryBuffer.addAll(reply.data);
      if (_memoryBuffer.length >= _memoryBytesExpected) {
        _memoryReadCompleter!.complete(Uint8List.fromList(_memoryBuffer));
      }
    }

    if (_memoryWriteCompleter != null && !_memoryWriteCompleter!.isCompleted) {
      _writtenBytes += 4;
      if (_writtenBytes >= 48) {
        _memoryWriteCompleter!.complete();
      }
    }
  }

  /// Compute calibration coefficients from collected measurements.
  Future<void> evaluate() async {
    if (_measurements.isEmpty) {
      _error = 'No measurements to evaluate';
      notifyListeners();
      return;
    }

    final enabledCount = _measurements.where((m) => m.enabled).length;
    if (enabledCount < CalibrationAlgorithm.minMeasurements) {
      _error = 'Need at least ${CalibrationAlgorithm.minMeasurements} enabled '
          'measurements, have $enabledCount';
      notifyListeners();
      return;
    }

    _state = CalibrationState.computing;
    _error = null;
    notifyListeners();

    try {
      final result = await _algorithm.compute(_measurements);

      _coefficients = result.coefficients;
      _rmsError = result.rmsError;
      _iterations = result.iterations;
      _state = CalibrationState.idle;

      // Expand results to match measurements indexing.
      // The algorithm only returns results for enabled measurements, so we need
      // to map them back to the full measurements list with null for disabled ones.
      final expandedResults = <CalibrationResult?>[];
      int algorithmResultIndex = 0;
      for (int i = 0; i < _measurements.length; i++) {
        if (_measurements[i].enabled &&
            algorithmResultIndex < result.results.length) {
          expandedResults.add(result.results[algorithmResultIndex]);
          algorithmResultIndex++;
        } else {
          expandedResults.add(null);
        }
      }
      _results = expandedResults;

      // After all 56 measurements, automatically set retake index for first bad measurement
      _retakeIndex = null;
      if (_measurements.length >= 56 && _results != null) {
        for (int i = 0; i < _results!.length; i++) {
          final r = _results![i];
          if (r != null && _measurements[i].enabled && r.error >= 0.5) {
            _retakeIndex = i;
            debugPrint('CalibrationService: next measurement will replace index $i');
            break;
          }
        }
      }

      debugPrint('Calibration computed: RMS error = ${_rmsError?.toStringAsFixed(3)}°, '
          'iterations = $_iterations');

      // Run auto-detection if enabled
      if (_autoDetectEnabled) {
        _runAutoDetection();
      }

      notifyListeners();
    } on CalibrationException catch (e) {
      _error = e.message;
      _state = CalibrationState.idle;
      notifyListeners();
    } catch (e) {
      _error = 'Calibration failed: $e';
      _state = CalibrationState.idle;
      notifyListeners();
    }
  }

  /// Write computed coefficients to device memory.
  /// Returns true if successful, false otherwise.
  Future<bool> writeCoefficients() async {
    if (_coefficients == null) {
      _error = 'No coefficients to write';
      notifyListeners();
      return false;
    }

    if (!isConnected) {
      _error = 'Not connected to DistoX';
      notifyListeners();
      return false;
    }

    _state = CalibrationState.writing;
    _error = null;
    notifyListeners();

    try {
      final bytes = _coefficients!.toBytes();
      _writtenBytes = 0;
      _memoryWriteCompleter = Completer<void>();

      // Write 4 bytes at a time to addresses 0x8010-0x803F
      for (int i = 0; i < 48; i += 4) {
        final address = 0x8010 + i;
        final data = bytes.sublist(i, i + 4);
        await _distoX.sendCommand(
            _protocol.buildWriteMemoryCommand(address, data.toList()));

        // Small delay between writes
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Wait for confirmation (or timeout)
      await _memoryWriteCompleter!.future
          .timeout(const Duration(seconds: 5))
          .catchError((_) {
        // Continue even if we don't get confirmation
        debugPrint('Write confirmation timeout (may still have succeeded)');
      });

      // Exit calibration mode on the device
      await _distoX.sendCommand(_protocol.buildStopCalibrationCommand());

      // Clear measurements after successful write
      clear();

      debugPrint('Calibration coefficients written to device');
      return true;
    } catch (e) {
      _error = 'Failed to write coefficients: $e';
      _state = CalibrationState.idle;
      notifyListeners();
      return false;
    }
  }

  /// Read current coefficients from device memory.
  Future<CalibrationCoefficients?> readCoefficients() async {
    if (!isConnected) {
      _error = 'Not connected to DistoX';
      notifyListeners();
      return null;
    }

    _state = CalibrationState.reading;
    _error = null;
    notifyListeners();

    try {
      _memoryBuffer.clear();
      _memoryBytesExpected = 48;
      _memoryReadCompleter = Completer<Uint8List>();

      // Read 4 bytes at a time from addresses 0x8010-0x803F
      for (int i = 0; i < 48; i += 4) {
        final address = 0x8010 + i;
        await _distoX.sendCommand(_protocol.buildReadMemoryCommand(address));

        // Small delay between reads
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Wait for all data (or timeout)
      final bytes = await _memoryReadCompleter!.future
          .timeout(const Duration(seconds: 5));

      final coeff = CalibrationCoefficients.fromBytes(bytes);
      _state = CalibrationState.idle;
      debugPrint('Read calibration coefficients from device');
      notifyListeners();
      return coeff;
    } catch (e) {
      _error = 'Failed to read coefficients: $e';
      _state = CalibrationState.idle;
      notifyListeners();
      return null;
    }
  }

  // ===== Auto-Detection Methods =====

  /// Run auto-detection on all measurements.
  /// This analyzes each measurement's direction and assigns it to a position slot.
  void _runAutoDetection() {
    if (_coefficients == null || _results == null) return;

    _filledSlots.clear();
    _detectedPositions = List<CalibrationPosition?>.filled(
      _measurements.length,
      null,
    );

    // Detect position for each measurement
    for (int i = 0; i < _measurements.length; i++) {
      final result = _results![i];
      if (result == null || !_measurements[i].enabled) continue;

      final position = _detectPosition(
        result.azimuth,
        result.inclination,
        result.roll,
      );

      if (position != null) {
        _detectedPositions[i] = position;

        // Assign to slot if not already filled, or if this one has lower error
        final slot = position.slotIndex;
        final existingIdx = _filledSlots[slot];

        if (existingIdx == null) {
          // Slot is empty, fill it
          _filledSlots[slot] = i;
          // Update measurement's group to match detected direction
          _updateMeasurementGroup(i, position.direction);
        } else {
          // Slot already filled - keep the one with lower error
          final existingError = _results![existingIdx]?.error ?? double.infinity;
          if (result.error < existingError) {
            _filledSlots[slot] = i;
            _updateMeasurementGroup(i, position.direction);
          }
        }
      }
    }

    _updateSuggestedNext();

    debugPrint('Auto-detection: ${_filledSlots.length}/56 slots filled');
  }

  /// Detect which position a measurement belongs to based on its angles.
  CalibrationPosition? _detectPosition(
    double bearing,
    double inclination,
    double roll,
  ) {
    final match = CalibrationPositions.findClosest(bearing, inclination, roll);
    if (match == null) return null;

    final (position, dirError, rollError) = match;

    // Check if within tolerance
    if (dirError <= CalibrationPositions.directionTolerance &&
        rollError <= CalibrationPositions.rollTolerance) {
      return position;
    }

    return null;
  }

  /// Update a measurement's group based on detected direction.
  void _updateMeasurementGroup(int index, int direction) {
    if (index < 0 || index >= _measurements.length) return;
    final m = _measurements[index];
    final newGroup = direction.toString();
    if (m.group != newGroup) {
      _measurements[index] = m.copyWith(group: newGroup);
    }
  }

  /// Update the suggested next position based on what's missing.
  void _updateSuggestedNext() {
    // Priority order:
    // 1. Complete partially-filled directions (finish 4 rolls for a direction)
    // 2. Then fill new directions in order (0-13)

    // Find directions that are partially filled
    final progress = progressByDirection;

    // First, try to complete partially-filled directions
    for (int d = 0; d < 14; d++) {
      final filled = progress[d] ?? 0;
      if (filled > 0 && filled < 4) {
        // Find the first missing roll for this direction
        for (int r = 0; r < 4; r++) {
          final slot = d * 4 + r;
          if (!_filledSlots.containsKey(slot)) {
            _suggestedNext = CalibrationPositions.bySlot(slot);
            return;
          }
        }
      }
    }

    // Then, find the first completely empty direction
    for (int d = 0; d < 14; d++) {
      final filled = progress[d] ?? 0;
      if (filled == 0) {
        // Start with roll 0 for this direction
        _suggestedNext = CalibrationPositions.bySlot(d * 4);
        return;
      }
    }

    // All slots filled
    _suggestedNext = null;
  }

  /// Get the first needed position (for initial state).
  CalibrationPosition? _getFirstNeededPosition() {
    return CalibrationPositions.bySlot(0);
  }

  /// Manually assign a measurement to a specific position slot.
  /// This overrides auto-detection for that measurement.
  void assignToSlot(int measurementIndex, int slotIndex) {
    if (measurementIndex < 0 || measurementIndex >= _measurements.length) return;
    if (slotIndex < 0 || slotIndex >= 56) return;

    final position = CalibrationPositions.bySlot(slotIndex);
    if (position == null) return;

    // Remove measurement from its current slot if any
    if (measurementIndex < _detectedPositions.length) {
      final oldPos = _detectedPositions[measurementIndex];
      if (oldPos != null) {
        final oldSlot = oldPos.slotIndex;
        if (_filledSlots[oldSlot] == measurementIndex) {
          _filledSlots.remove(oldSlot);
        }
      }
    }

    // Ensure detectedPositions list is long enough
    while (_detectedPositions.length <= measurementIndex) {
      _detectedPositions.add(null);
    }

    // Assign to new slot
    _detectedPositions[measurementIndex] = position;
    _filledSlots[slotIndex] = measurementIndex;
    _updateMeasurementGroup(measurementIndex, position.direction);

    _updateSuggestedNext();
    notifyListeners();
  }

  /// Get a description of the suggested next shot for the user.
  String? getSuggestedNextDescription() {
    if (_suggestedNext == null) {
      if (_filledSlots.length >= 56) {
        return 'All 56 positions filled!';
      }
      return null;
    }

    final pos = _suggestedNext!;
    final dirNames = [
      'North (horizontal)',
      'East (horizontal)',
      'South (horizontal)',
      'West (horizontal)',
      'NE (up 45°)',
      'SE (up 45°)',
      'SW (up 45°)',
      'NW (up 45°)',
      'NE (down 45°)',
      'SE (down 45°)',
      'SW (down 45°)',
      'NW (down 45°)',
      'Up (vertical)',
      'Down (vertical)',
    ];

    final rollNames = ['0°', '90°', '180°', '270°'];

    final dirName = pos.direction < dirNames.length
        ? dirNames[pos.direction]
        : 'Direction ${pos.direction}';
    final rollName = pos.rollIndex < rollNames.length
        ? rollNames[pos.rollIndex]
        : 'Roll ${pos.rollIndex}';

    final progress = progressByDirection[pos.direction] ?? 0;
    return '$dirName, roll $rollName (${progress + 1}/4)';
  }

  @override
  void dispose() {
    _memoryReadCompleter = null;
    _memoryWriteCompleter = null;
    super.dispose();
  }
}
