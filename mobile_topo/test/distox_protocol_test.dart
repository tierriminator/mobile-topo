import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/distox_protocol.dart';

void main() {
  group('DistoXProtocol', () {
    late DistoXProtocol protocol;

    setUp(() {
      protocol = DistoXProtocol();
    });

    group('parseMeasurementPacket', () {
      test('parses distance correctly', () {
        // Distance: 1234mm = 0x04D2 (low bytes) + 0 (bit 16)
        // Packet: type=0x01, distance_low=0xD2, distance_high=0x04
        final packet = Uint8List.fromList([
          0x01, // type (measurement) + seq bit 0
          0xD2, 0x04, // distance: 1234mm
          0x00, 0x00, // azimuth: 0
          0x00, 0x00, // inclination: 0
          0x00, // roll: 0
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement, isNotNull);
        expect(measurement!.distance, closeTo(1.234, 0.001));
      });

      test('parses distance with bit 16', () {
        // Distance: 65536mm + 1234mm = 66770mm (bit 16 set)
        // Byte 0: 0x41 (seq=0, bit16=1, type=0x01)
        final packet = Uint8List.fromList([
          0x41, // type + bit16 set
          0xD2, 0x04, // distance low bytes: 1234
          0x00, 0x00,
          0x00, 0x00,
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement, isNotNull);
        expect(measurement!.distance, closeTo(66.770, 0.001));
      });

      test('parses azimuth correctly (north = 0)', () {
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03, // 1000mm distance
          0x00, 0x00, // azimuth: 0 = north
          0x00, 0x00,
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.azimuth, closeTo(0.0, 0.01));
      });

      test('parses azimuth correctly (east = 90)', () {
        // 0x4000 = 16384 = 90 degrees
        // Formula: raw * 180 / 32768
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x40, // azimuth: 0x4000 = east
          0x00, 0x00,
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.azimuth, closeTo(90.0, 0.01));
      });

      test('parses azimuth correctly (south = 180)', () {
        // 0x8000 = 32768 = 180 degrees
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x80, // azimuth: 0x8000 = south
          0x00, 0x00,
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.azimuth, closeTo(180.0, 0.01));
      });

      test('parses azimuth correctly (west = 270)', () {
        // 0xC000 = 49152 = 270 degrees
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0xC0, // azimuth: 0xC000 = west
          0x00, 0x00,
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.azimuth, closeTo(270.0, 0.01));
      });

      test('parses inclination correctly (horizontal = 0)', () {
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x00,
          0x00, 0x00, // inclination: 0 = horizontal
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.inclination, closeTo(0.0, 0.01));
      });

      test('parses inclination correctly (up = 90)', () {
        // 0x4000 = 16384 = 90 degrees (up)
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x00,
          0x00, 0x40, // inclination: 0x4000 = up
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.inclination, closeTo(90.0, 0.01));
      });

      test('parses inclination correctly (down = -90)', () {
        // 0xC000 = -16384 (signed) = -90 degrees (down)
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x00,
          0x00, 0xC0, // inclination: 0xC000 = down
          0x00,
        ]);

        final measurement = protocol.parseMeasurementPacket(packet);
        expect(measurement!.inclination, closeTo(-90.0, 0.01));
      });

      test('returns null for duplicate packet', () {
        final packet = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x40,
          0x00, 0x20,
          0x00,
        ]);

        // First call should return measurement
        final first = protocol.parseMeasurementPacket(packet);
        expect(first, isNotNull);

        // Second call with same packet should return null
        final second = protocol.parseMeasurementPacket(packet);
        expect(second, isNull);
      });

      test('returns measurement when sequence bit changes', () {
        final packet1 = Uint8List.fromList([
          0x01, // seq bit = 0
          0xE8, 0x03,
          0x00, 0x40,
          0x00, 0x20,
          0x00,
        ]);

        final packet2 = Uint8List.fromList([
          0x81, // seq bit = 1 (same data)
          0xE8, 0x03,
          0x00, 0x40,
          0x00, 0x20,
          0x00,
        ]);

        final first = protocol.parseMeasurementPacket(packet1);
        expect(first, isNotNull);

        // Different sequence bit means new packet
        final second = protocol.parseMeasurementPacket(packet2);
        expect(second, isNotNull);
      });

      test('throws for wrong packet length', () {
        final shortPacket = Uint8List.fromList([0x01, 0x00, 0x00]);
        expect(
          () => protocol.parseMeasurementPacket(shortPacket),
          throwsArgumentError,
        );
      });

      test('throws for wrong packet type', () {
        final wrongType = Uint8List.fromList([
          0x02, // calibration type
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);
        expect(
          () => protocol.parseMeasurementPacket(wrongType),
          throwsArgumentError,
        );
      });
    });

    group('buildAcknowledge', () {
      test('builds acknowledge with sequence bit 0', () {
        final ack = protocol.buildAcknowledge(0);
        expect(ack.length, 1);
        expect(ack[0], 0x55); // bit 7 = 0, bits 0-6 = 0x55
      });

      test('builds acknowledge with sequence bit 1', () {
        final ack = protocol.buildAcknowledge(1);
        expect(ack.length, 1);
        expect(ack[0], 0xD5); // bit 7 = 1, bits 0-6 = 0x55
      });
    });

    group('getPacketType', () {
      test('returns measurement type', () {
        final packet = Uint8List.fromList([0x01, 0, 0, 0, 0, 0, 0, 0]);
        expect(protocol.getPacketType(packet), DistoXPacketType.measurement);
      });

      test('returns calibration accel type', () {
        final packet = Uint8List.fromList([0x02, 0, 0, 0, 0, 0, 0, 0]);
        expect(protocol.getPacketType(packet), DistoXPacketType.calibrationAccel);
      });

      test('returns calibration mag type', () {
        final packet = Uint8List.fromList([0x03, 0, 0, 0, 0, 0, 0, 0]);
        expect(protocol.getPacketType(packet), DistoXPacketType.calibrationMag);
      });

      test('returns memory reply type', () {
        final packet = Uint8List.fromList([0x38, 0, 0, 0, 0, 0, 0, 0]);
        expect(protocol.getPacketType(packet), DistoXPacketType.memoryReply);
      });

      test('returns null for empty packet', () {
        expect(protocol.getPacketType(Uint8List(0)), isNull);
      });
    });

    group('buildReadMemoryCommand', () {
      test('builds correct command', () {
        final cmd = protocol.buildReadMemoryCommand(0x1234);
        expect(cmd.length, 3);
        expect(cmd[0], 0x38); // read command
        expect(cmd[1], 0x34); // address low byte
        expect(cmd[2], 0x12); // address high byte
      });
    });

    group('buildWriteMemoryCommand', () {
      test('builds correct command', () {
        final cmd = protocol.buildWriteMemoryCommand(0x1234, [0xAA, 0xBB, 0xCC, 0xDD]);
        expect(cmd.length, 7);
        expect(cmd[0], 0x39); // write command
        expect(cmd[1], 0x34); // address low byte
        expect(cmd[2], 0x12); // address high byte
        expect(cmd[3], 0xAA); // data byte 0
        expect(cmd[4], 0xBB); // data byte 1
        expect(cmd[5], 0xCC); // data byte 2
        expect(cmd[6], 0xDD); // data byte 3
      });

      test('throws for wrong data length', () {
        expect(
          () => protocol.buildWriteMemoryCommand(0x1234, [0xAA, 0xBB]),
          throwsArgumentError,
        );
      });
    });

    group('mode commands', () {
      test('buildStartCalibrationCommand returns correct byte', () {
        final cmd = protocol.buildStartCalibrationCommand();
        expect(cmd, [0x30]); // DistoXCommand.startCalibration = 0x30
      });

      test('buildStopCalibrationCommand returns correct byte', () {
        final cmd = protocol.buildStopCalibrationCommand();
        expect(cmd, [0x31]); // DistoXCommand.stopCalibration = 0x31
      });

      test('buildStartSilentModeCommand returns correct byte', () {
        final cmd = protocol.buildStartSilentModeCommand();
        expect(cmd, [0x33]);
      });

      test('buildStopSilentModeCommand returns correct byte', () {
        final cmd = protocol.buildStopSilentModeCommand();
        expect(cmd, [0x32]);
      });
    });

    group('reset', () {
      test('clears duplicate detection state', () {
        final packet1 = Uint8List.fromList([
          0x01,
          0xE8, 0x03,
          0x00, 0x40,
          0x00, 0x20,
          0x00,
        ]);

        final first = protocol.parseMeasurementPacket(packet1);
        expect(first, isNotNull);

        // Duplicate should be rejected
        final second = protocol.parseMeasurementPacket(packet1);
        expect(second, isNull);

        // Reset and try again
        protocol.reset();
        final third = protocol.parseMeasurementPacket(packet1);
        expect(third, isNotNull);
      });
    });
  });

  group('parseMemoryReply', () {
    test('parses valid reply', () {
      final packet = Uint8List.fromList([
        0x38, // type
        0x34, 0x12, // address: 0x1234
        0xAA, 0xBB, 0xCC, 0xDD, // data
        0x00, // unused
      ]);

      final reply = parseMemoryReply(packet);
      expect(reply, isNotNull);
      expect(reply!.address, 0x1234);
      expect(reply.data, [0xAA, 0xBB, 0xCC, 0xDD]);
    });

    test('returns null for wrong length', () {
      final packet = Uint8List.fromList([0x38, 0x00, 0x00]);
      expect(parseMemoryReply(packet), isNull);
    });

    test('returns null for wrong type', () {
      final packet = Uint8List.fromList([
        0x01, // measurement type, not memory reply
        0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00,
      ]);
      expect(parseMemoryReply(packet), isNull);
    });
  });
}
