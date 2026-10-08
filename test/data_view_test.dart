import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/controllers/view_navigation.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/services/measurement_service.dart';
import 'package:mobile_topo/views/data_view.dart';

/// Repository that only records saves
class _InMemoryCaveRepository implements CaveRepository {
  @override
  Future<void> saveSection(String caveId, Section section) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026);

  Section section(String id, [Survey? survey]) => Section(
        id: id,
        name: id,
        survey: survey ?? const Survey(stretches: [], referencePoints: []),
        createdAt: now,
        modifiedAt: now,
      );

  Cave cave(List<Section> sections) => Cave(
        id: 'cave',
        name: 'Cave',
        sections: sections,
        createdAt: now,
        modifiedAt: now,
      );

  Future<void> pumpDataView(
    WidgetTester tester,
    SelectionState selectionState,
    MeasurementService measurementService, {
    ViewNavigation? navigation,
    SettingsController? settings,
  }) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: selectionState),
          ChangeNotifierProvider.value(value: measurementService),
          ChangeNotifierProvider.value(value: navigation ?? ViewNavigation()),
          ChangeNotifierProvider.value(value: settings ?? SettingsController()),
          Provider<CaveRepository>.value(value: _InMemoryCaveRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DataView()),
        ),
      ),
    );
  }

  /// Long-presses the first cell showing [cellText], or the last one if
  /// [last] is set
  Future<void> openMenuOn(WidgetTester tester, String cellText,
      {bool last = false}) async {
    final cells = find.text(cellText);
    await tester.longPress(last ? cells.last : cells.first);
    await tester.pumpAndSettle();
  }

  Future<void> startHereOn(WidgetTester tester, String cellText,
      {bool last = false}) async {
    await openMenuOn(tester, cellText, last: last);
    await tester.tap(find.text('Start here'));
    await tester.pumpAndSettle();
  }

  testWidgets('measurements go to the section selected when they arrive',
      (tester) async {
    final first = section('first');
    final second = section('second');
    final c = cave([first, second]);

    final selectionState = SelectionState()..selectSection(c, first);
    final measurementService = MeasurementService(SettingsController());
    await pumpDataView(tester, selectionState, measurementService);

    selectionState.selectSection(c, second);
    await tester.pumpAndSettle();

    measurementService.addMeasurement(
      distance: 3.0,
      azimuth: 45.0,
      inclination: 0.0,
      isStretch: false,
    );
    await tester.pumpAndSettle();

    expect(selectionState.selectedSection!.id, 'second');
    expect(selectionState.selectedSection!.survey.stretches, hasLength(1));
  });

  testWidgets('measurements are assigned to the active trip', (tester) async {
    final s = section('s');
    final c = cave([s])
        .addTrip(Trip(id: 'old', date: now, createdAt: now))
        .addTrip(Trip(id: 'trip', date: now, createdAt: now));

    final selectionState = SelectionState()..selectSection(c, s);
    final measurementService = MeasurementService(SettingsController());
    await pumpDataView(tester, selectionState, measurementService);

    measurementService.addMeasurement(
      distance: 3.0,
      azimuth: 45.0,
      inclination: 0.0,
      isStretch: false,
    );
    await tester.pumpAndSettle();

    final stretches = selectionState.selectedSection!.survey.stretches;
    expect(stretches.single.tripId, 'trip');
  });

  testWidgets('measurements keep changes made to the section in other views',
      (tester) async {
    final s = section('s');
    final c = cave([s]);
    final selectionState = SelectionState()..selectSection(c, s);
    final measurementService = MeasurementService(SettingsController());
    await pumpDataView(tester, selectionState, measurementService);

    void measure() => measurementService.addMeasurement(
          distance: 3.0,
          azimuth: 45.0,
          inclination: 0.0,
          isStretch: false,
        );

    measure();
    await tester.pumpAndSettle();
    // A stroke drawn in the sketch view between two measurements
    const stroke = Stroke(
        points: [Offset.zero, Offset(1, 1)], color: SketchColors.black);
    selectionState.changeSection(
        's',
        (section) => section.copyWith(
            outlineSketch: section.outlineSketch.addStroke(stroke)));
    measure();
    await tester.pumpAndSettle();

    final latest = selectionState.selectedSection!;
    expect(latest.survey.stretches, hasLength(2));
    expect(latest.outlineSketch.strokes, [stroke]);
  });

  group('showing a station in another view', () {
    Future<void> choose(WidgetTester tester, String cellText, String item) async {
      await openMenuOn(tester, cellText);
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, item));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the pressed station, or else the row\'s',
        (tester) async {
      final s = section(
        's',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 3, 0, 0)],
          referencePoints: [],
        ),
      );
      final navigation = ViewNavigation();
      await pumpDataView(tester, SelectionState()..selectSection(cave([s]), s),
          MeasurementService(SettingsController()),
          navigation: navigation);

      await choose(tester, '1.0', 'View in Map');
      expect(navigation.take({NavigationTarget.map})?.station,
          const Point(1, 0));

      // The distance holds no station, so the row's station is shown
      await choose(tester, '3.00', 'View in Side View');
      expect(navigation.take({NavigationTarget.sideView})?.station,
          const Point(1, 1));
    });

    testWidgets('stations of other sections cannot be shown in the sketch',
        (tester) async {
      final first = section(
        'first',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 3, 0, 0)],
          referencePoints: [],
        ),
      );
      final second = section(
        'second',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 1), Point(1, 2), 4, 0, 0)],
          referencePoints: [],
        ),
      );
      final c = cave([first, second]);
      await pumpDataView(tester, SelectionState()..selectSection(c, second),
          MeasurementService(SettingsController()));

      await openMenuOn(tester, '1.0');

      PopupMenuItem<String> item(String label) => tester
          .widget(find.widgetWithText(PopupMenuItem<String>, label));
      expect(item('View in Map').enabled, isTrue);
      expect(item('View in Outline').enabled, isFalse);
      expect(item('View in Side View').enabled, isFalse);
    });
  });

  group('showing a station from another view', () {
    testWidgets('scrolls to the shot leading to it', (tester) async {
      // A long series, so the start is out of view at first
      final s = section(
        's',
        Survey(
          stretches: [
            for (var i = 0; i < 60; i++)
              MeasuredDistance(Point(1, i), Point(1, i + 1), 3, 0, 0),
          ],
          referencePoints: const [],
        ),
      );
      final navigation = ViewNavigation();
      await pumpDataView(tester, SelectionState()..selectSection(cave([s]), s),
          MeasurementService(SettingsController()),
          navigation: navigation);
      await tester.pumpAndSettle();
      expect(find.text('1.0').hitTestable(), findsNothing);

      navigation.show(const Point(1, 1), NavigationTarget.data);
      await tester.pumpAndSettle();

      expect(find.text('1.0').hitTestable(), findsOneWidget);
      expect(navigation.pendingTarget, isNull);
    });

    testWidgets('selects its reference point if no shot leads to it',
        (tester) async {
      final s = section(
        's',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 3, 0, 0)],
          referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
        ),
      );
      final navigation = ViewNavigation();
      await pumpDataView(tester, SelectionState()..selectSection(cave([s]), s),
          MeasurementService(SettingsController()),
          navigation: navigation);

      navigation.show(const Point(1, 0), NavigationTarget.data);
      await tester.pumpAndSettle();

      expect(
          tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected,
          [false, true]);
    });
  });

  group('whole cave table', () {
    final previous = section(
      'previous',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
        referencePoints: [],
      ),
    );

    testWidgets('a new section continues from the last row of the cave',
        (tester) async {
      final current = section('current');
      final selectionState = SelectionState()
        ..selectSection(cave([previous, current]), current);
      final measurementService = MeasurementService(
          SettingsController(const Settings(smartModeEnabled: false)));
      await pumpDataView(tester, selectionState, measurementService);

      expect(find.text('Current: 1.1'), findsOneWidget);

      measurementService.addMeasurement(
          distance: 2, azimuth: 0, inclination: 0, isStretch: false);
      await tester.pumpAndSettle();
      measurementService.addMeasurement(
          distance: 3, azimuth: 0, inclination: 0, isStretch: true);
      await tester.pumpAndSettle();

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches[0].from, const Point(1, 1));
      expect(stretches[0].to, isNull);
      expect(stretches[1].from, const Point(1, 1));
      expect(stretches[1].to, const Point(1, 2));
      expect(find.text('Current: 1.2'), findsOneWidget);
    });

    testWidgets('a smart mode triple becomes a shot to the next station',
        (tester) async {
      final current = section('current');
      final selectionState = SelectionState()
        ..selectSection(cave([previous, current]), current);
      final measurementService = MeasurementService(SettingsController());
      await pumpDataView(tester, selectionState, measurementService);

      for (var i = 0; i < 3; i++) {
        measurementService.addMeasurement(
            distance: 4, azimuth: 30, inclination: 5, isStretch: true);
        await tester.pumpAndSettle();
      }

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(1));
      expect(stretches.single.from, const Point(1, 1));
      expect(stretches.single.to, const Point(1, 2));
      expect(measurementService.currentStation, const Point(1, 2));
    });

    testWidgets('rows of other sections are shown but cannot be edited',
        (tester) async {
      final current = section(
        'current',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 1), Point(1, 2), 6, 90, 0)],
          referencePoints: [],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([previous, current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      expect(find.text('5.00'), findsOneWidget);

      await openMenuOn(tester, '1.0');
      expect(find.text('Start here'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Insert above'), findsNothing);
    });
  });

  group('cell menus', () {
    final current = section(
      'current',
      const Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), null, 2, 0, 0),
        ],
        referencePoints: [],
      ),
    );

    Future<void> pump(WidgetTester tester) => pumpDataView(
          tester,
          SelectionState()..selectSection(cave([current]), current),
          MeasurementService(SettingsController()),
        );

    testWidgets('offer no station actions on a measurement cell',
        (tester) async {
      await pump(tester);

      await openMenuOn(tester, '5.00');

      expect(find.text('Start here'), findsNothing);
      expect(find.text('Continue here'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('offer no station actions on an empty To cell',
        (tester) async {
      await pump(tester);

      await openMenuOn(tester, '');

      expect(find.text('Start here'), findsNothing);
      expect(find.text('Continue here'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('Start Here', () {
    // Another section of the cave already uses series 2
    final other = section(
      'other',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0)],
        referencePoints: [],
      ),
    );

    testWidgets('on a To cell starts a new series at that station',
        (tester) async {
      final current = section(
        'current',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
          referencePoints: [],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([other, current]), current);
      final measurementService = MeasurementService(SettingsController());
      await pumpDataView(tester, selectionState, measurementService);

      // The other section's row lists 1.1 as From, this section's as To
      await startHereOn(tester, '1.1', last: true);

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(2));
      final dummy = stretches.last;
      expect(dummy.from, const Point(1, 1));
      expect(dummy.to, const Point(3, 0));
      expect(dummy.distance, 0);
      expect(measurementService.currentStation, const Point(3, 0));
    });

    testWidgets('on a From cell starts a new series at that station',
        (tester) async {
      final current = section(
        'current',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
          referencePoints: [],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([other, current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      await startHereOn(tester, '1.0');

      final dummy = selectionState.selectedSection!.survey.stretches.last;
      expect(dummy.from, const Point(1, 0));
      expect(dummy.to, const Point(3, 0));
    });

    testWidgets('on a reference point starts a new series at its station',
        (tester) async {
      final current = section(
        'current',
        const Survey(
          stretches: [],
          referencePoints: [ReferencePoint(Point(1, 0), 600, 200, 1500)],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([other, current]), current);
      final measurementService = MeasurementService(SettingsController());
      await pumpDataView(tester, selectionState, measurementService);

      await tester.tap(find.byTooltip('Reference Points'));
      await tester.pumpAndSettle();
      await startHereOn(tester, '1.0');

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(1));
      expect(stretches.single.from, const Point(1, 0));
      expect(stretches.single.to, const Point(3, 0));
      expect(measurementService.currentStation, const Point(3, 0));
    });
  });

  group('Flip, To survey shot and Renumber', () {
    final current = section(
      'current',
      const Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), null, 7, 0, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 6, 90, 0),
        ],
        referencePoints: [],
      ),
    );

    Future<void> choose(WidgetTester tester, String cellText, String item) async {
      await openMenuOn(tester, cellText);
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('turn a cross section into a shot and renumber after it',
        (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      await choose(tester, '7.00', 'To survey shot');

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches[1].from, const Point(1, 1));
      expect(stretches[1].to, const Point(1, 2));
      expect(stretches[2].from, const Point(1, 2));
      expect(stretches[2].to, const Point(1, 3));
    });

    testWidgets('renumber the rows after an edited station', (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));
      selectionState.changeSection(
          'current',
          (s) => s.copyWith(
              survey: s.survey.updateStretchAt(
                  0, s.survey.stretches[0].copyWith(to: const Point(1, 5)))));
      await tester.pumpAndSettle();

      await choose(tester, '5.00', 'Renumber');

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches[1].from, const Point(1, 5));
      expect(stretches[2].from, const Point(1, 5));
      expect(stretches[2].to, const Point(1, 6));
    });

    testWidgets('flip a survey shot between forward and backward',
        (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      await choose(tester, '5.00', 'Flip');

      final flipped = selectionState.selectedSection!.survey.stretches[0];
      expect(flipped.from, const Point(1, 1));
      expect(flipped.to, const Point(1, 0));
    });

    testWidgets('offer only the action matching the row', (tester) async {
      await pumpDataView(
          tester,
          SelectionState()..selectSection(cave([current]), current),
          MeasurementService(SettingsController()));

      await openMenuOn(tester, '5.00');
      expect(find.text('Flip'), findsOneWidget);
      expect(find.text('To survey shot'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await openMenuOn(tester, '7.00');
      expect(find.text('Flip'), findsNothing);
      expect(find.text('To survey shot'), findsOneWidget);
    });

    testWidgets('turn a cross section into a backward shot if set',
        (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      await pumpDataView(
        tester,
        selectionState,
        MeasurementService(SettingsController()),
        settings: SettingsController(
            const Settings(shotDirection: ShotDirection.backward)),
      );

      await choose(tester, '7.00', 'To survey shot');

      final shot = selectionState.selectedSection!.survey.stretches[1];
      expect(shot.from, const Point(1, 2));
      expect(shot.to, const Point(1, 1));
    });

    testWidgets('are not offered on rows of other sections', (tester) async {
      final later = section('later');
      await pumpDataView(
          tester,
          SelectionState()..selectSection(cave([current, later]), later),
          MeasurementService(SettingsController()));

      await openMenuOn(tester, '5.00');
      expect(find.text('Flip'), findsNothing);
      expect(find.text('Renumber'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await openMenuOn(tester, '7.00');
      expect(find.text('To survey shot'), findsNothing);
    });
  });

  group('Continue Here', () {
    // Series 1 runs 1.0 -> 1.1 -> 1.2, then branch 2 starts at 1.1
    final current = section(
      'current',
      const Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 6, 90, 0),
          MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0),
          MeasuredDistance(Point(2, 0), Point(2, 1), 7, 0, 0),
        ],
        referencePoints: [],
      ),
    );

    testWidgets(
        'at the last station of a series appends a dummy cross section there',
        (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      final measurementService = MeasurementService(SettingsController());
      await pumpDataView(tester, selectionState, measurementService);

      await openMenuOn(tester, '1.2');
      await tester.tap(find.text('Continue here'));
      await tester.pumpAndSettle();

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(5));
      final dummy = stretches.last;
      expect(dummy.from, const Point(1, 2));
      expect(dummy.to, isNull);
      expect(dummy.distance, 0);
      expect(measurementService.currentStation, const Point(1, 2));
      expect(measurementService.nextStation, const Point(1, 3));
    });

    testWidgets('is offered on the From cell of a backward shot ending a series',
        (tester) async {
      final backward = section(
        'backward',
        const Survey(
          stretches: [
            MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
            MeasuredDistance(Point(1, 2), Point(1, 1), 6, 270, 0),
          ],
          referencePoints: [],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([backward]), backward);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      await openMenuOn(tester, '1.2');
      await tester.tap(find.text('Continue here'));
      await tester.pumpAndSettle();

      final dummy = selectionState.selectedSection!.survey.stretches.last;
      expect(dummy.from, const Point(1, 2));
      expect(dummy.to, isNull);
    });

    testWidgets('is not offered in the middle of a series', (tester) async {
      final selectionState = SelectionState()
        ..selectSection(cave([current]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      await openMenuOn(tester, '1.0');

      expect(find.text('Start here'), findsOneWidget);
      expect(find.text('Continue here'), findsNothing);
    });

    testWidgets('is not offered where another section continues the series',
        (tester) async {
      final later = section(
        'later',
        const Survey(
          stretches: [MeasuredDistance(Point(1, 2), Point(1, 3), 8, 90, 0)],
          referencePoints: [],
        ),
      );
      final selectionState = SelectionState()
        ..selectSection(cave([current, later]), current);
      await pumpDataView(
          tester, selectionState, MeasurementService(SettingsController()));

      // 1.2 appears as From in the later section and as To in this one
      await openMenuOn(tester, '1.2', last: true);

      expect(find.text('Start here'), findsOneWidget);
      expect(find.text('Continue here'), findsNothing);
    });
  });
}
