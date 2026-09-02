import 'dart:async';

import 'package:flutter/foundation.dart';
import '../l10n/app_localizations.dart';

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

/// Phase of the calibration workflow.
enum CalibrationPhase {
  /// Phase 1: Collecting initial measurements (first 16) without guidance.
  /// User takes shots in any order until we have enough for initial calibration.
  collectingInitial,

  /// Phase 2: Guided collection to fill all 56 positions.
  /// We have coefficients, so we can detect positions and guide the user.
  /// Don't suggest corrections yet - just fill all slots.
  collectingGuided,

  /// Phase 3: All 56 positions filled. Now identifying and correcting bad shots.
  /// Suggests retaking measurements with high error.
  correcting,

  /// Calibration complete - all shots good, ready to write to device.
  complete,
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
  CalibrationPhase _phase = CalibrationPhase.collectingInitial;
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

  /// In-flight memory transaction. The DistoX answers every read and write
  /// command with a memory reply for the same address, so only one command may
  /// be outstanding at a time.
  Completer<Uint8List>? _memoryReplyCompleter;
  int? _memoryReplyAddress;

  /// Whether auto-detection mode is enabled.
  bool _autoDetectEnabled = true;

  /// Minimum measurements needed before auto-detection becomes reliable.
  static const int minForAutoDetect = 16;

  /// Error threshold (degrees) for considering a measurement "bad" and needing correction.
  static const double errorThreshold = 0.5;

  /// First address of the calibration coefficients in the device's
  /// configuration store: 0x8010-0x8027 hold G, 0x8028-0x803F hold M.
  static const int coefficientAddress = 0x8010;

  /// How long to wait for the reply to a single memory command.
  static const Duration _memoryReplyTimeout = Duration(seconds: 2);

  /// How many times to repeat a memory command that is not answered, or whose
  /// write is not echoed back correctly.
  static const int _memoryAttempts = 4;


  /// Which position slots (0-55) are filled, and by which measurement index.
  /// Key: slot index, Value: measurement list index.
  final Map<int, int> _filledSlots = {};

  /// Detected position for each measurement (null if not detected yet).
  List<CalibrationPosition?> _detectedPositions = [];

  /// The suggested next position to take.
  CalibrationPosition? _suggestedNext;

  /// Reference bearing that defines "Forward" (direction 0).
  /// Established from the first horizontal measurement.
  double? _referenceBearing;

  CalibrationService(this._distoX);

  // Getters
  CalibrationState get state => _state;
  CalibrationPhase get phase => _phase;
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

  /// Reference bearing that defines "Forward" direction.
  double? get referenceBearing => _referenceBearing;

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

  /// Get a user-friendly status message for the current phase.
  String getPhaseStatusMessage(AppLocalizations l10n) {
    switch (_phase) {
      case CalibrationPhase.collectingInitial:
        final remaining = minForAutoDetect - _measurements.length;
        if (remaining > 0) {
          return l10n.calibrationPhaseInitialRemaining(remaining);
        }
        return l10n.calibrationPhaseInitial;

      case CalibrationPhase.collectingGuided:
        final remaining = 56 - _filledSlots.length;
        return l10n.calibrationPhaseGuided(remaining, _filledSlots.length);

      case CalibrationPhase.correcting:
        final badCount = _countBadMeasurements();
        if (_retakeIndex != null) {
          final reason = _getBadMeasurementReason(_retakeIndex!, l10n);
          return l10n.calibrationPhaseCorrecting(_retakeIndex! + 1, reason, badCount);
        }
        return l10n.calibrationPhaseCorrectingGeneric(badCount);

      case CalibrationPhase.complete:
        return l10n.calibrationPhaseComplete;
    }
  }

  /// Count how many measurements need correction (high error or misaligned).
  int _countBadMeasurements() {
    int count = 0;
    for (int i = 0; i < _measurements.length; i++) {
      if (!_measurements[i].enabled) continue;

      final r = _results != null && i < _results!.length ? _results![i] : null;
      final hasHighError = r != null && r.error >= errorThreshold;
      final isMisaligned = isMeasurementMisaligned(i);

      if (hasHighError || isMisaligned) {
        count++;
      }
    }
    return count;
  }

