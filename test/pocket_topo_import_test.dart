import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/controllers/settings_controller.dart';
import 'package:mobile_topo/data/cave_repository.dart';
import 'package:mobile_topo/data/settings_repository.dart';
import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/views/explorer_view.dart';

import 'pocket_topo_file_test.dart' show TopWriter, topFile;

/// A picked file held in memory
final class _MemoryFile extends PlatformFile {
  @override
  final String name;
  final Uint8List bytes;

  _MemoryFile(this.name, this.bytes);

  @override
  Uri get uri => Uri.parse('memory:$name');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

/// Picker that returns fixed files
class _FakeFilePicker extends FilePickerPlatform {
  final List<PlatformFile> files;

  _FakeFilePicker(this.files);

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      files;
}

/// Repository holding a single cave in memory, replaced on every save
class _SingleCaveRepository implements CaveRepository {
  Cave cave;
  var saveCount = 0;

  _SingleCaveRepository(this.cave);

  @override
  Future<List<CaveSummary>> listCaves() async => [
        CaveSummary(
          id: cave.id,
          name: cave.name,
          createdAt: cave.createdAt,
          modifiedAt: cave.modifiedAt,
          sectionCount: cave.allSections.length,
        ),
      ];

  @override
  Future<Cave?> getCave(String caveId) async => cave;

  @override
  Future<void> saveCave(Cave cave) async {
    this.cave = cave;
    saveCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSettingsRepository extends SettingsRepository {}

void main() {
  final now = DateTime.now();
  final existingTrip = Trip(id: 'existing', date: now, createdAt: now);

  Future<_SingleCaveRepository> pumpExplorer(
      WidgetTester tester, List<PlatformFile> picked) async {
    FilePickerPlatform.instance = _FakeFilePicker(picked);
    final repository = _SingleCaveRepository(Cave(
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
      trips: [existingTrip],
      createdAt: now,
      modifiedAt: now,
    ));

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectionState()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        Provider<CaveRepository>.value(value: repository),
        Provider<SettingsRepository>.value(value: _NoopSettingsRepository()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ExplorerView()),
      ),
    ));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> importFromMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import PocketTopo Files'));
    await tester.pumpAndSettle();
  }

  testWidgets('imports a file as a new section with its trips',
      (tester) async {
    final bytes = topFile(
      tripCount: 1,
      trips: (w) => w.trip(DateTime(2009, 7, 14), comment: 'Entrance'),
      shotCount: 3,
      shots: (w) {
        w.shot(TopWriter.majorMinor(1, 0), TopWriter.majorMinor(1, 1), 5000,
            0, 0,
            trip: 0);
        w.shot(TopWriter.majorMinor(1, 1), TopWriter.undefined, 1000, 0, 0,
            trip: 0);
        w.shot(TopWriter.undefined, TopWriter.undefined, 1000, 0, 0);
      },
    );
    final repository =
        await pumpExplorer(tester, [_MemoryFile('Hoelloch.TOP', bytes)]);

    await importFromMenu(tester);

    final cave = repository.cave;
    expect(cave.sections.map((s) => s.name), ['Section', 'Hoelloch']);
    final imported = cave.sections.last;
    expect(imported.survey.stretches, hasLength(2));

    final [existing, trip] = cave.trips;
    expect(existing, same(existingTrip));
    expect(trip.comment, 'Entrance');
    expect(imported.survey.stretches.map((s) => s.tripId),
        everyElement(trip.id));
    // The imported trip is older, so the existing one stays active
    expect(cave.activeTrip, same(existingTrip));

    expect(find.text('Hoelloch'), findsOneWidget);
    expect(
        find.text('1 measurement belongs to no station and was left out.'),
        findsOneWidget);
  });

  testWidgets('imports several files, sharing their common trip',
      (tester) async {
    Uint8List fileFrom(int series) => topFile(
          tripCount: 1,
          trips: (w) =>
              w.trip(DateTime(2009, 7, 14, 9 + series), comment: 'Anna'),
          shotCount: 1,
          shots: (w) => w.shot(TopWriter.majorMinor(series, 0),
              TopWriter.majorMinor(series, 1), 5000, 0, 0,
              trip: 0),
        );
    final repository = await pumpExplorer(tester, [
      _MemoryFile('b.top', fileFrom(2)),
      _MemoryFile('notes.txt', Uint8List.fromList([1, 2, 3, 4])),
      _MemoryFile('a.top', fileFrom(1)),
    ]);

    await importFromMenu(tester);

    final cave = repository.cave;
    expect(repository.saveCount, 1);
    expect(cave.sections.map((s) => s.name), ['Section', 'a', 'b']);
    final [_, trip] = cave.trips;
    expect(trip.comment, 'Anna');
    expect(
        [
          for (final s in cave.sections.skip(1))
            s.survey.stretches.single.tripId
        ],
        [trip.id, trip.id]);
    expect(
        find.text('notes.txt could not be imported: Not a PocketTopo file'),
        findsOneWidget);
  });

  testWidgets('reports files that cannot be read and imports nothing',
      (tester) async {
    final repository = await pumpExplorer(
        tester, [_MemoryFile('notes.txt', Uint8List.fromList([1, 2, 3, 4]))]);

    await importFromMenu(tester);

    expect(repository.saveCount, 0);
    expect(find.textContaining('notes.txt could not be imported'),
        findsOneWidget);
  });

  testWidgets('cancelling the picker imports nothing', (tester) async {
    final repository = await pumpExplorer(tester, []);

    await importFromMenu(tester);

    expect(repository.saveCount, 0);
    expect(find.byType(SnackBar), findsNothing);
  });
}
