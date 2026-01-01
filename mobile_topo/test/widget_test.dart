import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/data/local_cave_repository.dart';
import 'package:mobile_topo/data/settings_repository.dart';
import 'package:mobile_topo/main.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/services/distox_service.dart';
import 'package:mobile_topo/services/measurement_service.dart';

/// Mock settings repository for testing (no SharedPreferences dependency)
class MockSettingsRepository extends SettingsRepository {
  Settings _settings = const Settings();

  @override
  Future<Settings> load() async => _settings;

  @override
  Future<void> save(Settings settings) async {
    _settings = settings;
  }
}

void main() {
  Widget createTestApp() {
    final settingsController = SettingsController();
    final distoXService = DistoXService();
    final measurementService = MeasurementService(settingsController);
    measurementService.connectDistoX(distoXService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectionState()),
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: distoXService),
        ChangeNotifierProvider.value(value: measurementService),
        Provider<CaveRepository>(create: (_) => LocalCaveRepository()),
        Provider<SettingsRepository>(create: (_) => MockSettingsRepository()),
      ],
      child: const MyApp(),
    );
  }

  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());

    // Verify the app bar shows the default view title
    expect(find.text('Data'), findsWidgets);

    // Verify bottom navigation items exist (Data is active so shows filled icon)
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('Navigation switches views', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());

    // Tap on Map tab
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();

    // Verify Map view is shown (shows empty state when no section selected)
    expect(find.text('Select a section in Explorer'), findsOneWidget);

    // Tap on Sketch tab
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pump();

    // Verify Sketch view is shown (shows empty state when no section selected)
    expect(find.text('Select a section in Explorer'), findsOneWidget);
  });
}
