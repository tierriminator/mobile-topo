import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/series_range.dart';
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
      Cave? inCave,
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
                context, inCave ?? cave, tripToEdit ?? trip,
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

  group('reserved series', () {
    Finder fields(String label) => find.widgetWithText(TextField, label);

    /// Scrolls the page until [finder] is built and on screen
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 100,
          scrollable: find.byType(Scrollable).first);
      // Built may still be just below the screen
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> addRange(WidgetTester tester) async {
      await reveal(tester, find.text('Add range'));
      await tester.tap(find.text('Add range'));
      await tester.pumpAndSettle();
    }

    testWidgets('a range added starts after the highest series in use',
        (tester) async {
      final edited = await editAndLeave(tester, () => addRange(tester));
      expect(edited?.reservedSeries, const [SeriesRange(2)]);
    });

    testWidgets('a further range starts after the ranges so far',
        (tester) async {
      final edited = await editAndLeave(tester, () async {
        await addRange(tester);
        await tester.enterText(fields('To').first, '9');
        await addRange(tester);
      });
      expect(edited?.reservedSeries,
          const [SeriesRange(2, 9), SeriesRange(10)]);
    });

    testWidgets('shows the series the next new series gets', (tester) async {
      await open(tester);
      await reveal(tester, find.text('Next new series: 2'));
      expect(find.text('Next new series: 2'), findsOneWidget);
      await addRange(tester);
      await tester.enterText(fields('From').first, '30');
      await tester.pump();
      await reveal(tester, find.text('Next new series: 30'));
      expect(find.text('Next new series: 30'), findsOneWidget);
    });

    testWidgets('invalid ranges are shown as such and stored anyway',
        (tester) async {
      final edited = await editAndLeave(tester, () async {
        await addRange(tester);
        await addRange(tester);
        await tester.pump();
        expect(find.text('Only the last range can be open, not 2–'),
            findsOneWidget);
        await tester.enterText(fields('To').first, '1');
        await tester.pump();
        expect(find.text('The range 2–1 ends before it starts'),
            findsOneWidget);
      });
      expect(edited?.reservedSeries,
          const [SeriesRange(2, 1), SeriesRange(3)]);
    });

    testWidgets('a range without a first series is left out',
        (tester) async {
      final edited = await editAndLeave(tester, () async {
        await addRange(tester);
        await tester.enterText(fields('From').first, '');
        await tester.enterText(fields('To').first, '5');
        await tester.pump();
        expect(find.text('Enter a series'), findsOneWidget);
      });
      expect(edited, isNull);
    });

    /// Opens the page for [tripToEdit], or else [trip], in a cave where
    /// [trip] started series 2 and trip "other", which reserves the series
    /// 5 to 9, started series 3
    Future<Future<Trip?>> openWithOtherTrip(WidgetTester tester,
        {Trip? tripToEdit}) {
      final other = Trip(
          id: 'other',
          date: DateTime(2026, 10, 9),
          comment: 'Team B',
          createdAt: DateTime(2026),
          reservedSeries: const [SeriesRange(5, 9)]);
      final section = cave.sections.single;
      final withSeries = section.copyWith(
          survey: section.survey.copyWith(stretches: [
        ...section.survey.stretches,
        const MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0,
            tripId: 't'),
        const MeasuredDistance(Point(1, 2), Point(3, 0), 0, 0, 0,
            tripId: 'other'),
      ]));
      return open(tester,
          tripToEdit: tripToEdit,
          inCave: cave
              .copyWith(trips: [trip, other]).replaceSection(withSeries));
    }

    /// Enters [first] to [last] as a new range and returns what is shown
    /// as wrong with it
    Future<String?> rangeError(WidgetTester tester, String first,
        [String last = '']) async {
      await addRange(tester);
      await tester.enterText(fields('From').last, first);
      await tester.enterText(fields('To').last, last);
      await tester.pump();
      final texts = find.byWidgetPredicate((w) =>
          w is Text &&
          w.style?.color ==
              Theme.of(tester.element(find.byType(ListView))).colorScheme.error);
      return texts.evaluate().map((e) => (e.widget as Text).data).firstOrNull;
    }

    testWidgets('a range cannot overlap another trip\'s', (tester) async {
      await openWithOtherTrip(tester);
      expect(await rangeError(tester, '9', '12'),
          startsWith('The range 9–12 overlaps 5–9, reserved by'));
    });

    testWidgets('a range cannot hold a series another trip started',
        (tester) async {
      await openWithOtherTrip(tester);
      expect(await rangeError(tester, '3', '4'),
          startsWith('The range 3–4 holds series 3, started on'));
    });

    testWidgets('a range can hold the series the trip started',
        (tester) async {
      await openWithOtherTrip(tester);
      expect(await rangeError(tester, '1', '2'), isNull);
    });

    testWidgets('an open range may start anywhere, even on other trips',
        (tester) async {
      await openWithOtherTrip(tester);
      expect(await rangeError(tester, '1'), isNull);
    });

    testWidgets('shows a series of the trip outside its closed ranges',
        (tester) async {
      await openWithOtherTrip(tester,
          tripToEdit:
              trip.copyWith(reservedSeries: const [SeriesRange(10, 12)]));
      const text = 'Series 2 was started outside the reserved series';
      await reveal(tester, find.text(text));
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('shows a series of the trip below its open range',
        (tester) async {
      await openWithOtherTrip(tester,
          tripToEdit: trip.copyWith(reservedSeries: const [SeriesRange(3)]));
      const text = 'Series 2 was started outside the reserved series';
      await reveal(tester, find.text(text));
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('a removed range is no longer reserved', (tester) async {
      final result = await open(tester,
          tripToEdit: trip.copyWith(reservedSeries: const [SeriesRange(5)]));
      await reveal(tester, find.byTooltip('Remove range'));
      await tester.tap(find.byTooltip('Remove range'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final edited = await result;
      expect(edited, isNotNull);
      expect(edited!.reservedSeries, isEmpty);
    });
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

  group('automatic declination', () {
    final autoTrip = trip.copyWith(autoDeclination: true);

    testWidgets('shows the computed declination instead of the field',
        (tester) async {
      await open(tester, tripToEdit: autoTrip);
      // The cave has no position, so it is computed at the Hölloch: 3.7°
      // against true north, 2.7° against Swiss grid north
      expect(find.text('2.7°'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Declination correction'),
          findsNothing);
    });

    testWidgets('switching it off starts from the computed declination',
        (tester) async {
      final result = await open(tester, tripToEdit: autoTrip);
      await tester.tap(find.text('Automatic declination'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '2.7'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final edited = await result;
      expect(edited?.autoDeclination, isFalse);
      expect(edited?.declination, 2.7);
    });

    testWidgets('switching it on keeps the manual declination',
        (tester) async {
      final result =
          await open(tester, tripToEdit: trip.copyWith(declination: 1.5));
      await tester.tap(find.text('Automatic declination'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      final edited = await result;
      expect(edited?.autoDeclination, isTrue);
      expect(edited?.declination, 1.5);
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
    // The focused comment field would keep scrolling itself into view
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Delete'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('the page stays open if the trip is not deleted',
      (tester) async {
    await open(tester, onDelete: () async => false);
    await tester.scrollUntilVisible(find.text('Delete'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsOneWidget);
  });
}
