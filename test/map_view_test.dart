import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/view_navigation.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/services/screen_density.dart';
import 'package:mobile_topo/views/map_view.dart';

/// Shows the map of a cave with a single shot from 1.0 to 1.1, 5 m east
Future<void> _pumpMapView(WidgetTester tester,
    {ViewNavigation? navigation}) async {
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
        ChangeNotifierProvider.value(value: navigation ?? ViewNavigation()),
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
}

void main() {
  testWidgets('zooming in is not limited', (tester) async {
    await _pumpMapView(tester);

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

  testWidgets('a station shown from another view is centred and selected',
      (tester) async {
    final navigation = ViewNavigation();
    await _pumpMapView(tester, navigation: navigation);

    navigation.show(const Point(1, 1), NavigationTarget.map);
    await tester.pump();

    expect(find.text('Station 1.1: E 5.0m, N 0.0m, Alt 0.0m'), findsOneWidget);
    expect(navigation.pendingTarget, isNull);
    // Now in the centre, where tapping keeps it selected
    final center = tester.getCenter(find.byType(CustomPaint).last);
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Station 1.1: E 5.0m, N 0.0m, Alt 0.0m'), findsOneWidget);
  });

  testWidgets('requests for other views are left alone', (tester) async {
    final navigation = ViewNavigation();
    await _pumpMapView(tester, navigation: navigation);

    navigation.show(const Point(1, 1), NavigationTarget.data);
    await tester.pump();

    expect(navigation.pendingTarget, NavigationTarget.data);
    expect(find.textContaining('Station'), findsNothing);
  });
}
