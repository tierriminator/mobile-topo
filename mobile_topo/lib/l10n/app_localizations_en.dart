// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mobile Topo';

  @override
  String get dataViewTitle => 'Data';

  @override
  String get dataViewNoSection => 'Select a section in Explorer';

  @override
  String get dataViewNoStretches => 'No stretches yet';

  @override
  String get dataViewNoReferencePoints => 'No reference points yet';

  @override
  String get mapViewTitle => 'Map';

  @override
  String get mapViewNoSection => 'Select a section in Explorer';

  @override
  String get mapViewNoData => 'No survey data yet';

  @override
  String get sketchViewTitle => 'Sketch';

  @override
  String get sketchViewNoSection => 'Select a section in Explorer';

  @override
  String get sketchViewNoData => 'No survey data yet';

  @override
  String get explorerViewTitle => 'Explorer';

  @override
  String get optionsViewTitle => 'Options';

  @override
  String get stretches => 'Stretches';

  @override
  String get referencePoints => 'Reference Points';

  @override
  String get columnFrom => 'From';

  @override
  String get columnTo => 'To';

  @override
  String get columnDistance => 'Dist.';

  @override
  String get columnAzimuth => 'Azi.';

  @override
  String get columnInclination => 'Incl.';

  @override
  String get columnId => 'ID';

  @override
  String get columnEast => 'East';

  @override
  String get columnNorth => 'North';

  @override
  String get columnAltitude => 'Alt.';

  @override
  String mapStatusOverview(String length, String depth, String scale) {
    return 'Length: ${length}m  Depth: ${depth}m  Scale: $scale';
  }

  @override
  String mapStatusStation(
      String id, String east, String north, String altitude) {
    return 'Station $id: E ${east}m, N ${north}m, Alt ${altitude}m';
  }

  @override
  String get sketchOutline => 'Outline';

  @override
  String get sketchSideView => 'Side View';

  @override
  String sketchScale(String scale) {
    return 'Scale: $scale';
  }

  @override
  String get sketchModeMove => 'Move';

  @override
  String get sketchModeErase => 'Erase';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get explorerTitle => 'Explorer';

  @override
  String get explorerAddNew => 'Add new';

  @override
  String get explorerEmpty => 'No caves yet. Tap + to create one.';

  @override
  String get explorerNewCave => 'New Cave';

  @override
  String get explorerNewCaveTitle => 'Create New Cave';

  @override
  String get explorerCaveName => 'Cave name';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get explorerAddSection => 'Add Section';

  @override
  String get explorerAddArea => 'Add Area';

  @override
  String get explorerDelete => 'Delete';

  @override
  String get explorerNewSection => 'New Section';

  @override
  String get explorerNewSectionTitle => 'Create New Section';

  @override
  String get explorerSectionName => 'Section name';

  @override
  String get optionsViewPlaceholder => 'Options';

  @override
  String get addStretch => 'Add Stretch';

  @override
  String get addStretchTitle => 'Add Stretch';

  @override
  String get deleteStretch => 'Delete stretch';

  @override
  String get fromStation => 'From station';

  @override
  String get toStation => 'To station';

  @override
  String get distance => 'Distance (m)';

  @override
  String get azimuth => 'Azimuth (°)';

  @override
  String get inclination => 'Inclination (°)';

  @override
  String get add => 'Add';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get required => 'Required';

  @override
  String get insertAbove => 'Insert above';

  @override
  String get insertBelow => 'Insert below';
}
