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
import 'package:mobile_topo/models/cross_section.dart';
import 'package:mobile_topo/models/settings.dart';
import 'package:mobile_topo/models/sketch.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/services/screen_density.dart';
import 'package:mobile_topo/views/sketch_view.dart';

/// Records saved sections and supports nothing else
class _RecordingCaveRepository implements CaveRepository {
  final saved = <Section>[];

  @override
  Future<void> saveSection(String caveId, Section section) async =>
      saved.add(section);

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
  CaveRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => SelectionState()..selectSection(cave, section)),
        ChangeNotifierProvider.value(value: settings ?? SettingsController()),
        Provider<CaveRepository>.value(
            value: repository ?? _RecordingCaveRepository()),
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

  testWidgets('a shot is flipped from the station menu in the side view',
      (tester) async {
    final section = _section('section', _singleShot);
    final repository = _RecordingCaveRepository();
    await _pumpSketchView(tester, _cave([section]), section,
        repository: repository);
    await tester.tap(find.byIcon(Icons.terrain));
    await tester.pump();

    // Stations at 0 m and 5 m along, centred at the default 20 px per metre
    final center = tester.getCenter(find.byType(CustomPaint).last);
    await tester.longPressAt(center + const Offset(50, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<VoidCallback>, 'Flip'));
    await tester.pumpAndSettle();

    expect(repository.saved.last.survey.stretches.single.flipped, isTrue);
  });

  testWidgets('a cross section is placed by the tap after choosing it',
      (tester) async {
    final section = _section('section', _singleShot);
    final repository = _RecordingCaveRepository();
    await _pumpSketchView(tester, _cave([section]), section,
        repository: repository);

    // Stations at 0 m and 5 m east, centred at the default 20 px per metre
    final center = tester.getCenter(find.byType(CustomPaint).last);
    await tester.longPressAt(center + const Offset(50, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(
        PopupMenuItem<VoidCallback>, 'Vertical Cross Section'));
    await tester.pumpAndSettle();
    expect(find.text('Tap where to draw the cross section of 1.1'),
        findsOneWidget);

    await tester.tapAt(center + const Offset(0, 100));
    await tester.pump(kDoubleTapTimeout);

    final crossSection =
        repository.saved.last.outlineSketch.crossSections.single;
    expect(crossSection.station, const Point(1, 1));
    expect(crossSection.kind, CrossSectionKind.vertical);
    // 100 px below the centre, which is 2.5 m east of the first station
    expect(crossSection.position, const Offset(2.5, 5));
    expect(find.textContaining('Tap where'), findsNothing);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(repository.saved.last.outlineSketch.crossSections, isEmpty);
  });

  testWidgets('a cross section shows only the section\'s own measurements',
      (tester) async {
    // 1.1 ends the entrance section and starts the continuation; both
    // measured a splay there
    final entrance = _section(
      'entrance',
      const Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
          MeasuredDistance(Point(1, 1), null, 2, 0, 0),
        ],
        referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
      ),
    );
    final continuation = _section(
      'continuation',
      const Survey(
        stretches: [
          MeasuredDistance(Point(1, 1), Point(1, 2), 4, 90, 0),
          MeasuredDistance(Point(1, 1), null, 1, 180, 0),
        ],
        referencePoints: [],
      ),
    ).copyWith(
      outlineSketch: const Sketch(crossSections: [
        CrossSection(
          station: Point(1, 1),
          position: Offset(5, 10),
          kind: CrossSectionKind.vertical,
        ),
      ]),
    );
    await _pumpSketchView(
        tester, _cave([entrance, continuation]), continuation,
        settings: SettingsController(const Settings(showGrid: false)));

    // The shot, the splay at 1.1 and one line in the cross section
    expect(tester.renderObject(find.byType(CustomPaint).last),
        paintsExactlyCountTimes(#drawLine, 3));
  });

  testWidgets('only the side view offers horizontal cross sections',
      (tester) async {
    final section = _section('section', _singleShot);
    await _pumpSketchView(tester, _cave([section]), section);
    final center = tester.getCenter(find.byType(CustomPaint).last);

    await tester.longPressAt(center + const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(find.text('Horizontal Cross Section'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.terrain));
    await tester.pump();
    await tester.longPressAt(center + const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(find.text('Horizontal Cross Section'), findsOneWidget);
  });

  testWidgets('Show All adds the rest of the cave to the outline',
      (tester) async {
    final entrance = _section('entrance', _singleShot);
    final continuation = _section(
      'continuation',
      const Survey(
        stretches: [MeasuredDistance(Point(1, 1), Point(1, 2), 4, 180, 0)],
        referencePoints: [],
      ),
    );
    // Without the grid, the only lines are survey shots
    await _pumpSketchView(
        tester, _cave([entrance, continuation]), continuation,
        settings: SettingsController(const Settings(showGrid: false)));
    final canvas = find.byType(CustomPaint).last;

    expect(tester.renderObject(canvas),
        paintsExactlyCountTimes(#drawLine, 1));

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Show All'));
    await tester.pumpAndSettle();

    expect(tester.renderObject(canvas),
        paintsExactlyCountTimes(#drawLine, 2));
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
