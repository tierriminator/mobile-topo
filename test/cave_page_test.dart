import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/views/cave_page.dart';

void main() {
  /// A cave of 10 m down a 30° slope and 4 m level, 14 m long and 5 m high,
  /// with [referencePoints]
  Cave caveWith(List<ReferencePoint> referencePoints) => Cave(
        id: 'cave',
        name: 'Cave',
        sections: [
          Section(
            id: 's',
            name: 'Section',
            survey: Survey(
              stretches: const [
                MeasuredDistance(Point(1, 0), Point(1, 1), 10, 0, -30),
                MeasuredDistance(Point(1, 1), Point(1, 2), 4, 90, 0),
              ],
              referencePoints: referencePoints,
            ),
            createdAt: DateTime(2026),
            modifiedAt: DateTime(2026),
          ),
        ],
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      );

  const entrance = ReferencePoint(Point(1, 0), 2709400, 1204300, 650);

  /// Opens the page for [cave], by default one with the [entrance], with
  /// [settings] and returns the pending result of editCave
  Future<Future<String?>> open(WidgetTester tester,
      {Cave? cave,
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
            onPressed: () => result = editCave(
                context, cave ?? caveWith(const [entrance]),
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

  testWidgets('the title shows the name with an edit button',
      (tester) async {
    await open(tester);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Cave')),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);

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

  group('coordinates', () {
    testWidgets('are those of the first reference point', (tester) async {
      const later = ReferencePoint(Point(1, 2), 2600000, 1200000, 500);
      await open(tester, cave: caveWith(const [entrance, later]));
      expect(find.text('Coordinates of 1.0'), findsOneWidget);
      expect(find.text('2709400.0 m'), findsOneWidget);
      expect(find.text('1204300.0 m'), findsOneWidget);
      expect(find.text('650.0 m'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('are not editable', (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('missing are warned about, showing the Hölloch\'s',
        (tester) async {
      await open(tester, cave: caveWith(const []));
      expect(find.text('Coordinates of the Hölloch (default)'),
          findsOneWidget);
      expect(find.text('2702698.0 m'), findsOneWidget);
      expect(find.text('1203724.0 m'), findsOneWidget);
      expect(find.text('The cave has no reference point yet.'),
          findsOneWidget);
    });

    testWidgets('outside the Swiss grid are warned about', (tester) async {
      await open(tester,
          cave: caveWith(const [ReferencePoint(Point(1, 0), 0, 0, 0)]));
      expect(find.text('Coordinates of the Hölloch (default)'),
          findsOneWidget);
      expect(find.textContaining('Reference point 1.0 is not in the Swiss'),
          findsOneWidget);
    });

    testWidgets('a warning leads to the reference points', (tester) async {
      var shown = 0;
      late Future<String?> result;
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => SettingsController(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = editCave(context, caveWith(const []),
                  onShowReferencePoints: () => shown++),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await editName(tester, 'Hölloch');

      await tester.tap(find.text('Reference points'));
      await tester.pumpAndSettle();

      expect(shown, 1);
      expect(find.byType(CavePage), findsNothing);
      // The page keeps its edits when leaving this way
      expect(await result, 'Hölloch');
    });

    testWidgets('usable ones offer no way to the reference points',
        (tester) async {
      await open(tester);
      expect(find.text('Reference points'), findsNothing);
    });
  });

  testWidgets('leaving the page unchanged returns null', (tester) async {
    final result = await open(tester);
    await leave(tester);
    expect(await result, isNull);
  });

  testWidgets('returns the edited name', (tester) async {
    final result = await open(tester);
    await editName(tester, ' Hölloch ');
    await leave(tester);
    expect(await result, 'Hölloch');
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
