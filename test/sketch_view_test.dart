import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/data/settings_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/services/screen_density.dart';
import 'package:mobile_topo/views/sketch_view.dart';

class _NoopCaveRepository implements CaveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A cave holding the given sections
Cave _cave(List<Section> sections) => Cave(
      id: 'cave',
      name: 'Cave',
      sections: sections,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    );

Section _section(String id, Survey survey) => Section(
      id: id,
      name: id,
      survey: survey,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    );

/// Shows the sketch view with [section] of [cave] selected
Future<void> _pumpSketchView(
  WidgetTester tester,
  Cave cave,
  Section section, {
  SettingsController? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => SelectionState()..selectSection(cave, section)),
        ChangeNotifierProvider.value(value: settings ?? SettingsController()),
        Provider<CaveRepository>.value(value: _NoopCaveRepository()),
        Provider.value(value: SettingsRepository()),
        // A typical phone: 160 dp per inch
        Provider.value(value: const ScreenDensity(6.3)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SketchView()),
      ),
    ),
  );
}

const _singleShot = Survey(
  stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
  referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
);

void main() {
  testWidgets(
      'a section without a reference point is placed via the rest of the cave',
      (tester) async {
    final entrance = _section('entrance', _singleShot);
    final continuation = _section(
      'continuation',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(1, 2), 4, 180, 0)],
        referencePoints: [],
      ),
    );

    await _pumpSketchView(tester, _cave([entrance, continuation]), continuation);

    expect(find.text('No survey data yet'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('zooming in is not limited', (tester) async {
    final section = _section('section', _singleShot);
    await _pumpSketchView(tester, _cave([section]), section);

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

    expect(find.textContaining('Scale: 1:0.'), findsOneWidget);
  });

  testWidgets('tapping a station shows its coordinates', (tester) async {
    final section = _section('section', _singleShot);
    await _pumpSketchView(tester, _cave([section]), section);

    // The view is centred between the stations at 0 m and 5 m east, at the
    // default 20 px per metre
    final center = tester.getCenter(find.byType(CustomPaint).last);
    await tester.tapAt(center + const Offset(50, 0));
    await tester.pump(kDoubleTapTimeout);

    expect(find.text('Station 1.1: E 5.0m, N 0.0m, Alt 0.0m'), findsOneWidget);

    // Tapping away from the stations shows the scale again
    await tester.tapAt(center + const Offset(0, 100));
    await tester.pump(kDoubleTapTimeout);

    expect(find.textContaining('Scale: '), findsOneWidget);
  });

  testWidgets('the grid is toggled from the menu', (tester) async {
    final section = _section('section', _singleShot);
    final settings = SettingsController();
    await _pumpSketchView(tester, _cave([section]), section, settings: settings);
    expect(settings.showGrid, isTrue);

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Show Grid'));
    await tester.pumpAndSettle();

    expect(settings.showGrid, isFalse);
  });
}
