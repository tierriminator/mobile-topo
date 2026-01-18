import 'dart:typed_data';

/// Packet types from DistoX2 protocol (InsideDistoX2.txt)
class DistoXPacketType {
  /// Measurement data: distance, azimuth, inclination, roll high byte
  static const int measurement = 0x01;

  /// Calibration acceleration sensor data
  static const int calibrationAccel = 0x02;

  /// Calibration magnetic field sensor data
  static const int calibrationMag = 0x03;

  /// Vector data: absG, absM, dip angle, roll low byte
  /// Sent after measurement packet for quality checking
  static const int vector = 0x04;

  /// Memory read reply
  static const int memoryReply = 0x38;
}

/// Commands that can be sent to DistoX2 (InsideDistoX2.txt)
class DistoXCommand {
  // Note: 0x31 = 0b00110001 starts calibration, 0x30 = 0b00110000 stops it
  static const int startCalibration = 0x31;
  static const int stopCalibration = 0x30;
  static const int stopSilentMode = 0x32;
  static const int startSilentMode = 0x33;
  static const int powerOff = 0x34; // v2.3+
  static const int triggerMeasurement = 0x35; // v2.3+
  static const int laserOn = 0x36; // v2.3+
  static const int laserOff = 0x37; // v2.3+
  static const int readMemory = 0x38;
  static const int writeMemory = 0x39;
}

/// A parsed measurement from DistoX
class DistoXMeasurement {
  final double distance;
  final double azimuth;
  final double inclination;
  final double rollAngle;
  final int sequenceBit;

  const DistoXMeasurement({
    required this.distance,
    required this.azimuth,
    required this.inclination,
    required this.rollAngle,
    required this.sequenceBit,
  });

  @override
  String toString() =>
      'DistoXMeasurement(dist: ${distance.toStringAsFixed(2)}m, '
      'azi: ${azimuth.toStringAsFixed(1)}°, incl: ${inclination.toStringAsFixed(1)}°)';
}

/// Handles DistoX binary protocol parsing and packet creation.
///
/// Protocol details from DistoXAdvancedInformation.txt:
/// - Measurement packets are 8 bytes
/// - Distance: 17-bit value in mm
/// - Angles: 16-bit values where full circle = 2^16 (radians * 2^15 / Pi)
/// - Sequence bit in bit 7 of byte 0 is toggled for each new packet
class DistoXProtocol {
  // Conversion factor: raw_value * 180 / 32768 = degrees
  static const double _angleToDegrees = 180.0 / 32768.0;

  // Roll angle uses different scale: raw_value * 180 / 128 = degrees
  static const double _rollToDegrees = 180.0 / 128.0;

  int? _lastSequenceBit;
  DistoXMeasurement? _lastMeasurement;

  /// Parse an 8-byte measurement packet from DistoX.
  ///
  /// Returns null if the packet is a duplicate (same sequence bit and data).
  /// Returns the parsed measurement otherwise.
  DistoXMeasurement? parseMeasurementPacket(Uint8List data) {
    if (data.length != 8) {
      throw ArgumentError('Measurement packet must be 8 bytes, got ${data.length}');
    }

    final type = data[0] & 0x3F;
    if (type != DistoXPacketType.measurement) {
      throw ArgumentError('Not a measurement packet, type: $type');
    }

    final sequenceBit = (data[0] >> 7) & 0x01;

    // Distance: 17 bits total (bit 6 of byte 0 + bytes 1-2), in mm
    final distanceBit16 = (data[0] >> 6) & 0x01;
    final distanceMm = data[1] | (data[2] << 8) | (distanceBit16 << 16);
    final distance = distanceMm / 1000.0; // Convert to meters

    // Azimuth: 16-bit unsigned, 0 = North, increases clockwise
    final azimuthRaw = data[3] | (data[4] << 8);
    final azimuth = azimuthRaw * _angleToDegrees;

    // Inclination: 16-bit signed, 0 = horizontal, positive = up
    final inclinationRaw = _toSigned16(data[5] | (data[6] << 8));
    final inclination = inclinationRaw * _angleToDegrees;

    // Roll angle: 8-bit, different scale
    final rollRaw = _toSigned8(data[7]);
    final rollAngle = rollRaw * _rollToDegrees;

    final measurement = DistoXMeasurement(
      distance: distance,
      azimuth: azimuth,
      inclination: inclination,
      rollAngle: rollAngle,
      sequenceBit: sequenceBit,
    );

    // Check for duplicate packet (same sequence bit + same data)
    if (_lastSequenceBit == sequenceBit && _isDuplicate(measurement)) {
      return null;
    }

    _lastSequenceBit = sequenceBit;
    _lastMeasurement = measurement;
    return measurement;
  }

