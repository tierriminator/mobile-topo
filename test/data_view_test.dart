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

  Section section(String id) => Section(
        id: id,
        name: id,
        survey: const Survey(stretches: [], referencePoints: []),
        createdAt: now,
        modifiedAt: now,
      );

  testWidgets('measurements go to the section selected when they arrive',
      (tester) async {
    final first = section('first');
    final second = section('second');
    final cave = Cave(
      id: 'cave',
      name: 'Cave',
      sections: [first, second],
      createdAt: now,
      modifiedAt: now,
    );

    final selectionState = SelectionState()..selectSection(cave, first);
    final measurementService = MeasurementService(SettingsController());

    await tester.pumpWidget(
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

    selectionState.selectSection(cave, second);
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
}
