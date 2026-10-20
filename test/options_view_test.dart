import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/settings_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/coordinate_system.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/services/distox_service.dart';
import 'package:mobile_topo/views/options_view.dart';

import 'widget_test.dart' show MockBluetoothAdapter, MockSettingsRepository;

void main() {
  group('Settings', () {
    test('new caves are in the Swiss grid by default', () {
      expect(const Settings().defaultCoordinateSystem, CoordinateSystem.swiss);
      expect(Settings.fromJson(const {}).defaultCoordinateSystem,
          CoordinateSystem.swiss);
    });

    test('the default coordinate system survives a JSON round trip', () {
      const settings =
          Settings(defaultCoordinateSystem: Utm(33, south: true));
      expect(Settings.fromJson(settings.toJson()).defaultCoordinateSystem,
          const Utm(33, south: true));
    });
  });

  group('default coordinate system', () {
    Future<(SettingsController, MockSettingsRepository)> pump(
        WidgetTester tester) async {
      final controller = SettingsController();
      final repository = MockSettingsRepository();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider(
              create: (_) => DistoXService(controller, MockBluetoothAdapter())),
          Provider<SettingsRepository>.value(value: repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OptionsView()),
        ),
      ));
      await tester.pumpAndSettle();
      final tile = find.text('Default Coordinate System');
      await tester.scrollUntilVisible(tile, 100,
          scrollable: find.byType(Scrollable).first);
      return (controller, repository);
    }

    testWidgets('is shown in the units section', (tester) async {
      await pump(tester);
      expect(find.text('Swiss grid (LV95/LV03)'), findsOneWidget);
    });

    testWidgets('can be set to a UTM zone', (tester) async {
      final (controller, repository) = await pump(tester);
      await tester.tap(find.text('Default Coordinate System'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      await tester.tap(find.descendant(
          of: dialog, matching: find.text('Swiss grid (LV95/LV03)')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTM').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('South'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.defaultCoordinateSystem, const Utm(32, south: true));
      expect((await repository.load()).defaultCoordinateSystem,
          const Utm(32, south: true));
      expect(find.text('UTM 32S'), findsOneWidget);
    });

    testWidgets('cancelling keeps it', (tester) async {
      final (controller, _) = await pump(tester);
      await tester.tap(find.text('Default Coordinate System'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.defaultCoordinateSystem, CoordinateSystem.swiss);
    });
  });
}
