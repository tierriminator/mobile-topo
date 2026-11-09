import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/distox_protocol.dart';
import 'package:mobile_topo/services/distox_service.dart';

/// Adapter whose data stream is a broadcast stream, like the platform channel
class _FakeBluetoothAdapter implements BluetoothAdapter {
  final data = StreamController<Uint8List>.broadcast();
  final sent = <Uint8List>[];

  @override
  Future<void> connect(DistoXDevice device) async {}

  @override
  Future<void> send(Uint8List bytes) async => sent.add(bytes);

  @override
  Stream<Uint8List> get dataStream => data.stream;

  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Measurement packet taken from a real device log
const _measurement = [0x01, 0x3b, 0x06, 0xc1, 0xd5, 0xb5, 0x3a, 0x2c];

/// `data:`, the payload length, the payload and a line break
List<int> _wrapped(List<int> payload) =>
    [...'data:'.codeUnits, payload.length, ...payload, 0x0d, 0x0a];

void main() {
  test('a reconnect does not process each packet more than once', () async {
    final adapter = _FakeBluetoothAdapter();
    final service = DistoXService(SettingsController(), adapter);
    const device = DistoXDevice(name: 'DistoX', address: '00:11');

    await service.connect(device);
    await service.connect(device);

    adapter.data.add(Uint8List.fromList(_measurement));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.sent, hasLength(1));
  });

  group('DistoX BLE', () {
    const device = DistoXDevice(name: 'DistoX-BLE', address: 'AB', ble: true);

    test('receives a shot and acknowledges it once', () async {
      final adapter = _FakeBluetoothAdapter();
      final service = DistoXService(SettingsController(), adapter);
      final measurements = <DistoXMeasurement>[];
      service.onMeasurement = measurements.add;
      await service.connect(device);

      adapter.data.add(Uint8List.fromList(
          [0x01, ..._measurement, 0x04, 0, 0, 0, 0, 0, 0, 0]));
      await Future<void>.delayed(Duration.zero);

      expect(measurements, hasLength(1));
      expect(measurements.single.distance, closeTo(1.595, 1e-9));
      expect(adapter.sent, [_wrapped([0x55])]);
    });

    test('sends commands wrapped and passes memory replies on', () async {
      final adapter = _FakeBluetoothAdapter();
      final service = DistoXService(SettingsController(), adapter);
      final replies = <DistoXMemoryReply>[];
      service.onMemoryReply = replies.add;
      await service.connect(device);

      await service
          .sendCommand(DistoXProtocol().buildReadMemoryCommand(0x8010));
      adapter.data.add(
          Uint8List.fromList([0x3d, 0x10, 0x80, 0xaa, 0xbb, 0xcc, 0xdd]));
      await Future<void>.delayed(Duration.zero);

      expect(adapter.sent, [_wrapped([0x3d, 0x10, 0x80, 4])]);
      expect(replies.single.address, 0x8010);
      expect(replies.single.data, [0xaa, 0xbb, 0xcc, 0xdd]);
    });
  });
}
