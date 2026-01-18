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
class CalibrationService extends ChangeNotifier {
  final DistoXService _distoX;
  final DistoXProtocol _protocol = DistoXProtocol();
  final CalibrationAlgorithm _algorithm = CalibrationAlgorithm();

  CalibrationState _state = CalibrationState.idle;
  List<CalibrationMeasurement> _measurements = [];
  List<CalibrationResult>? _results;
  CalibrationCoefficients? _coefficients;
  double? _rmsError;
  int? _iterations;
  String? _error;

  /// Pending acceleration packet waiting for matching magnetic packet.
  CalibrationAccelPacket? _pendingAccel;

  /// Memory read state for reading coefficients.
  final List<int> _memoryBuffer = [];
  int _memoryBytesExpected = 0;
  Completer<Uint8List>? _memoryReadCompleter;

  /// Memory write state.
  int _writtenBytes = 0;
  Completer<void>? _memoryWriteCompleter;

  CalibrationService(this._distoX);

  // Getters
  CalibrationState get state => _state;
  List<CalibrationMeasurement> get measurements =>
      List.unmodifiable(_measurements);
  List<CalibrationResult>? get results => _results;
  CalibrationCoefficients? get coefficients => _coefficients;
  double? get rmsError => _rmsError;
  int? get iterations => _iterations;
  String? get error => _error;
  bool get hasResults => _results != null && _results!.isNotEmpty;
  int get measurementCount => _measurements.length;

  /// Check if connected to DistoX.
  bool get isConnected => _distoX.isConnected;

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
    notifyListeners();
  }

  /// Delete a specific measurement.
  void deleteMeasurement(int index) {
    if (index < 0 || index >= _measurements.length) return;
    _measurements.removeAt(index);
    // Invalidate results since data changed
    _results = null;
    _rmsError = null;
    notifyListeners();
  }

  /// Toggle whether a measurement is enabled.
  void toggleEnabled(int index) {
    if (index < 0 || index >= _measurements.length) return;
    final m = _measurements[index];
    _measurements[index] = m.copyWith(enabled: !m.enabled);
    // Invalidate results since data changed
    _results = null;
    _rmsError = null;
    notifyListeners();
  }

  /// Cycle through group assignments: A -> B -> null -> A.
  void cycleGroup(int index) {
    if (index < 0 || index >= _measurements.length) return;
    final m = _measurements[index];
    String? newGroup;
    switch (m.group) {
      case 'A':
        newGroup = 'B';
      case 'B':
        newGroup = null;
      case null:
        newGroup = 'A';
    }
    _measurements[index] =
        newGroup == null ? m.copyWith(clearGroup: true) : m.copyWith(group: newGroup);
    // Invalidate results since data changed
    _results = null;
    _rmsError = null;
    notifyListeners();
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

    // Combine into full measurement
    final measurement = CalibrationMeasurement(
      gx: _pendingAccel!.gx,
      gy: _pendingAccel!.gy,
      gz: _pendingAccel!.gz,
      mx: packet.mx,
      my: packet.my,
      mz: packet.mz,
      index: packet.measurementNumber,
      enabled: true,
      group: CalibrationData.defaultGroup(packet.measurementNumber),
    );

    _measurements.add(measurement);
    _pendingAccel = null;

    debugPrint('CalibrationService: added measurement #${measurement.index}');
    notifyListeners();
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
      _results = result.results;
      _rmsError = result.rmsError;
      _iterations = result.iterations;
      _state = CalibrationState.idle;

      debugPrint('Calibration computed: RMS error = ${_rmsError?.toStringAsFixed(3)}°, '
          'iterations = $_iterations');
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
  Future<void> writeCoefficients() async {
    if (_coefficients == null) {
      _error = 'No coefficients to write';
      notifyListeners();
      return;
    }

    if (!isConnected) {
      _error = 'Not connected to DistoX';
      notifyListeners();
      return;
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

      _state = CalibrationState.idle;
      debugPrint('Calibration coefficients written to device');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to write coefficients: $e';
      _state = CalibrationState.idle;
      notifyListeners();
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

  @override
  void dispose() {
    _memoryReadCompleter = null;
    _memoryWriteCompleter = null;
    super.dispose();
  }
}