  /// Build an acknowledge packet for a received data packet.
  ///
  /// The acknowledge byte has the sequence bit in bit 7 and 0x55 in bits 0-6.
  Uint8List buildAcknowledge(int sequenceBit) {
    return Uint8List.fromList([(sequenceBit << 7) | 0x55]);
  }

  /// Build an acknowledge for a measurement.
  Uint8List buildAcknowledgeFor(DistoXMeasurement measurement) {
    return buildAcknowledge(measurement.sequenceBit);
  }

  /// Parse any incoming packet and determine its type.
  ///
  /// Returns the packet type from byte 0, or null for invalid packets.
  int? getPacketType(Uint8List data) {
    if (data.isEmpty) return null;
    return data[0] & 0x3F;
  }

  /// Build a command to start calibration mode.
  Uint8List buildStartCalibrationCommand() {
    return Uint8List.fromList([DistoXCommand.startCalibration]);
  }

  /// Build a command to stop calibration mode.
  Uint8List buildStopCalibrationCommand() {
    return Uint8List.fromList([DistoXCommand.stopCalibration]);
  }

  /// Build a command to start silent mode.
  Uint8List buildStartSilentModeCommand() {
    return Uint8List.fromList([DistoXCommand.startSilentMode]);
  }

  /// Build a command to stop silent mode.
  Uint8List buildStopSilentModeCommand() {
    return Uint8List.fromList([DistoXCommand.stopSilentMode]);
  }

  /// Build a command to read 4 bytes from memory.
  Uint8List buildReadMemoryCommand(int address) {
    return Uint8List.fromList([
      DistoXCommand.readMemory,
      address & 0xFF,
      (address >> 8) & 0xFF,
    ]);
  }

  /// Build a command to write 4 bytes to memory.
  Uint8List buildWriteMemoryCommand(int address, List<int> data) {
    if (data.length != 4) {
      throw ArgumentError('Write data must be exactly 4 bytes');
    }
    return Uint8List.fromList([
      DistoXCommand.writeMemory,
      address & 0xFF,
      (address >> 8) & 0xFF,
      ...data,
    ]);
  }

  /// Reset protocol state (e.g., when reconnecting).
  void reset() {
    _lastSequenceBit = null;
    _lastMeasurement = null;
  }

  // Convert unsigned 16-bit to signed
  int _toSigned16(int value) {
    if (value >= 0x8000) {
      return value - 0x10000;
    }
    return value;
  }

  // Convert unsigned 8-bit to signed
  int _toSigned8(int value) {
    if (value >= 0x80) {
      return value - 0x100;
    }
    return value;
  }

  // Check if measurement is duplicate of last one
  bool _isDuplicate(DistoXMeasurement m) {
    final last = _lastMeasurement;
    if (last == null) return false;
    return m.distance == last.distance &&
        m.azimuth == last.azimuth &&
        m.inclination == last.inclination;
  }
}

/// Represents a memory read reply from DistoX
class DistoXMemoryReply {
  final int address;
  final Uint8List data;

  DistoXMemoryReply({required this.address, required this.data});
}

/// Parse a memory reply packet (8 bytes)
DistoXMemoryReply? parseMemoryReply(Uint8List data) {
  if (data.length != 8) return null;
  if ((data[0] & 0x3F) != DistoXPacketType.memoryReply) return null;

  final address = data[1] | (data[2] << 8);
  final replyData = Uint8List.fromList(data.sublist(3, 7));

  return DistoXMemoryReply(address: address, data: replyData);
}

