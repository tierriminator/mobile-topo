import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/views/widgets/trip_picker.dart';

void main() {
  // One trip on October 1, two on October 5; the last one is active
  final single = Trip(
      id: 'single',
      date: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1));
  final upper = Trip(
      id: 'upper',
      date: DateTime(2026, 10, 5),
      comment: 'Upper series\nwith Anna',
      createdAt: DateTime(2026, 10, 5, 9));
  final lower = Trip(
      id: 'lower',
      date: DateTime(2026, 10, 5),
      createdAt: DateTime(2026, 10, 5, 9));
  final cave = Cave(
    id: 'cave',
    name: 'Cave',
    trips: [single, upper, lower],
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  /// Opens the picker with [currentTripId] and returns its pending result
  Future<Future<Trip?>> open(WidgetTester tester, String currentTripId) async {
    late Future<Trip?> result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              result = pickTrip(context, cave, currentTripId: currentTripId),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tapAndSettle(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('the current trip\'s day is preselected', (tester) async {
    final result = await open(tester, 'single');
    await tapAndSettle(tester, 'OK');
    expect(await result, same(single));
  });

  testWidgets('a day with one trip picks that trip', (tester) async {
    final result = await open(tester, 'upper');
    await tapAndSettle(tester, '1');
    await tapAndSettle(tester, 'OK');
    expect(await result, same(single));
  });

  testWidgets('days without a trip cannot be picked', (tester) async {
    final result = await open(tester, 'single');
    await tapAndSettle(tester, '3');
    await tapAndSettle(tester, 'OK');
    expect(await result, same(single));
  });

  testWidgets('a day with several trips lists them by ID, newest first',
      (tester) async {
    final result = await open(tester, 'single');
    await tapAndSettle(tester, '5');
    await tapAndSettle(tester, 'OK');

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles, ['lower', 'upper']);
    expect(find.text('(active)'), findsOneWidget);
    expect(find.text('Upper series'), findsOneWidget);

    await tapAndSettle(tester, 'upper');
    expect(await result, same(upper));
  });

  testWidgets('the current trip is highlighted in the list', (tester) async {
    await open(tester, 'upper');
    await tapAndSettle(tester, 'OK');

    final selected = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => t.selected)
        .toList();
    expect(selected, [false, true]);
  });

  testWidgets('cancelling picks no trip', (tester) async {
    final result = await open(tester, 'single');
    await tapAndSettle(tester, 'Cancel');
    expect(await result, isNull);
  });
}
