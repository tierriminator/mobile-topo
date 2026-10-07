import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/views/sketch_view.dart';

class _NoopCaveRepository implements CaveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'a section without a reference point is placed via the rest of the cave',
      (tester) async {
    final now = DateTime(2026);
    final entrance = Section(
      id: 'entrance',
      name: 'Entrance',
      survey: const Survey(
        stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
        referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
      ),
      createdAt: now,
      modifiedAt: now,
    );
    final continuation = Section(
      id: 'continuation',
      name: 'Continuation',
      survey: const Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(1, 2), 4, 180, 0)],
        referencePoints: [],
      ),
      createdAt: now,
      modifiedAt: now,
    );
    final cave = Cave(
      id: 'cave',
      name: 'Cave',
      sections: [entrance, continuation],
      createdAt: now,
      modifiedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => SelectionState()..selectSection(cave, continuation)),
          Provider<CaveRepository>.value(value: _NoopCaveRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SketchView()),
        ),
      ),
    );

    expect(find.text('No survey data yet'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
