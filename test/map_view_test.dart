import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/services/screen_density.dart';
import 'package:mobile_topo/views/map_view.dart';

void main() {
  testWidgets('zooming in is not limited', (tester) async {
    final now = DateTime(2026);
    final section = Section(
      id: 'section',
      name: 'Section',
      survey: const Survey(
        stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
        referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
      ),
      createdAt: now,
      modifiedAt: now,
    );
    final cave = Cave(
      id: 'cave',
      name: 'Cave',
      sections: [section],
      createdAt: now,
      modifiedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => SelectionState()..selectSection(cave, section)),
          // A typical phone: 160 dp per inch
          Provider.value(value: const ScreenDensity(6.3)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MapView()),
        ),
      ),
    );

    // Each scroll step zooms in by 10%; 80 steps go far past the former
    // limit of 200 px/m
    final center = tester.getCenter(find.byType(CustomPaint).last);
    for (var i = 0; i < 80; i++) {
      await tester.sendEventToBinding(PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -10),
      ));
    }
    await tester.pump();

    expect(find.textContaining('1:0.'), findsOneWidget);
  });
}
