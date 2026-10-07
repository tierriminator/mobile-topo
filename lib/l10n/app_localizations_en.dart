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
    String id,
    String east,
    String north,
    String altitude,
  ) {
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
  String get startHere => 'Start here';

  @override
  String get continueHere => 'Continue here';

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
  String get currentStation => 'Current';

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

  @override
  String get cellEditMode => 'Edit cells';

  @override
  String get calibrationTitle => 'Device Calibration';

  @override
  String get calibrationDescription =>
      'Take 56 measurements in 14 directions with 4 device orientations each to calibrate the DistoX sensors.';

  @override
  String get calibrationStart => 'Start';

  @override
  String get calibrationWrite => 'Write';

  @override
  String get calibrationCancelTitle => 'Cancel Calibration?';

  @override
  String get calibrationCancelConfirm =>
      'You have unsaved calibration measurements. Discard and exit?';

  @override
  String get calibrationDiscard => 'Discard';

  @override
  String get calibrationNotConnected => 'Connect to DistoX first';

  @override
  String get delete => 'Delete';

  @override
  String get calibrationPhase1Title => 'Phase 1: Precise Measurements';

  @override
  String get calibrationPhase1Instructions =>
      'The first 16 measurements (4 directions × 4 orientations) must be PRECISE.\n\n• Use two fixed points (marks on trees or cave walls)\n• For each direction, take 4 shots with different device orientations (display up, right, down, left)\n• All 4 shots in each direction must hit the SAME target point\n\nIMPORTANT: Calibrate in an undisturbed magnetic environment - a cave or forest. NOT inside buildings or near metal objects.';

  @override
  String get calibrationPhase2Title => 'Phase 2: Coverage Measurements';

  @override
  String get calibrationPhase2Instructions =>
      'The remaining 40 measurements (10 directions × 4 orientations) cover additional angles.\n\n• Imagine standing in the center of a large cube\n• Point toward the 8 corners (diagonals) plus up and down\n• For each direction, take 4 shots with different device orientations\n• The exact directions are NOT critical - just get good spread\n• Still use a target point and let readings stabilize';

  @override
  String get calibrationPhase2Tip =>
      'Unlike Phase 1, you don\'t need to hit the exact same point for all 4 shots in a direction. Just aim roughly the same way.';

  @override
  String get calibrationBegin => 'Begin';

  @override
  String get calibrationContinue => 'Continue';

  @override
  String get calibrationEnvironmentText =>
      'You must be in a magnetically clean environment (cave or forest). Buildings and metal objects will ruin the calibration.';

  @override
  String get calibrationModeIndicator => 'CAL';

  @override
  String get calibrationPhase1Complete => 'Phase 1 Complete!';

  @override
  String get calibrationPreciseMeasurementsDone =>
      '16 precise measurements done';

  @override
  String get calibrationDirection0 => 'Forward';

  @override
  String get calibrationDirection1 => 'Right';

  @override
  String get calibrationDirection2 => 'Back';

  @override
  String get calibrationDirection3 => 'Left';

  @override
  String get calibrationDirection4 => 'Forward-Right, upper corner';

  @override
  String get calibrationDirection5 => 'Right-Back, upper corner';

  @override
  String get calibrationDirection6 => 'Back-Left, upper corner';

  @override
  String get calibrationDirection7 => 'Left-Forward, upper corner';

  @override
  String get calibrationDirection8 => 'Forward-Right, lower corner';

  @override
  String get calibrationDirection9 => 'Right-Back, lower corner';

  @override
  String get calibrationDirection10 => 'Back-Left, lower corner';

  @override
  String get calibrationDirection11 => 'Left-Forward, lower corner';

  @override
  String get calibrationDirection12 => 'Up';

  @override
  String get calibrationDirection13 => 'Down';

  @override
  String calibrationDirectionN(int n) {
    return 'Direction $n';
  }

  @override
  String get calibrationDisplayUp => 'Display up';

  @override
  String get calibrationDisplayRight => 'Display right';

  @override
  String get calibrationDisplayDown => 'Display down';

  @override
  String get calibrationDisplayLeft => 'Display left';

  @override
  String get calibrationDisplayForward => 'Display forward';

  @override
  String get calibrationDisplayBackward => 'Display backward';

  @override
  String get calibrationPreciseMeasurement => 'Precise measurement';

  @override
  String get calibrationUndoLastShot => 'Undo last shot';

  @override
  String get calibrationUndoConfirm =>
      'Discard the last shot and take it again?';

  @override
  String get calibrationRetake => 'Retake';

  @override
  String calibrationRetakeConfirm(String direction) {
    return 'Discard the four shots of $direction and take them again?';
  }

  @override
  String get calibrationHighErrorTitle => 'High calibration error';

  @override
  String calibrationHighErrorConfirm(String error, String limit) {
    return 'The calibration error is $error, above the limit of $limit. Retaking the flagged directions may bring it down.\n\nWrite these coefficients to the device anyway?';
  }

  @override
  String get calibrationWriteAnyway => 'Write anyway';

  @override
  String get calibrationDirectionsToRetake => 'Directions to retake';

  @override
  String get calibrationAllDirectionsGood => 'All directions look good';

  @override
  String get calibrationProblemCoverage =>
      'The shots do not cover enough directions to judge the calibration. Follow the shown directions.';

  @override
  String get calibrationProblemUnsteady =>
      'The device moved during shots. Hold it still until each reading has settled.';

  @override
  String get calibrationProblemMagnetic =>
      'The magnetic field differed between shots. Move away from metal, vehicles and power lines.';

  @override
  String get calibrationProblemAiming =>
      'The shots of the horizontal directions do not hit one point. Aim all four shots of each precisely at the same fixed target.';

  @override
  String get calibrationFixDirection => 'aim in the shown direction';

  @override
  String get calibrationFixTarget => 'aim at the same point';

  @override
  String get calibrationFixOrientation => 'turn the display as shown';

  @override
  String get calibrationFixSteady => 'hold the device still';

  @override
  String get calibrationFixMagnetic => 'keep away from metal';

  @override
  String calibrationFixesJoined(String first, String last) {
    return '$first and $last';
  }
}
