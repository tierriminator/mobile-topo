import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/main.dart';

void main() {
  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

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
    await tester.pumpWidget(const MyApp());

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
