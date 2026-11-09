import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/distox_framing.dart';
import 'package:mobile_topo/services/distox_protocol.dart';

/// `data:`, the payload length, the payload and a line break
List<int> _wrapped(List<int> payload) =>
    [0x64, 0x61, 0x74, 0x61, 0x3a, payload.length, ...payload, 0x0d, 0x0a];

// Measurement packet taken from a real device log, and a vector packet
const _measurement = [0x01, 0x3b, 0x06, 0xc1, 0xd5, 0xb5, 0x3a, 0x2c];
const _vector = [0x04, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70];

void main() {
  group('ClassicFraming', () {
    test('joins bytes into 8-byte packets', () {
      final framing = ClassicFraming();

      expect(framing.receive(Uint8List.fromList(_measurement.sublist(0, 5))),
          isEmpty);
      final packets = framing.receive(Uint8List.fromList(
          [..._measurement.sublist(5), ..._vector, 0x01]));

      expect(packets, [_measurement, _vector]);
    });

    test('acknowledges data packets with their sequence bit', () {
      final framing = ClassicFraming();

      expect(framing.acknowledge(Uint8List.fromList(_measurement)), [0x55]);
      expect(framing.acknowledge(Uint8List.fromList([0x84, 0, 0, 0, 0, 0, 0, 0])),
          [0xd5]);
      expect(framing.acknowledge(Uint8List.fromList([0x38, 0, 0, 0, 0, 0, 0, 0])),
          isNull);
    });

    test('sends commands as they are', () {
      final command = DistoXProtocol().buildReadMemoryCommand(0x8010);

      expect(ClassicFraming().encode(command), command);
    });
  });

  group('BleFraming', () {
    test('splits a shot into its two DistoX2 packets', () {
      final packets = BleFraming()
          .receive(Uint8List.fromList([0x01, ..._measurement, ..._vector]));

      expect(packets, [_measurement, _vector]);
    });

    test('splits a calibration shot into its two DistoX2 packets', () {
      const accel = [0x82, 1, 2, 3, 4, 5, 6, 7];
      const mag = [0x83, 8, 9, 10, 11, 12, 13, 7];

      final packets =
          BleFraming().receive(Uint8List.fromList([0x02, ...accel, ...mag]));

      expect(packets, [accel, mag]);
    });

    test('acknowledges a shot once, wrapped', () {
      final framing = BleFraming();
      final packets = framing.receive(Uint8List.fromList(
          [0x01, 0x80 | _measurement[0], ..._measurement.sublist(1), ..._vector]));

      expect(framing.acknowledge(packets[0]), _wrapped([0xd5]));
      expect(framing.acknowledge(packets[1]), isNull);
    });

    test('turns a memory reply into a DistoX2 one', () {
      final packets = BleFraming().receive(
          Uint8List.fromList([0x3d, 0x10, 0x80, 0xaa, 0xbb, 0xcc, 0xdd]));

      final reply = parseMemoryReply(packets.single)!;
      expect(reply.address, 0x8010);
      expect(reply.data, [0xaa, 0xbb, 0xcc, 0xdd]);
    });

    test('ignores incomplete and unknown notifications', () {
      final framing = BleFraming();

      expect(framing.receive(Uint8List.fromList([0x01, 1, 2, 3])), isEmpty);
      expect(framing.receive(Uint8List.fromList([0x7f, 1, 2, 3])), isEmpty);
      expect(framing.receive(Uint8List(0)), isEmpty);
    });

    test('wraps single byte commands', () {
      final command = DistoXProtocol().buildStartCalibrationCommand();

      expect(BleFraming().encode(command), _wrapped([0x31]));
    });

    test('reads memory four bytes at a time', () {
      final command = DistoXProtocol().buildReadMemoryCommand(0x8014);

      expect(BleFraming().encode(command), _wrapped([0x3d, 0x14, 0x80, 4]));
    });

    test('writes memory four bytes at a time', () {
      final command =
          DistoXProtocol().buildWriteMemoryCommand(0x8014, [1, 2, 3, 4]);

      expect(BleFraming().encode(command),
          _wrapped([0x3e, 0x14, 0x80, 4, 1, 2, 3, 4]));
    });
  });
}
