import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/calibration.dart';
import 'calibration_algorithm.dart';
import 'calibration_diagnosis.dart';
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
/// - Diagnosing a calibration error above the limit
class CalibrationService extends ChangeNotifier {
  final DistoXService _distoX;
  final DistoXProtocol _protocol = DistoXProtocol();
  final CalibrationAlgorithm _algorithm = CalibrationAlgorithm();

  CalibrationState _state = CalibrationState.idle;
  List<CalibrationMeasurement> _measurements = [];
  List<CalibrationResult?>? _results;
  CalibrationCoefficients? _coefficients;
  double? _rmsError;
  double? _directionCoverage;
  int? _iterations;
  String? _error;

  /// Number of shots at the end of [_measurements] taken since the last
  /// retake started, which [undoLastShot] may take back.
  int _undoableShots = 0;

  /// Pending acceleration packet waiting for matching magnetic packet.
  CalibrationAccelPacket? _pendingAccel;

  /// In-flight memory transaction. The DistoX answers every read and write
  /// command with a memory reply for the same address, so only one command may
  /// be outstanding at a time.
  Completer<Uint8List>? _memoryReplyCompleter;
  int? _memoryReplyAddress;

  /// Quality limit for a calibration, from which [CalibrationDiagnoser]
  /// derives its limits for single shots.
  ///
  /// Step 8 of `docs/distox/DistoX2_CalibrationManual.txt`: "The third value
  /// given in the lower part of the screen is a measure of quality. It should
  /// be smaller than 0.5." That value is the error measure E of Heeb's paper
  /// as a percentage, which the paper shows is within 1% of the angular error
  /// in degrees — matching step 10's expectation that a calibrated device
  /// reads consistently "to a few tenth of a degree".
  ///
  /// See [CalibrationResult.errorScale] for the scaling this implies.
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

  /// [diagnosis], and the results it was worked out for.
  CalibrationDiagnosis? _diagnosis;
  List<CalibrationResult?>? _diagnosedResults;

  /// The suggested next position to take.
  CalibrationPosition? _suggestedNext = CalibrationPositions.bySlot(0);

  /// Reference bearing that defines "Forward" (direction 0), taken from the
  /// shots of direction 0.
  double? _referenceBearing;

  CalibrationService(this._distoX);

  // Getters
  CalibrationState get state => _state;
  List<CalibrationMeasurement> get measurements =>
      List.unmodifiable(_measurements);
  List<CalibrationResult?>? get results => _results;
  CalibrationCoefficients? get coefficients => _coefficients;
  int? get iterations => _iterations;

  /// How evenly the collected orientations cover the rotation group, 0 to 1.
  double? get directionCoverage => _directionCoverage;

  /// Whether enough of the rotation group is covered for the reported errors
  /// to carry information.
  ///
  /// Below the threshold, part of the G and M matrices is unconstrained by any
  /// measurement, and the residuals of those free parameters dominate the
  /// reported errors.
  bool get hasUsefulCoverage =>
      (_directionCoverage ?? 0) >= CalibrationAlgorithm.minUsefulCoverage;

  /// Overall calibration quality, available once [hasUsefulCoverage] holds.
  ///
  /// This is the error measure E of Heeb's paper scaled by
  /// [CalibrationResult.errorScale], i.e. roughly the angular error in
  /// degrees. The DistoX2 calibration manual asks for less than
  /// [errorThreshold].
  double? get rmsError => hasUsefulCoverage ? _rmsError : null;
  String? get error => _error;
  bool get hasResults => _results != null && _results!.isNotEmpty;
  int get measurementCount => _measurements.length;

  /// Check if connected to DistoX.
  bool get isConnected => _distoX.isConnected;

  /// Which slots are filled (0-55).
  Set<int> get filledSlots => _filledSlots.keys.toSet();

  /// Number of filled slots.
  int get filledSlotCount => _filledSlots.length;

  /// The suggested next position to take.
  CalibrationPosition? get suggestedNext => _suggestedNext;

  /// Reference bearing that defines "Forward" direction.
  double? get referenceBearing => _referenceBearing;

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

  /// What to tell the user about the shots, once all slots are filled and
  /// evaluated: nothing while [rmsError] is within [errorThreshold], and
  /// otherwise the likely cause and the suspect shots.
  ///
  /// Derived from the current results, so it always agrees with [rmsError];
  /// it is worked out once per set of results.
  CalibrationDiagnosis get diagnosis {
    final results = _results;
    if (_suggestedNext != null || results == null) {
      return CalibrationDiagnosis.ok;
    }
    if (!identical(results, _diagnosedResults)) {
      _diagnosedResults = results;
      _diagnosis = _diagnose(results);
    }
    return _diagnosis ?? CalibrationDiagnosis.ok;
  }

  /// Diagnose the evaluated shots of all slots.
  CalibrationDiagnosis _diagnose(List<CalibrationResult?> results) {
    final CalibrationOutput output;
    try {
      output = _algorithm.computeNow(_measurements);
    } on CalibrationException {
      return CalibrationDiagnosis.ok;
    }

    final positions = List<CalibrationPosition?>.filled(
      _measurements.length,
      null,
    );
    for (final MapEntry(key: slot, value: i) in _filledSlots.entries) {
      if (i < positions.length) positions[i] = CalibrationPositions.bySlot(slot);
    }

    final measurements = List.of(_measurements);
    return const CalibrationDiagnoser(errorLimit: errorThreshold).diagnose(
      measurements: measurements,
      positions: positions,
      results: results,
      output: output,
      rmsError: rmsError,
      referenceBearing: _referenceBearing,
      refit: (excluded) {
        try {
          return _algorithm.computeNow([
            for (int i = 0; i < measurements.length; i++)
              if (!excluded.contains(i)) measurements[i],
          ]).coefficients;
        } on CalibrationException {
          return null;
        }
      },
    );
  }

