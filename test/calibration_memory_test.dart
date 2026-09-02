import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/calibration_service.dart';
import 'package:mobile_topo/services/distox_service.dart';
import 'package:mobile_topo/utils/matrix_helpers.dart';
import 'package:vector_math/vector_math.dart';

/// Emulates a DistoX's configuration memory over the RFCOMM byte stream.
///
/// The real device answers every read and write command with a memory reply
/// carrying the contents of the addressed four bytes. [dropReplies] makes it
/// swallow the reply for the first N commands it sees for a given address,
/// which is what happens in practice when commands are sent faster than the
/// device can answer them.
class _FakeDistoX implements BluetoothAdapter {
  final _data = StreamController<Uint8List>.broadcast();
  final _state = StreamController<bool>.broadcast();

  /// Contents of 0x8010-0x803F.
  final memory = Uint8List(48);

  /// Commands received, in order.
  final commands = <Uint8List>[];

  /// Number of replies to swallow per address before answering.
  final Map<int, int> dropReplies;

  /// When true, writes land in memory but no reply is ever sent.
  bool silent;

  /// When set, the device writes this byte instead of what was asked, so the
  /// echo does not match. Used to exercise verification.
  int? corruptWritesAt;

  _FakeDistoX({
    Map<int, int>? dropReplies,
    this.silent = false,
    this.corruptWritesAt,
  }) : dropReplies = dropReplies ?? {};

  static const int _readMemory = 0x38;
  static const int _writeMemory = 0x39;
  static const int _base = 0x8010;

  @override
  Future<void> send(Uint8List data) async {
    commands.add(Uint8List.fromList(data));
    if (data.isEmpty) return;

    final op = data[0];
    if (op != _readMemory && op != _writeMemory) return;

    final address = data[1] | (data[2] << 8);
    final offset = address - _base;
    if (offset < 0 || offset + 4 > memory.length) return;

    if (op == _writeMemory) {
      for (int i = 0; i < 4; i++) {
        memory[offset + i] =
            address == corruptWritesAt ? 0x00 : data[3 + i];
      }
    }

    if (silent) return;
    final remaining = dropReplies[address] ?? 0;
    if (remaining > 0) {
      dropReplies[address] = remaining - 1;
      return;
    }

    // Memory reply: type, addr low, addr high, 4 data bytes, unused.
    _data.add(Uint8List.fromList([
      _readMemory,
      address & 0xFF,
      (address >> 8) & 0xFF,
      ...memory.sublist(offset, offset + 4),
      0,
    ]));
  }

  @override
  Stream<Uint8List> get dataStream => _data.stream;
  @override
  Stream<bool> get connectionStateStream => _state.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<bool> requestEnable() async => true;
  @override
  Future<List<DistoXDevice>> getBondedDevices() async => const [];
  @override
  Stream<DistoXDevice> startDiscovery() => const Stream.empty();
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String address) async {}
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() {
    _data.close();
    _state.close();
  }
}

/// Coefficients from a real 56-shot calibration run.
CalibrationCoefficients _coefficients() => CalibrationCoefficients(
      aG: matrix3FromRowMajor([
        0.9789, -0.0190, -0.0001, //
        -0.0140, 0.9945, 0.0141, //
        0.0429, 0.0141, 0.9898, //
      ]),
      bG: Vector3(-0.0139, -0.0065, -0.0046),
      aM: matrix3FromRowMajor([
        1.5637, -0.0289, -0.0146, //
        -0.0004, 1.5709, 0.0399, //
        0.0322, -0.0173, 1.5450, //
      ]),
      bM: Vector3(0.0052, -0.0282, -0.2039),
    );

/// Wire a CalibrationService to a connected DistoXService over [adapter].
Future<CalibrationService> _connect(_FakeDistoX adapter) async {
  final distox = DistoXService(SettingsController(), adapter);
  await distox.connect(const DistoXDevice(name: 'DistoX', address: '00:11'));
  final calibration = CalibrationService(distox);
  distox.onMemoryReply = calibration.onMemoryReply;
  return calibration;
}

void main() {
  group('coefficient memory transfer', () {
    test('writes and verifies all 48 bytes', () async {
      final device = _FakeDistoX();
      final service = await _connect(device);
      final coefficients = _coefficients();

      final ok = await service.writeCoefficientsFor(coefficients);

      expect(ok, isTrue, reason: service.error);
      expect(device.memory, coefficients.toBytes());

      // Twelve writes, one per four byte chunk, each at its own address.
      final writes = device.commands.where((c) => c[0] == 0x39).toList();
      expect(writes.length, 12);
      for (int i = 0; i < 12; i++) {
        final address = writes[i][1] | (writes[i][2] << 8);
        expect(address, CalibrationService.coefficientAddress + i * 4);
      }
    });

    test('retries a chunk whose reply is dropped', () async {
      // The device swallows the first two replies for the third G chunk and
      // the first reply for a M chunk.
      final device = _FakeDistoX(dropReplies: {0x8018: 2, 0x8030: 1});
      final service = await _connect(device);
      final coefficients = _coefficients();

      final ok = await service.writeCoefficientsFor(coefficients);

      expect(ok, isTrue, reason: service.error);
      expect(device.memory, coefficients.toBytes());

      final writes = device.commands.where((c) => c[0] == 0x39).toList();
      // 12 chunks + 2 extra attempts at 0x8018 + 1 extra at 0x8030.
      expect(writes.length, 15);
    });

    test('fails loudly when the device never answers', () async {
      final device = _FakeDistoX(silent: true);
      final service = await _connect(device);

      final ok = await service.writeCoefficientsFor(_coefficients());

      expect(ok, isFalse);
      expect(service.error, contains('0x8010'));
      // Gives up on the first chunk instead of blasting the rest.
      final writes = device.commands.where((c) => c[0] == 0x39).toList();
      expect(writes.length, lessThanOrEqualTo(4));
    });

    test('fails when a write is not echoed back correctly', () async {
      final device = _FakeDistoX(corruptWritesAt: 0x8028);
      final service = await _connect(device);

      final ok = await service.writeCoefficientsFor(_coefficients());

      expect(ok, isFalse);
      expect(service.error, contains('0x8028'));
    });

    test('reads coefficients back by address', () async {
      final device = _FakeDistoX();
      final service = await _connect(device);
      final written = _coefficients();
      expect(await service.writeCoefficientsFor(written), isTrue);

      final read = await service.readCoefficients();

      expect(read, isNotNull);
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(read!.aG.entry(i, j), closeTo(written.aG.entry(i, j), 1e-4));
          expect(read.aM.entry(i, j), closeTo(written.aM.entry(i, j), 1e-4));
        }
      }
      expect(read!.bM.z, closeTo(written.bM.z, 1e-4));
    });

    test('a dropped read reply does not shift the remaining chunks', () async {
      final device = _FakeDistoX();
      final service = await _connect(device);
      final written = _coefficients();
      expect(await service.writeCoefficientsFor(written), isTrue);

      // Lose the reply for one chunk in the middle of the read.
      device.dropReplies[0x8020] = 1;
      final read = await service.readCoefficients();

      expect(read, isNotNull);
      expect(read!.aM.entry(0, 0), closeTo(written.aM.entry(0, 0), 1e-4));
      expect(read.bM.z, closeTo(written.bM.z, 1e-4));
    });
  });
}
