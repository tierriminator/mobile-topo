import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/distox_service.dart';

/// Adapter whose data stream is a broadcast stream, like the platform channel
class _FakeBluetoothAdapter implements BluetoothAdapter {
  final data = StreamController<Uint8List>.broadcast();
  final sent = <Uint8List>[];

  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> send(Uint8List bytes) async => sent.add(bytes);

  @override
  Stream<Uint8List> get dataStream => data.stream;

  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a reconnect does not process each packet more than once', () async {
    final adapter = _FakeBluetoothAdapter();
    final service = DistoXService(SettingsController(), adapter);
    const device = DistoXDevice(name: 'DistoX', address: '00:11');

    await service.connect(device);
    await service.connect(device);

    // Measurement packet taken from a real device log
    adapter.data
        .add(Uint8List.fromList([0x01, 0x3b, 0x06, 0xc1, 0xd5, 0xb5, 0x3a, 0x2c]));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.sent, hasLength(1));
  });
}
