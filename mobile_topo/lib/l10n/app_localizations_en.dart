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
  String get mapViewTitle => 'Map';

  @override
  String get sketchViewTitle => 'Sketch';

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
  String get optionsViewPlaceholder => 'Options';
}
