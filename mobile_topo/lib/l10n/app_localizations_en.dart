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
  String get calibrationStop => 'Stop';

  @override
  String get calibrationNew => 'New';

  @override
  String get calibrationEvaluate => 'Evaluate';

  @override
  String get calibrationUpdate => 'Update';

  @override
  String get calibrationWrite => 'Write';

  @override
  String get calibrationClear => 'Clear';

  @override
  String get calibrationClearConfirm =>
      'Clear all measurements and start over?';

  @override
  String get calibrationCancelTitle => 'Cancel Calibration?';

  @override
  String get calibrationCancelConfirm =>
      'You have unsaved calibration measurements. Discard and exit?';

  @override
  String get calibrationDiscard => 'Discard';

  @override
  String get calibrationUpdateConfirm =>
      'Write calibration coefficients to device?';

  @override
  String get calibrationQualityGood => 'Good calibration';

  @override
  String get calibrationQualityPoor => 'Poor calibration';

  @override
  String get calibrationNoMeasurements => 'No calibration measurements yet';

  @override
  String get calibrationColumnEnabled => '*';

  @override
  String get calibrationColumnGroup => 'Grp';

  @override
  String get calibrationColumnError => 'Δ';

  @override
  String get calibrationColumnGMag => '|G|';

  @override
  String get calibrationColumnMMag => '|M|';

  @override
  String get calibrationColumnAlpha => 'α';

  @override
  String get calibrationMeasuring => 'Measuring...';

  @override
  String get calibrationComputing => 'Computing...';

  @override
  String get calibrationWriting => 'Writing...';

  @override
  String get calibrationReading => 'Reading...';

  @override
  String calibrationStatusCount(int count) {
    return 'n: $count';
  }

  @override
  String calibrationStatusIterations(int iterations) {
    return 'i: $iterations';
  }

  @override
  String calibrationStatusError(String error) {
    return 'Δ: $error';
  }

  @override
  String get calibrationNotConnected => 'Connect to DistoX first';

  @override
  String get calibrationMeasurement => 'Measurement';

  @override
  String get calibrationHighError => 'High error';

  @override
  String get calibrationGood => 'Good';

  @override
  String get calibrationRawValues => 'Raw sensor values';

  @override
  String get calibrationComputedValues => 'Computed values';

  @override
  String get calibrationError => 'Error';

  @override
  String get calibrationAzimuth => 'Azimuth';

  @override
  String get calibrationInclination => 'Inclination';

  @override
  String get calibrationRoll => 'Roll';

  @override
  String get calibrationDisable => 'Disable';

  @override
  String get calibrationEnable => 'Enable';

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
      'The remaining 40 measurements are less critical.\n\n• Aim in different directions to cover a sphere (imagine cube vertices)\n• Still use a target point for each shot\n• Allow the reading to stabilize before shooting\n• The exact directions don\'t matter - just get good spread';

  @override
  String get calibrationBegin => 'Begin';

  @override
  String get calibrationContinue => 'Continue';

  @override
  String get calibrationEnvironmentWarning => 'Magnetic Environment';

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
  String get calibrationComplete => 'Calibration complete';

  @override
  String calibrationRetakeNeeded(int index) {
    return 'Measurement #$index has high error. Retake:';
  }

  @override
  String get calibrationTakeMoreOrRetake =>
      'Take more shots or retake bad ones';

  @override
  String get calibrationAlphaDip => 'α (dip)';

  @override
  String get calibrationDirectionForward => 'Forward';

  @override
  String get calibrationDirectionRight => 'Right';

  @override
  String get calibrationDirectionBack => 'Back';

  @override
  String get calibrationDirectionLeft => 'Left';

  @override
  String get calibrationDirectionForwardRightUp => 'Forward-Right, up 45°';

  @override
  String get calibrationDirectionRightBackUp => 'Right-Back, up 45°';

  @override
  String get calibrationDirectionBackLeftUp => 'Back-Left, up 45°';

  @override
  String get calibrationDirectionLeftForwardUp => 'Left-Forward, up 45°';

  @override
  String get calibrationDirectionForwardRightDown => 'Forward-Right, down 45°';

  @override
  String get calibrationDirectionRightBackDown => 'Right-Back, down 45°';

  @override
  String get calibrationDirectionBackLeftDown => 'Back-Left, down 45°';

  @override
  String get calibrationDirectionLeftForwardDown => 'Left-Forward, down 45°';

  @override
  String get calibrationDirectionUp => 'Up';

  @override
  String get calibrationDirectionDown => 'Down';

  @override
  String calibrationDirectionN(int n) {
    return 'Direction $n';
  }

  @override
  String get calibrationRollFlat => 'flat';

  @override
  String get calibrationRoll90CW => '90° CW';

  @override
  String get calibrationRollUpsideDown => 'upside down';

  @override
  String get calibrationRoll90CCW => '90° CCW';

  @override
  String get calibrationRollDescFlat => 'Roll: flat (display up)';

  @override
  String get calibrationRollDesc90CW => 'Roll: 90° CW (display right)';

  @override
  String get calibrationRollDescUpsideDown =>
      'Roll: upside down (display down)';

  @override
  String get calibrationRollDesc90CCW => 'Roll: 90° CCW (display left)';

  @override
  String calibrationRollN(int n) {
    return 'Roll $n';
  }

  @override
  String calibrationShotDescription(
      String direction, String roll, int progress) {
    return '$direction, roll $roll ($progress/4)';
  }

  @override
  String calibrationPhaseInitialRemaining(int remaining) {
    return 'Take $remaining more shots to enable guidance';
  }

  @override
  String get calibrationPhaseInitial => 'Take shots in any direction';

  @override
  String calibrationPhaseGuided(int remaining, int filled) {
    return 'Fill remaining $remaining positions ($filled/56)';
  }

  @override
  String calibrationPhaseCorrecting(int index, String reason, int remaining) {
    return 'Retake shot #$index ($reason) - $remaining remaining';
  }

  @override
  String calibrationPhaseCorrectingGeneric(int count) {
    return 'Correct $count shots with errors';
  }

  @override
  String get calibrationPhaseComplete =>
      'Calibration complete! Ready to write to device.';

  @override
  String get calibrationAllPositionsFilled => 'All 56 positions filled!';

  @override
  String calibrationReasonHighError(String error) {
    return 'error $error°';
  }

  @override
  String get calibrationReasonMisaligned => 'misaligned';

  @override
  String get calibrationReasonBoth => 'high error & misaligned';
}
