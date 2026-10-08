import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/views/trip_page.dart';

void main() {
  final trip = Trip(id: 't', date: DateTime(2026, 10, 8), createdAt: DateTime(2026));

  // Two survey shots and a cross section on the trip, one shot on another
  final cave = Cave(
    id: 'cave',
    name: 'Cave',
    sections: [
      Section(
        id: 's',
        name: 'Section',
        survey: const Survey(
          stretches: [
            MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0,
                tripId: 't'),
            MeasuredDistance(Point(1, 1), null, 2, 90, 0, tripId: 't'),
            MeasuredDistance(Point(1, 1), Point(1, 2), 7.5, 0, 0,
                tripId: 't'),
            MeasuredDistance(Point(1, 2), Point(1, 3), 9, 0, 0,
                tripId: 'other'),
          ],
          referencePoints: [],
        ),
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      ),
    ],
    trips: [trip],
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  /// Opens the page for [tripToEdit], or else [trip], with [settings] and
  /// returns the pending result of editTrip
  Future<Future<Trip?>> open(WidgetTester tester,
      {Future<bool> Function()? onDelete,
      Trip? tripToEdit,
      Settings settings = const Settings()}) async {
    late Future<Trip?> result;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => SettingsController(settings),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = editTrip(
                context, cave, tripToEdit ?? trip,
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

  /// Opens the page for [trip] and returns the result of editTrip once the
  /// page is left through the back button after [edit]
  Future<Trip?> editAndLeave(
      WidgetTester tester, Future<void> Function() edit) async {
    final result = await open(tester);
    await edit();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('leaving the page returns the edited trip', (tester) async {
    final edited = await editAndLeave(tester, () async {
      await tester.enterText(
          find.widgetWithText(TextField, 'Declination correction'), '-2.5');
      await tester.enterText(
          find.widgetWithText(TextField, 'Comment'), 'Anna, Ben');
    });

    expect(edited?.id, 't');
    expect(edited?.declination, -2.5);
    expect(edited?.comment, 'Anna, Ben');
    expect(edited?.createdAt, trip.createdAt);
  });

  testWidgets('leaving the page unchanged returns null', (tester) async {
    expect(await editAndLeave(tester, () async {}), isNull);
  });

  testWidgets('the page shows the length surveyed on the trip',
      (tester) async {
    await open(tester);
    // Only the trip's survey shots count, not its cross section
    expect(find.text('12.5 m'), findsOneWidget);
  });

  testWidgets('the surveyed length is shown in the length unit',
      (tester) async {
    await open(tester, settings: const Settings(lengthUnit: LengthUnit.feet));
    expect(find.text('41.0 ft'), findsOneWidget);
  });

  testWidgets('the page shows the trip ID', (tester) async {
    await open(tester);
    expect(find.text('ID: t'), findsOneWidget);
  });

  group('make active', () {
    // Not the cave's active trip, which is [trip]
    Trip inactive(DateTime date) =>
        Trip(id: 'other', date: date, createdAt: DateTime(2000));

    testWidgets('the active trip shows that it is active', (tester) async {
      await open(tester);
      expect(find.text('Make active'), findsNothing);
      expect(find.text('Active trip'), findsOneWidget);
    });

    testWidgets('a trip of today is made active right away', (tester) async {
      final result = await open(tester, tripToEdit: inactive(DateTime.now()));
      await tester.tap(find.text('Make active'));
      await tester.pumpAndSettle();
      expect(find.text('Active trip'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect((await result)?.activatedAt, isNotNull);
    });

    testWidgets('a trip of another day is made active after confirming',
        (tester) async {
      final result = await open(tester, tripToEdit: inactive(DateTime(2000)));
      await tester.tap(find.text('Make active'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sat, Jan 1, 2000, not today'),
          findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Make active')));
      await tester.pumpAndSettle();
      expect(find.text('Active trip'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect((await result)?.activatedAt, isNotNull);
    });

    testWidgets('cancelling the confirmation leaves the trip inactive',
        (tester) async {
      final result = await open(tester, tripToEdit: inactive(DateTime(2000)));
      await tester.tap(find.text('Make active'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Make active'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });

  testWidgets('the date shows the year if it is not the current one',
      (tester) async {
    await open(tester,
        tripToEdit:
            Trip(id: 't', date: DateTime(2000), createdAt: DateTime(2000)));
    expect(find.text('Sat, Jan 1, 2000'), findsOneWidget);
  });

  group('tripLabel', () {
    /// The label of [labelled] as the app shows it
    Future<String> label(WidgetTester tester, Trip labelled) async {
      late String result;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          result = tripLabel(context, labelled);
          return const SizedBox();
        }),
      ));
      return result;
    }

    final year = DateTime.now().year;

    testWidgets('leaves out the current year', (tester) async {
      final labelled = Trip(
          id: 't', date: DateTime(year, 3, 4), createdAt: DateTime(year));
      final text = await label(tester, labelled);
      expect(text, contains('Mar 4'));
      expect(text, isNot(contains('$year')));
    });

    testWidgets('shows other years', (tester) async {
      final labelled = Trip(
          id: 't', date: DateTime(2000, 3, 4), createdAt: DateTime(2000));
      expect(await label(tester, labelled), 'Sat, Mar 4, 2000');
    });

    testWidgets('adds the first line of the comment', (tester) async {
      final labelled = Trip(
          id: 't',
          date: DateTime(2000, 3, 4),
          comment: 'Upper series\nwith Anna',
          createdAt: DateTime(2000));
      expect(await label(tester, labelled), 'Sat, Mar 4, 2000 – Upper series');
    });
  });

  group('in grad', () {
    const grad = Settings(angleUnit: AngleUnit.grad);
    final tripInGrad = trip.copyWith(declination: 0.9);

    testWidgets('the declination is shown in grad', (tester) async {
      await open(tester, tripToEdit: tripInGrad, settings: grad);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
    });

    testWidgets('an entered declination is stored in degrees',
        (tester) async {
      final result =
          await open(tester, tripToEdit: tripInGrad, settings: grad);
      await tester.enterText(
          find.widgetWithText(TextField, 'Declination correction'), '2');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect((await result)?.declination, closeTo(1.8, 1e-9));
    });

    testWidgets('an unchanged declination is kept as it is', (tester) async {
      // 0.95° shows rounded to 1.056g; leaving it must not store 1.056g
      final result = await open(tester,
          tripToEdit: trip.copyWith(declination: 0.95), settings: grad);
      expect(find.text('1.056'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });
  });

  testWidgets('without onDelete there is no delete button', (tester) async {
    await open(tester);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('deleting closes the page and discards edits', (tester) async {
    final result = await open(tester, onDelete: () async => true);
    await tester.enterText(
        find.widgetWithText(TextField, 'Comment'), 'Anna, Ben');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('the page stays open if the trip is not deleted',
      (tester) async {
    await open(tester, onDelete: () async => false);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsOneWidget);
  });
}
