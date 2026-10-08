import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/screen_density.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mobile_topo/display');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('uses the natively measured density', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'logicalPixelsPerMm');
      return 6.25;
    });

    expect((await ScreenDensity.load()).logicalPixelsPerMm, 6.25);
  });

  test('falls back to a nominal density if the screen size is unknown',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    // The tests run on a desktop host: 96 logical pixels per inch
    expect((await ScreenDensity.load()).logicalPixelsPerMm,
        closeTo(96 / 25.4, 1e-9));
  });

  test('falls back to a nominal density without a native measurement',
      () async {
    expect((await ScreenDensity.load()).logicalPixelsPerMm,
        closeTo(96 / 25.4, 1e-9));
  });
}