  /// Get a description of why a measurement needs correction.
  String _getBadMeasurementReason(int index, AppLocalizations l10n) {
    final r = _results != null && index < _results!.length ? _results![index] : null;
    final hasHighError = r != null && r.error >= errorThreshold;
    final isMisaligned = isMeasurementMisaligned(index);

    if (hasHighError && isMisaligned) {
      return l10n.calibrationReasonBoth;
    } else if (hasHighError) {
      return l10n.calibrationReasonHighError(r.error.toStringAsFixed(2));
    } else if (isMisaligned) {
      return l10n.calibrationReasonMisaligned;
    }
    return 'unknown';
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
    _referenceBearing = null;
    _suggestedNext = _getFirstNeededPosition();
    _phase = CalibrationPhase.collectingInitial;
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
    int? newGroup;
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

    // Determine what to do: replace or append
    final bool isReplace = _retakeIndex != null;
    final int listPosition = isReplace ? _retakeIndex! : _measurements.length;

    // Get the group and slot from the suggested position (prescriptive assignment)
    // During collection, we assign based on what we told the user to take
    final int? group;
    final int? slotIndex;

    if (isReplace && _phase == CalibrationPhase.correcting) {
      // Correction phase: keep the same group/slot as the measurement being replaced
      final existing = _measurements[listPosition];
      group = existing.group;
      slotIndex = listPosition < _detectedPositions.length
          ? _detectedPositions[listPosition]?.slotIndex
          : null;
    } else if (_suggestedNext != null) {
      // Collection phase: assign based on suggested position
      group = _suggestedNext!.direction;
      slotIndex = _suggestedNext!.slotIndex;
    } else {
      // Fallback (shouldn't happen in normal flow)
      group = CalibrationData.defaultGroup(listPosition + 1);
      slotIndex = null;
    }

    // Combine into full measurement
    final measurement = CalibrationMeasurement(
      gx: _pendingAccel!.gx,
      gy: _pendingAccel!.gy,
      gz: _pendingAccel!.gz,
      mx: packet.mx,
      my: packet.my,
      mz: packet.mz,
      index: listPosition + 1,
      enabled: true,
      group: group,
    );

    if (isReplace) {
      // Replace a bad measurement
      _measurements[listPosition] = measurement;

      // Update detected position for the replaced measurement
      while (_detectedPositions.length <= listPosition) {
        _detectedPositions.add(null);
      }
      if (_suggestedNext != null) {
        _detectedPositions[listPosition] = _suggestedNext;
      }

      _retakeIndex = null;
      debugPrint('CalibrationService: replaced measurement at position $listPosition');
    } else if (_insertPosition != null) {
      // Insert at deleted position (manual delete case)
      final insertPos = _insertPosition!;
      _measurements.insert(insertPos, measurement);

      // Insert into detected positions as well
      while (_detectedPositions.length < insertPos) {
        _detectedPositions.add(null);
      }
      _detectedPositions.insert(insertPos, _suggestedNext);

      debugPrint('CalibrationService: inserted measurement at position $insertPos');
      _insertPosition = null;

      // Advance to next suggested position
      _updateSuggestedNext();
    } else {
      // Append new measurement
      _measurements.add(measurement);

      // Track the slot as filled (prescriptive: we assume user took the suggested position)
      if (slotIndex != null) {
        _filledSlots[slotIndex] = _measurements.length - 1;
      }

      // Track detected position (will be validated later)
      while (_detectedPositions.length < _measurements.length) {
        _detectedPositions.add(null);
      }
      _detectedPositions[_measurements.length - 1] = _suggestedNext;

      debugPrint('CalibrationService: added measurement #${measurement.index} '
          'for slot $slotIndex (group $group)');

      // Advance to next suggested position
      _updateSuggestedNext();
    }

    _pendingAccel = null;
    notifyListeners();

    // Auto-evaluate when we have enough measurements
    _tryAutoEvaluate();
  }

  /// Called when a memory reply packet is received.
  void onMemoryReply(DistoXMemoryReply reply) {
    final hex = reply.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final completer = _memoryReplyCompleter;

    // Only the reply for the address we are waiting on is meaningful. Replies
    // are matched by address rather than by arrival order because a dropped
    // reply would otherwise shift every following chunk onto the wrong offset.
    if (completer != null &&
        !completer.isCompleted &&
        reply.address == _memoryReplyAddress) {
      _memoryReplyCompleter = null;
      _memoryReplyAddress = null;
      completer.complete(reply.data);
      return;
    }

    debugPrint('CalibrationService: ignoring unexpected memory reply at '
        '0x${reply.address.toRadixString(16)} (data=$hex)');
  }

