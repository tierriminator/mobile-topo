import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/bluetooth_adapter_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mobile_topo/bluetooth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late bool permitted;
  late bool poweredOn;

  setUp(() {
    calls = [];
    permitted = true;
    poweredOn = false;
    messenger.setMockStreamHandler(
        const EventChannel('mobile_topo/bluetooth/state'),
        MockStreamHandler.inline(onListen: (_, _) {}));
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'ensurePermissions':
          return permitted;
        case 'isPoweredOn':
          return poweredOn;
        case 'requestEnable':
        case 'connect':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('AndroidBluetoothAdapter', () {
    test('asks for the permissions before asking to enable Bluetooth',
        () async {
      final enabled = await AndroidBluetoothAdapter().requestEnable();

      expect(enabled, isTrue);
      expect(calls, ['ensurePermissions', 'requestEnable']);
    });

    test('does not ask to enable Bluetooth without the permissions', () async {
      permitted = false;

      final enabled = await AndroidBluetoothAdapter().requestEnable();

      expect(enabled, isFalse);
      expect(calls, isNot(contains('requestEnable')));
    });

    test('does not connect while Bluetooth is disabled', () async {
      await expectLater(
          AndroidBluetoothAdapter().connect('00:11:22:33:44:55'),
          throwsException);
      expect(calls, isNot(contains('connect')));
    });

    test('connects while Bluetooth is enabled', () async {
      poweredOn = true;

      await AndroidBluetoothAdapter().connect('00:11:22:33:44:55');

      expect(calls, contains('connect'));
    });
  });
}
