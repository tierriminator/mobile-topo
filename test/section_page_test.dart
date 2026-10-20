import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/views/section_page.dart';

void main() {
  final day = DateTime(2026, 3, 1);
  Trip trip(String id) => Trip(id: id, date: day, createdAt: day);

  /// 10 m down a 30° slope on trip a and 4 m level with a splay on trip b:
  /// 14 m long and 5 m high, with 3 stations on 2 trips
  final section = Section(
    id: 's',
    name: 'Section',
    survey: const Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 10, 0, -30, tripId: 'a'),
        MeasuredDistance(Point(1, 1), Point(1, 2), 4, 90, 0, tripId: 'b'),
        MeasuredDistance(Point(1, 2), null, 2, 0, 0, tripId: 'b'),
      ],
      referencePoints: [],
    ),
    createdAt: day,
    modifiedAt: day,
  );
  final cave = Cave(
    id: 'cave',
    name: 'Cave',
    sections: [section],
    trips: [trip('a'), trip('b'), trip('unused')],
    createdAt: day,
    modifiedAt: day,
  );

  /// Opens the page for the section with [settings] and returns the pending
  /// result of editSection
  Future<Future<String?>> open(WidgetTester tester,
      {bool isSelected = false,
      VoidCallback? onSelect,
      Future<bool> Function()? onDelete,
      Settings settings = const Settings()}) async {
    late Future<String?> result;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => SettingsController(settings),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = editSection(context, cave, section,
                isSelected: isSelected,
                onSelect: onSelect,
                onDelete: onDelete),
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

  /// Taps the edit button of the title and enters [name]
  Future<void> editName(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AppBar), matching: find.byType(TextField)),
        name);
  }

  testWidgets('shows the length, height, stations and trips',
      (tester) async {
    await open(tester);
    expect(find.text('14.0 m'), findsOneWidget);
    expect(find.text('5.0 m'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
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

  testWidgets('returns the edited name', (tester) async {
    final result = await open(tester);
    await editName(tester, ' Main passage ');
    await leave(tester);
    expect(await result, 'Main passage');
  });

  testWidgets('an empty name keeps the old one', (tester) async {
    final result = await open(tester);
    await editName(tester, ' ');
    await leave(tester);
    expect(await result, isNull);
  });

  testWidgets('opening the section closes the page and keeps edits',
      (tester) async {
    var selected = 0;
    final result = await open(tester, onSelect: () => selected++);
    await editName(tester, 'Main passage');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(find.byType(SectionPage), findsNothing);
    expect(await result, 'Main passage');
  });

  testWidgets('the open section cannot be opened again', (tester) async {
    await open(tester, isSelected: true, onSelect: () {});
    expect(find.text('Open'), findsNothing);
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Open section'),
        matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
  });

  testWidgets('deleting closes the page and discards edits', (tester) async {
    final result = await open(tester, onDelete: () async => true);
    await editName(tester, 'Main passage');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(SectionPage), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('without onDelete there is no delete button', (tester) async {
    await open(tester);
    expect(find.text('Delete'), findsNothing);
  });
}