  /// Send one memory command and wait for the reply for [address].
  ///
  /// Returns the four reply bytes, or null if no reply arrived in time. The
  /// DistoX protocol is strictly request/response — one command outstanding at
  /// a time, and the spec says to repeat a command that goes unanswered.
  Future<Uint8List?> _memoryCommand(Uint8List command, int address) async {
    final completer = Completer<Uint8List>();
    _memoryReplyCompleter = completer;
    _memoryReplyAddress = address;
    try {
      await _distoX.sendCommand(command);
      return await completer.future.timeout(_memoryReplyTimeout);
    } catch (e) {
      debugPrint('CalibrationService: no reply for '
          '0x${address.toRadixString(16)} ($e)');
      return null;
    } finally {
      if (_memoryReplyCompleter == completer) {
        _memoryReplyCompleter = null;
        _memoryReplyAddress = null;
      }
    }
  }

  /// Write four bytes to [address], verifying the device's echo.
  ///
  /// The reply to a write command contains the memory contents after the
  /// write, so a mismatch means the write did not take and is worth retrying.
  Future<bool> _writeMemoryChunk(int address, List<int> data) async {
    for (int attempt = 1; attempt <= _memoryAttempts; attempt++) {
      final echo = await _memoryCommand(
        _protocol.buildWriteMemoryCommand(address, data),
        address,
      );
      if (echo != null && _bytesEqual(echo, data)) return true;

      debugPrint('CalibrationService: write to '
          '0x${address.toRadixString(16)} '
          '${echo == null ? "unacknowledged" : "echoed back ${_hex(echo)} "
              "instead of ${_hex(data)}"} '
          '(attempt $attempt of $_memoryAttempts)');
    }
    return false;
  }

  /// Read four bytes from [address], retrying if the reply is lost.
  Future<Uint8List?> _readMemoryChunk(int address) async {
    for (int attempt = 1; attempt <= _memoryAttempts; attempt++) {
      final data = await _memoryCommand(
        _protocol.buildReadMemoryCommand(address),
        address,
      );
      if (data != null) return data;
      debugPrint('CalibrationService: retrying read of '
          '0x${address.toRadixString(16)} '
          '(attempt $attempt of $_memoryAttempts)');
    }
    return null;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

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

      debugPrint('Calibration computed: RMS error = ${_rmsError?.toStringAsFixed(3)}°, '
          'iterations = $_iterations');

      // Debug: print measurement statistics
      final enabledMeasurements = _measurements.where((m) => m.enabled && m.group != null).toList();
      if (enabledMeasurements.isNotEmpty) {
        final gxRange = enabledMeasurements.map((m) => m.gx).toList()..sort();
        final gyRange = enabledMeasurements.map((m) => m.gy).toList()..sort();
        final gzRange = enabledMeasurements.map((m) => m.gz).toList()..sort();
        final mxRange = enabledMeasurements.map((m) => m.mx).toList()..sort();
        final myRange = enabledMeasurements.map((m) => m.my).toList()..sort();
        final mzRange = enabledMeasurements.map((m) => m.mz).toList()..sort();
        debugPrint('Measurement stats (${enabledMeasurements.length} enabled):');
        debugPrint('  G ranges: X=[${gxRange.first}, ${gxRange.last}], Y=[${gyRange.first}, ${gyRange.last}], Z=[${gzRange.first}, ${gzRange.last}]');
        debugPrint('  M ranges: X=[${mxRange.first}, ${mxRange.last}], Y=[${myRange.first}, ${myRange.last}], Z=[${mzRange.first}, ${mzRange.last}]');

        // Print group distribution
        final groupCounts = <int, int>{};
        for (final m in enabledMeasurements) {
          groupCounts[m.group!] = (groupCounts[m.group!] ?? 0) + 1;
        }
        debugPrint('  Groups: $groupCounts');
      }

      // Debug: print coefficient values
      final c = _coefficients!;
      debugPrint('Coefficients aG:');
      debugPrint('  [${c.aG.entry(0,0).toStringAsFixed(4)}, ${c.aG.entry(0,1).toStringAsFixed(4)}, ${c.aG.entry(0,2).toStringAsFixed(4)}]');
      debugPrint('  [${c.aG.entry(1,0).toStringAsFixed(4)}, ${c.aG.entry(1,1).toStringAsFixed(4)}, ${c.aG.entry(1,2).toStringAsFixed(4)}]');
      debugPrint('  [${c.aG.entry(2,0).toStringAsFixed(4)}, ${c.aG.entry(2,1).toStringAsFixed(4)}, ${c.aG.entry(2,2).toStringAsFixed(4)}]');
      debugPrint('Coefficients bG: [${c.bG.x.toStringAsFixed(4)}, ${c.bG.y.toStringAsFixed(4)}, ${c.bG.z.toStringAsFixed(4)}]');
      debugPrint('Coefficients aM:');
      debugPrint('  [${c.aM.entry(0,0).toStringAsFixed(4)}, ${c.aM.entry(0,1).toStringAsFixed(4)}, ${c.aM.entry(0,2).toStringAsFixed(4)}]');
      debugPrint('  [${c.aM.entry(1,0).toStringAsFixed(4)}, ${c.aM.entry(1,1).toStringAsFixed(4)}, ${c.aM.entry(1,2).toStringAsFixed(4)}]');
      debugPrint('  [${c.aM.entry(2,0).toStringAsFixed(4)}, ${c.aM.entry(2,1).toStringAsFixed(4)}, ${c.aM.entry(2,2).toStringAsFixed(4)}]');
      debugPrint('Coefficients bM: [${c.bM.x.toStringAsFixed(4)}, ${c.bM.y.toStringAsFixed(4)}, ${c.bM.z.toStringAsFixed(4)}]');

      // The A matrices act on raw counts already scaled by
      // CalibrationCoefficients.rawUnit (1/24000), so their diagonal should
      // come out around 1 — roughly 24000 / (counts per unit field). Report
      // the raw sphere radii too: those are what decide whether the required
      // gain fits the device's fixed point format at all.
      debugPrint('  aG diagonal: [${c.aG.entry(0,0).toStringAsFixed(4)}, '
          '${c.aG.entry(1,1).toStringAsFixed(4)}, ${c.aG.entry(2,2).toStringAsFixed(4)}]');
      debugPrint('  aM diagonal: [${c.aM.entry(0,0).toStringAsFixed(4)}, '
          '${c.aM.entry(1,1).toStringAsFixed(4)}, ${c.aM.entry(2,2).toStringAsFixed(4)}]');

      final saturated = c.saturatedElements;
      if (saturated.isNotEmpty) {
        debugPrint('WARNING: coefficients exceed the device fixed point range '
            '(|a| <= ${CalibrationCoefficients.maxMatrixElement}, '
            '|b| <= ${CalibrationCoefficients.maxBiasComponent}): '
            '${saturated.join(", ")}');
      }

      // Run auto-detection if enabled
      if (_autoDetectEnabled) {
        _runAutoDetection();
      }

      // Update phase based on current state
      _updatePhase();

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

  /// Write the computed coefficients to device memory.
  /// Returns true if successful, false otherwise.
  Future<bool> writeCoefficients() async {
    final c = _coefficients;
    if (c == null) {
      _error = 'No coefficients to write';
      notifyListeners();
      return false;
    }
    return writeCoefficientsFor(c);
  }

  /// Write [c] to the device's coefficient memory, verifying every chunk.
  /// Returns true if successful, false otherwise.
  Future<bool> writeCoefficientsFor(CalibrationCoefficients c) async {
    if (!isConnected) {
      _error = 'Not connected to DistoX';
      notifyListeners();
      return false;
    }

    // Never write coefficients the device's 48-byte fixed point format cannot
    // represent: toBytes would silently clamp them, leaving the device with a
    // near-singular transform (typically showing up as an azimuth stuck near
    // 0/180).
    final saturated = c.saturatedElements;
    if (saturated.isNotEmpty) {
      _error = 'Calibration coefficients exceed the range the DistoX can store '
          '(${saturated.join(", ")}). The sensor gain is too far from the '
          'device scale factor for these measurements to be written.';
      debugPrint('ERROR: Refusing to write unrepresentable coefficients: '
          '${saturated.join(", ")}');
      notifyListeners();
      return false;
    }

    _state = CalibrationState.writing;
    _error = null;
    notifyListeners();

    try {
      final bytes = c.toBytes();

      debugPrint('Writing calibration bytes (48 total):');
      debugPrint('  G coeffs: ${_hex(bytes.sublist(0, 24))}');
      debugPrint('  M coeffs: ${_hex(bytes.sublist(24, 48))}');

      // Write 4 bytes at a time to 0x8010-0x803F, confirming each chunk before
      // moving on. Firing all twelve writes back to back loses most of the
      // replies and, worse, most of the writes: the device is then left with a
      // mix of new and stale coefficients.
      for (int i = 0; i < 48; i += 4) {
        final address = coefficientAddress + i;
        final chunk = bytes.sublist(i, i + 4);

        if (!await _writeMemoryChunk(address, chunk)) {
          _error = 'The DistoX did not confirm the calibration data at '
              '0x${address.toRadixString(16)}. The coefficients are only '
              'partly written — reconnect and try again.';
          debugPrint('ERROR: giving up writing coefficients at '
              '0x${address.toRadixString(16)} after $_memoryAttempts attempts');
          _state = CalibrationState.idle;
          notifyListeners();
          return false;
        }
      }

      // Exit calibration mode on the device
      await _distoX.sendCommand(_protocol.buildStopCalibrationCommand());

      // Clear measurements after successful write
      clear();

      debugPrint('Calibration coefficients written to device and verified');
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
      // Read 4 bytes at a time from 0x8010-0x803F, one command at a time.
      // Assembling the buffer from replies in arrival order would silently
      // shift every following chunk if one reply were dropped.
      final bytes = Uint8List(48);
      for (int i = 0; i < 48; i += 4) {
        final address = coefficientAddress + i;
        final chunk = await _readMemoryChunk(address);
        if (chunk == null) {
          _error = 'The DistoX did not answer the read of '
              '0x${address.toRadixString(16)}.';
          _state = CalibrationState.idle;
          notifyListeners();
          return null;
        }
        bytes.setRange(i, i + 4, chunk);
      }

      final coeff = CalibrationCoefficients.fromBytes(bytes);
      _state = CalibrationState.idle;
      debugPrint('Read calibration coefficients from device:');
      debugPrint('  G coeffs: ${_hex(bytes.sublist(0, 24))}');
      debugPrint('  M coeffs: ${_hex(bytes.sublist(24, 48))}');
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

  /// Run auto-detection to validate measurements.
  ///
  /// During collection (phases 1-2): Validates shots but keeps prescriptive slot assignments.
  /// After 56 measurements (phase 3+): Identifies misaligned shots that need correction.
  void _runAutoDetection() {
    if (_coefficients == null || _results == null) return;

    // Establish reference bearing from first horizontal measurement
    _referenceBearing ??= _findReferenceBearing();
    debugPrint('Reference bearing: ${_referenceBearing?.toStringAsFixed(1)}°');

    // Ensure _detectedPositions list is sized correctly
    while (_detectedPositions.length < _measurements.length) {
      _detectedPositions.add(null);
    }

    // Detect actual position for each measurement (validation)
    for (int i = 0; i < _measurements.length; i++) {
      final result = _results![i];
      if (result == null || !_measurements[i].enabled) continue;

      final detectedPos = _detectPosition(
        result.azimuth,
        result.inclination,
        result.roll,
      );

      // Store detected position for comparison with prescriptive assignment
      _detectedPositions[i] = detectedPos;
    }

    debugPrint('Auto-detection: ${_filledSlots.length}/56 slots filled');
  }

  /// Check if a measurement is misaligned (detected position doesn't match assigned).
  bool isMeasurementMisaligned(int index) {
    if (index < 0 || index >= _measurements.length) return false;
    if (index >= _detectedPositions.length) return false;

    final assigned = _measurements[index].group;
    final detected = _detectedPositions[index];

    // No detection = can't validate = not misaligned (yet)
    if (detected == null) return false;

    // Check if detected direction matches assigned group
    return detected.direction != assigned;
  }

  /// Get list of misaligned measurement indices.
  List<int> get misalignedMeasurements {
    final misaligned = <int>[];
    for (int i = 0; i < _measurements.length; i++) {
      if (_measurements[i].enabled && isMeasurementMisaligned(i)) {
        misaligned.add(i);
      }
    }
    return misaligned;
  }

  /// Update the calibration phase based on current state.
  void _updatePhase() {
    // Phase 1: Still collecting initial measurements
    if (_coefficients == null) {
      _phase = CalibrationPhase.collectingInitial;
      _retakeIndex = null;
      return;
    }

    // Phase 2: Have coefficients, but not all 56 slots filled yet
    if (_filledSlots.length < 56) {
      _phase = CalibrationPhase.collectingGuided;
      _retakeIndex = null;
      return;
    }

    // Phase 3: All 56 slots filled - check for bad measurements
    _retakeIndex = _findFirstBadMeasurement();
    if (_retakeIndex != null) {
      _phase = CalibrationPhase.correcting;
      debugPrint('CalibrationService: correcting phase, next will replace index $_retakeIndex');
      return;
    }

    // Phase 4: All measurements good!
    _phase = CalibrationPhase.complete;
  }

  /// Find the first measurement that needs correction.
  /// A measurement needs correction if it has high error OR is misaligned.
  /// Returns the index, or null if all are good.
  int? _findFirstBadMeasurement() {
    if (_results == null) return null;

    for (int i = 0; i < _results!.length; i++) {
      if (!_measurements[i].enabled) continue;

      final r = _results![i];
      final hasHighError = r != null && r.error >= errorThreshold;
      final isMisaligned = isMeasurementMisaligned(i);

      if (hasHighError || isMisaligned) {
        return i;
      }
    }
    return null;
  }

  /// Find the reference bearing from the first horizontal measurement.
  /// Returns null if no suitable measurement found.
  double? _findReferenceBearing() {
    if (_results == null) return null;

    // Find the first enabled measurement that is roughly horizontal
    // (inclination within ±30° of horizontal)
    for (int i = 0; i < _measurements.length && i < _results!.length; i++) {
      if (!_measurements[i].enabled) continue;
      final result = _results![i];
      if (result == null) continue;

      // Check if roughly horizontal (Phase 1 shots are horizontal)
      if (result.inclination.abs() <= 30.0) {
        return result.azimuth;
      }
    }

    // Fallback: use first measurement regardless of inclination
    for (int i = 0; i < _measurements.length && i < _results!.length; i++) {
      if (!_measurements[i].enabled) continue;
      final result = _results![i];
      if (result != null) {
        return result.azimuth;
      }
    }

    return null;
  }

  /// Detect which position a measurement belongs to based on its angles.
  CalibrationPosition? _detectPosition(
    double bearing,
    double inclination,
    double roll,
  ) {
    final match = CalibrationPositions.findClosest(
      bearing,
      inclination,
      roll,
      referenceBearing: _referenceBearing,
    );
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
    if (m.group != direction) {
      _measurements[index] = m.copyWith(group: direction);
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
  String? getSuggestedNextDescription(AppLocalizations l10n) {
    if (_suggestedNext == null) {
      if (_filledSlots.length >= 56) {
        return l10n.calibrationAllPositionsFilled;
      }
      return null;
    }

    final pos = _suggestedNext!;
    final dirName = _getDirectionName(pos.direction, l10n);
    final rollName = _getRollName(pos.rollIndex, l10n);
    final progress = progressByDirection[pos.direction] ?? 0;

    return l10n.calibrationShotDescription(dirName, rollName, progress + 1);
  }

  /// Get localized direction name.
  String _getDirectionName(int direction, AppLocalizations l10n) {
    switch (direction) {
      case 0: return l10n.calibrationDirection0;
      case 1: return l10n.calibrationDirection1;
      case 2: return l10n.calibrationDirection2;
      case 3: return l10n.calibrationDirection3;
      case 4: return l10n.calibrationDirection4;
      case 5: return l10n.calibrationDirection5;
      case 6: return l10n.calibrationDirection6;
      case 7: return l10n.calibrationDirection7;
      case 8: return l10n.calibrationDirection8;
      case 9: return l10n.calibrationDirection9;
      case 10: return l10n.calibrationDirection10;
      case 11: return l10n.calibrationDirection11;
      case 12: return l10n.calibrationDirection12;
      case 13: return l10n.calibrationDirection13;
      default: return l10n.calibrationDirectionN(direction);
    }
  }

  /// Get localized roll name.
  String _getRollName(int rollIndex, AppLocalizations l10n) {
    switch (rollIndex) {
      case 0: return l10n.calibrationRoll0;
      case 1: return l10n.calibrationRoll90;
      case 2: return l10n.calibrationRoll180;
      case 3: return l10n.calibrationRoll270;
      default: return l10n.calibrationRollN(rollIndex);
    }
  }

  @override
  void dispose() {
    _memoryReplyCompleter = null;
    _memoryReplyAddress = null;
    super.dispose();
  }
}