  /// Whether the last shot can be taken back: one was taken since
  /// calibration or the current retake started.
  bool get canUndoLastShot => _undoableShots > 0;

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
    _directionCoverage = null;
    _iterations = null;
    _error = null;
    _pendingAccel = null;
    _undoableShots = 0;
    _filledSlots.clear();
    _referenceBearing = null;
    _suggestedNext = CalibrationPositions.bySlot(0);
    notifyListeners();
  }

  /// Discard the most recent shot, so that its slot is asked for again.
  void undoLastShot() {
    if (!canUndoLastShot) return;
    final index = _measurements.length - 1;
    _filledSlots.removeWhere((_, i) => i == index);
    _measurements.removeAt(index);
    _results = _results?.take(index).toList();
    _undoableShots--;

    _updateSuggestedNext();
    notifyListeners();
    _tryAutoEvaluate();
  }

  /// Discard the four shots of [direction], so that they are asked for again.
  void retakeDirection(int direction) {
    final keep = [
      for (int i = 0; i < _measurements.length; i++)
        if (_measurements[i].direction != direction) i,
    ];
    final newIndex = {for (int k = 0; k < keep.length; k++) keep[k]: k};
    final results = _results;

    final slots = Map.of(_filledSlots);
    _filledSlots.clear();
    for (final MapEntry(key: slot, value: i) in slots.entries) {
      final k = newIndex[i];
      if (k != null) _filledSlots[slot] = k;
    }
    _measurements = [for (final i in keep) _measurements[i]];
    _results = results == null
        ? null
        : [for (final i in keep) if (i < results.length) results[i]];
    _undoableShots = 0;

    _updateSuggestedNext();
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

    // The shot fills the slot the user was asked to shoot.
    final next = _suggestedNext;
    if (next == null) {
      debugPrint('CalibrationService: ignoring shot, all slots are filled');
      _pendingAccel = null;
      return;
    }

    // The direction decides the group.
    final measurement = CalibrationMeasurement(
      gx: _pendingAccel!.gx,
      gy: _pendingAccel!.gy,
      gz: _pendingAccel!.gz,
      mx: packet.mx,
      my: packet.my,
      mz: packet.mz,
      index: _measurements.length + 1,
      enabled: true,
    ).forDirection(next.direction);

    _measurements.add(measurement);
    _filledSlots[next.slotIndex] = _measurements.length - 1;
    _undoableShots++;

    debugPrint('CalibrationService: added measurement #${measurement.index} '
        'for slot ${next.slotIndex} (direction ${next.direction}, '
        'group ${measurement.group})');

    _updateSuggestedNext();
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
      _directionCoverage = result.directionCoverage;
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

      debugPrint('Calibration computed: quality = '
          '${_rmsError?.toStringAsFixed(3)} (limit $errorThreshold), '
          'coverage = ${_directionCoverage?.toStringAsFixed(2)}, '
          'iterations = $_iterations');
      debugPrint('Error by cause: ${result.errorBreakdown}, '
          'alpha = ${result.alpha.toStringAsFixed(2)}°');

      // Debug: print measurement statistics
      final enabledMeasurements = _measurements.where((m) => m.enabled).toList();
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

        // Print group and direction distribution
        final groupCounts = <int, int>{};
        final directionCounts = <int, int>{};
        var freeCount = 0;
        for (final m in enabledMeasurements) {
          final group = m.group;
          if (group == null) {
            freeCount++;
          } else {
            groupCounts[group] = (groupCounts[group] ?? 0) + 1;
          }
          final direction = m.direction;
          if (direction != null) {
            directionCounts[direction] = (directionCounts[direction] ?? 0) + 1;
          }
        }
        debugPrint('  Groups: $groupCounts, free: $freeCount');
        debugPrint('  Directions: $directionCounts');
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

      _referenceBearing = _findReferenceBearing();
      debugPrint('Reference bearing: '
          '${_referenceBearing?.toStringAsFixed(1)}°');
      if (_suggestedNext == null) debugPrint('Diagnosis: $diagnosis');
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
      // sending the next. The device only keeps up with one command at a time,
      // and a chunk it never acknowledges is a chunk it never stored — leaving
      // a mix of new and stale coefficients behind.
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

  /// Bearing that defines "Forward", from the shots of the precisely aimed
  /// horizontal directions: direction 0 itself, or while it is being
  /// retaken, another one with its offset from Forward taken off.
  ///
  /// It comes out of the current fit, so it is re-derived on every evaluation
  /// to track the improving fit.
  double? _findReferenceBearing() {
    final results = _results;
    if (results == null) return null;

    for (int d = 0; d < CalibrationPositions.preciseDirections; d++) {
      final (offset, _) = CalibrationPositions.relativeDirections[d];
      for (int i = 0; i < _measurements.length && i < results.length; i++) {
        final result = results[i];
        if (result != null &&
            _measurements[i].enabled &&
            _measurements[i].direction == d) {
          return (result.azimuth - offset) % 360;
        }
      }
    }
    return null;
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

  @override
  void dispose() {
    _memoryReplyCompleter = null;
    _memoryReplyAddress = null;
    super.dispose();
  }
}
