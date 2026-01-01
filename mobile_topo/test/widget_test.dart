import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/data/local_cave_repository.dart';
import 'package:mobile_topo/main.dart';

void main() {
  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectionState()),
        Provider<CaveRepository>(create: (_) => LocalCaveRepository()),
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
