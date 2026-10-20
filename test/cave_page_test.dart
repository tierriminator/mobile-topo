import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/geo_position.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/views/cave_page.dart';

void main() {
  // 10 m down a 30° slope and 4 m level: 14 m long, 5 m high
  final cave = Cave(
    id: 'cave',
    name: 'Cave',
    sections: [
      Section(
        id: 's',
        name: 'Section',
        survey: const Survey(
          stretches: [
            MeasuredDistance(Point(1, 0), Point(1, 1), 10, 0, -30),
            MeasuredDistance(Point(1, 1), Point(1, 2), 4, 90, 0),
          ],
          referencePoints: [],
        ),
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      ),
    ],
    location: const GeoPosition(46.9, 8.8),
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  /// Opens the page for [cave] with [settings] and returns the pending
  /// result of editCave
  Future<Future<CaveEdit?>> open(WidgetTester tester,
      {Future<bool> Function()? onDelete,
      Settings settings = const Settings()}) async {
    late Future<CaveEdit?> result;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => SettingsController(settings),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                result = editCave(context, cave, onDelete: onDelete),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// Taps the edit button of the title and enters [name]
  Future<void> editName(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AppBar), matching: find.byType(TextField)),
        name);
  }

  testWidgets('the title shows the name with an edit button',
      (tester) async {
    await open(tester);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Cave')),
        findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await editName(tester, 'Hölloch');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Hölloch'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('finishing with an empty name shows the old one',
      (tester) async {
    await open(tester);
    await editName(tester, ' ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Cave'), findsOneWidget);
  });

  testWidgets('shows the length and height of the cave', (tester) async {
    await open(tester);
    expect(find.text('14.0 m'), findsOneWidget);
    expect(find.text('5.0 m'), findsOneWidget);
  });

  testWidgets('shows the figures in the length unit', (tester) async {
    await open(tester, settings: const Settings(lengthUnit: LengthUnit.feet));
    expect(find.text('45.9 ft'), findsOneWidget);
    expect(find.text('16.4 ft'), findsOneWidget);
  });

  testWidgets('leaving the page unchanged returns null', (tester) async {
    final result = await open(tester);
    await leave(tester);
    expect(await result, isNull);
  });

  testWidgets('returns the edited name and location', (tester) async {
    final result = await open(tester);
    await editName(tester, ' Hölloch ');
    await tester.enterText(field('Latitude'), '46.97');
    await tester.enterText(field('Longitude'), '8.79');
    await leave(tester);

    final edited = await result;
    expect(edited?.name, 'Hölloch');
    expect(edited?.location, const GeoPosition(46.97, 8.79));
  });

  testWidgets('emptying the location fields removes it', (tester) async {
    final result = await open(tester);
    await tester.enterText(field('Latitude'), '');
    await tester.enterText(field('Longitude'), '');
    await leave(tester);

    final edited = await result;
    expect(edited, isNotNull);
    expect(edited?.location, isNull);
  });

  testWidgets('an invalid location is shown and not taken', (tester) async {
    final result = await open(tester);
    await tester.enterText(field('Latitude'), '95');
    await tester.pump();
    expect(find.textContaining('Enter a latitude from -90 to 90'),
        findsOneWidget);
    await leave(tester);

    expect(await result, isNull);
  });

  testWidgets('an empty name keeps the old one', (tester) async {
    final result = await open(tester);
    await editName(tester, ' ');
    await leave(tester);
    expect(await result, isNull);
  });

  testWidgets('deleting closes the page and discards edits', (tester) async {
    final result = await open(tester, onDelete: () async => true);
    await editName(tester, 'Hölloch');
    await tester.scrollUntilVisible(find.text('Delete'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(CavePage), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('without onDelete there is no delete button', (tester) async {
    await open(tester);
    expect(find.text('Delete'), findsNothing);
  });
}
