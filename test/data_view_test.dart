import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
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
    MeasurementService measurementService,
  ) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: selectionState),
          ChangeNotifierProvider.value(value: measurementService),
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

  Future<void> startHereOn(WidgetTester tester, String cellText) async {
    await tester.longPress(find.text(cellText).first);
    await tester.pumpAndSettle();
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

  group('Start Here', () {
    // Another section of the cave already uses series 2
    final other = section(
      'other',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(2, 0), 0, 0, 0)],
        referencePoints: [],
      ),
    );

    testWidgets('on a survey shot starts a new series at its To station',
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

      await startHereOn(tester, '5.00');

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(2));
      final dummy = stretches.last;
      expect(dummy.from, const Point(1, 1));
      expect(dummy.to, const Point(3, 0));
      expect(dummy.distance, 0);
      expect(measurementService.currentStation, const Point(3, 0));
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
      await startHereOn(tester, '600');

      final stretches = selectionState.selectedSection!.survey.stretches;
      expect(stretches, hasLength(1));
      expect(stretches.single.from, const Point(1, 0));
      expect(stretches.single.to, const Point(3, 0));
      expect(measurementService.currentStation, const Point(3, 0));
    });
  });
}