/// Parsed calibration acceleration sensor data (packet type 0x02).
class CalibrationAccelPacket {
  /// X acceleration (16-bit signed).
  final int gx;

  /// Y acceleration (16-bit signed).
  final int gy;

  /// Z acceleration (16-bit signed).
  final int gz;

  /// Measurement number (1-56).
  final int measurementNumber;

  /// Sequence bit for acknowledgment.
  final int sequenceBit;

  const CalibrationAccelPacket({
    required this.gx,
    required this.gy,
    required this.gz,
    required this.measurementNumber,
    required this.sequenceBit,
  });

  @override
  String toString() =>
      'CalibrationAccelPacket(#$measurementNumber, G=($gx, $gy, $gz))';
}

/// Parsed calibration magnetic sensor data (packet type 0x03).
class CalibrationMagPacket {
  /// X magnetic field (16-bit signed).
  final int mx;

  /// Y magnetic field (16-bit signed).
  final int my;

  /// Z magnetic field (16-bit signed).
  final int mz;

  /// Measurement number (1-56).
  final int measurementNumber;

  /// Sequence bit for acknowledgment.
  final int sequenceBit;

  const CalibrationMagPacket({
    required this.mx,
    required this.my,
    required this.mz,
    required this.measurementNumber,
    required this.sequenceBit,
  });

  @override
  String toString() =>
      'CalibrationMagPacket(#$measurementNumber, M=($mx, $my, $mz))';
}

/// Extension to DistoXProtocol for calibration packet parsing.
extension DistoXCalibrationProtocol on DistoXProtocol {
  /// Parse calibration acceleration packet (type 0x02).
  ///
  /// Packet format:
  /// - Byte 0: [seqBit:1][0000010:7] = packet type
  /// - Bytes 1-2: Gx (16-bit signed, little-endian)
  /// - Bytes 3-4: Gy (16-bit signed, little-endian)
  /// - Bytes 5-6: Gz (16-bit signed, little-endian)
  /// - Byte 7: measurement number
  CalibrationAccelPacket? parseCalibrationAccelPacket(Uint8List data) {
    if (data.length != 8) return null;
    if ((data[0] & 0x3F) != DistoXPacketType.calibrationAccel) return null;

    final seqBit = (data[0] >> 7) & 0x01;
    final gx = _toSigned16(data[1] | (data[2] << 8));
    final gy = _toSigned16(data[3] | (data[4] << 8));
    final gz = _toSigned16(data[5] | (data[6] << 8));
    final num = data[7];

    return CalibrationAccelPacket(
      gx: gx,
      gy: gy,
      gz: gz,
      measurementNumber: num,
      sequenceBit: seqBit,
    );
  }

  /// Parse calibration magnetic packet (type 0x03).
  ///
  /// Packet format:
  /// - Byte 0: [seqBit:1][0000011:7] = packet type
  /// - Bytes 1-2: Mx (16-bit signed, little-endian)
  /// - Bytes 3-4: My (16-bit signed, little-endian)
  /// - Bytes 5-6: Mz (16-bit signed, little-endian)
  /// - Byte 7: measurement number
  CalibrationMagPacket? parseCalibrationMagPacket(Uint8List data) {
    if (data.length != 8) return null;
    if ((data[0] & 0x3F) != DistoXPacketType.calibrationMag) return null;

    final seqBit = (data[0] >> 7) & 0x01;
    final mx = _toSigned16(data[1] | (data[2] << 8));
    final my = _toSigned16(data[3] | (data[4] << 8));
    final mz = _toSigned16(data[5] | (data[6] << 8));
    final num = data[7];

    return CalibrationMagPacket(
      mx: mx,
      my: my,
      mz: mz,
      measurementNumber: num,
      sequenceBit: seqBit,
    );
  }

  // Helper to convert unsigned 16-bit to signed
  int _toSigned16(int value) {
    if (value >= 0x8000) {
      return value - 0x10000;
    }
    return value;
  }
}
