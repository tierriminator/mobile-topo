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

  @override
  String get optionsBluetoothSection => 'Bluetooth / Device';

  @override
  String get optionsBluetoothDevice => 'DistoX Device';

  @override
  String get optionsBluetoothDeviceNone => 'No device selected';

  @override
  String get optionsAutoConnect => 'Auto Connect';

  @override
  String get optionsAutoConnectDescription =>
      'Automatically reconnect when connection drops';

  @override
  String get optionsSmartModeSection => 'Smart Mode';

  @override
  String get optionsSmartMode => 'Smart Mode';

  @override
  String get optionsSmartModeDescription =>
      'Auto-detect 3 identical shots as survey shot';

  @override
  String get optionsShotDirection => 'Shot Direction';

  @override
  String get optionsShotDirectionForward => 'Forward';

  @override
  String get optionsShotDirectionBackward => 'Backward';

  @override
  String get optionsUnitsSection => 'Units';

  @override
  String get optionsLengthUnit => 'Length Unit';

  @override
  String get optionsLengthUnitMeters => 'Meters (m)';

  @override
  String get optionsLengthUnitFeet => 'Feet (ft)';

  @override
  String get optionsAngleUnit => 'Angle Unit';

  @override
  String get optionsAngleUnitDegrees => 'Degrees (360°)';

  @override
  String get optionsAngleUnitGrad => 'Grad (400g)';

  @override
  String get optionsDisplaySection => 'Display';

  @override
  String get optionsShowGrid => 'Show Grid';

  @override
  String get optionsShowGridDescription => 'Display grid in sketch view';

  @override
  String get optionsCalibrationSection => 'Calibration';

  @override
  String get optionsCalibration => 'Device Calibration';

  @override
  String get optionsCalibrationDescription =>
      'Calibrate DistoX compass and clinometer';

  @override
  String get optionsAboutSection => 'About';

  @override
  String get optionsAbout => 'About Mobile Topo';

  @override
  String get stretch => 'Stretch';

  @override
  String get crossSection => 'Cross-section';

  @override
  String get bluetoothNotAvailable =>
      'Bluetooth is not available on this device';

  @override
  String get bluetoothEnablePrompt => 'Please enable Bluetooth';

  @override
  String get bluetoothSelectDevice => 'Select DistoX Device';

  @override
  String get bluetoothPairedDevices => 'Paired Devices';

  @override
  String get bluetoothAvailableDevices => 'Available Devices';

  @override
  String get bluetoothScanPrompt => 'Tap Scan to find devices';

  @override
  String get bluetoothConnecting => 'Connecting...';

  @override
  String get bluetoothReconnecting => 'Reconnecting...';

  @override
  String get bluetoothConnected => 'Connected';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get scan => 'Scan';

  @override
  String get stop => 'Stop';

  @override
  String connectionFailed(String error) {
    return 'Failed to connect: $error';
  }
}
