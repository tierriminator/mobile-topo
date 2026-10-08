import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/data/settings_repository.dart';
import 'package:mobile_topo/main.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/services/bluetooth_adapter.dart';
import 'package:mobile_topo/services/distox_service.dart';
import 'package:mobile_topo/services/measurement_service.dart';
import 'package:mobile_topo/services/screen_density.dart';
import 'package:mobile_topo/views/trip_page.dart';
import 'package:mobile_topo/views/widgets/trip_bar.dart';

/// Adapter that connects successfully and stays connected without sending
/// data
class _ConnectingBluetoothAdapter implements BluetoothAdapter {
  // Never closed: a closed data stream counts as a disconnect
  final _data = StreamController<Uint8List>.broadcast();

  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> send(Uint8List bytes) async {}

  @override
  Stream<Uint8List> get dataStream => _data.stream;

  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository holding a single cave in memory
class _SingleCaveRepository implements CaveRepository {
  final Cave cave;
  final savedTrips = <Trip>[];

  _SingleCaveRepository(this.cave);

  @override
  Future<List<CaveSummary>> listCaves() async => [
        CaveSummary(
          id: cave.id,
          name: cave.name,
          createdAt: cave.createdAt,
          modifiedAt: cave.modifiedAt,
          sectionCount: cave.sections.length,
        ),
      ];

  @override
  Future<Cave?> getCave(String caveId) async => cave;

  @override
  Future<void> saveTrip(String caveId, Trip trip) async => savedTrips.add(trip);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSettingsRepository extends SettingsRepository {}

void main() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  Cave caveWith(List<Trip> trips) => Cave(
        id: 'cave',
        name: 'Cave',
        sections: [
          Section(
            id: 's',
            name: 'Section',
            survey: const Survey(stretches: [], referencePoints: []),
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        trips: trips,
        createdAt: now,
        modifiedAt: now,
      );

  final oldTrip = Trip(
      id: 'old', date: yesterday, comment: 'Anna, Ben', createdAt: yesterday);

  /// Pumps the app with [cave] selected; returns the DistoX service. With
  /// [connected], the DistoX is connected before the app is shown, as with
  /// auto-connect.
  Future<DistoXService> pumpApp(WidgetTester tester, Cave cave,
      {bool connected = false}) async {
    final settings = SettingsController();
    final distoX = DistoXService(settings, _ConnectingBluetoothAdapter());
    if (connected) {
      await distoX
          .connect(const DistoXDevice(name: 'DistoX', address: '00:11'));
    }
    final selection = SelectionState()
      ..selectSection(cave, cave.sections.first);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: selection),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: distoX),
        ChangeNotifierProvider.value(value: MeasurementService(settings)),
        Provider<CaveRepository>.value(value: _SingleCaveRepository(cave)),
        Provider<SettingsRepository>.value(value: _NoopSettingsRepository()),
        Provider.value(value: const ScreenDensity(6.3)),
      ],
      child: const MyApp(),
    ));
    await tester.pumpAndSettle();
    return distoX;
  }

  Future<void> connect(WidgetTester tester, DistoXService distoX) async {
    await distoX
        .connect(const DistoXDevice(name: 'DistoX', address: '00:11'));
    await tester.pumpAndSettle();
  }

  test('a trip is from a day before only on an earlier calendar day', () {
    final trip = Trip(
        id: 't', date: DateTime(2026, 10, 8, 23, 59), createdAt: DateTime(2026));
    expect(trip.isFromDayBefore(DateTime(2026, 10, 8, 0, 1)), isFalse);
    expect(trip.isFromDayBefore(DateTime(2026, 10, 9, 0, 1)), isTrue);
  });

  testWidgets('a current trip shows no trip bar', (tester) async {
    final today = Trip(id: 't', date: now, comment: 'Carla', createdAt: now);
    final distoX = await pumpApp(tester, caveWith([today]));

    expect(find.byType(TripBar), findsNothing);

    // A current trip needs no check when connecting
    await connect(tester, distoX);
    expect(find.text('Check the trip'), findsNothing);
  });

  testWidgets('the trip bar warns about a missing trip', (tester) async {
    await pumpApp(tester, caveWith([]));
    expect(find.text('No trip – tap to start one'), findsOneWidget);
  });

  testWidgets('connecting with an old trip asks; keeping it hides the bar',
      (tester) async {
    final distoX = await pumpApp(tester, caveWith([oldTrip]));
    expect(find.textContaining('Old trip: '), findsOneWidget);

    await connect(tester, distoX);
    expect(find.text('Check the trip'), findsOneWidget);

    await tester.tap(find.text('Keep trip'));
    await tester.pumpAndSettle();

    expect(find.text('Check the trip'), findsNothing);
    expect(find.byType(TripBar), findsNothing);
  });

  testWidgets('a connection made before the app is shown is checked too',
      (tester) async {
    await pumpApp(tester, caveWith([oldTrip]), connected: true);
    expect(find.text('Check the trip'), findsOneWidget);
  });

  testWidgets('choosing a new trip opens it in the explorer', (tester) async {
    final distoX = await pumpApp(tester, caveWith([oldTrip]));

    await connect(tester, distoX);
    await tester.tap(find.text('New trip'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The new trip is today's, so the warning is gone
    expect(find.text('Trips'), findsOneWidget);
    expect(find.byType(TripBar), findsNothing);
  });
}
