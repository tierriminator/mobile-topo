import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Mobile Topo'**
  String get appTitle;

  /// Title for the data view
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataViewTitle;

  /// Message shown when no section is selected
  ///
  /// In en, this message translates to:
  /// **'Select a section in Explorer'**
  String get dataViewNoSection;

  /// Message shown when section has no stretches
  ///
  /// In en, this message translates to:
  /// **'No stretches yet'**
  String get dataViewNoStretches;

  /// Message shown when section has no reference points
  ///
  /// In en, this message translates to:
  /// **'No reference points yet'**
  String get dataViewNoReferencePoints;

  /// Title for the map view
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapViewTitle;

  /// Message shown when no section is selected
  ///
  /// In en, this message translates to:
  /// **'Select a section in Explorer'**
  String get mapViewNoSection;

  /// Message shown when section has no survey data
  ///
  /// In en, this message translates to:
  /// **'No survey data yet'**
  String get mapViewNoData;

  /// Title for the sketch view
  ///
  /// In en, this message translates to:
  /// **'Sketch'**
  String get sketchViewTitle;

  /// Message shown when no section is selected
  ///
  /// In en, this message translates to:
  /// **'Select a section in Explorer'**
  String get sketchViewNoSection;

  /// Message shown when section has no survey data
  ///
  /// In en, this message translates to:
  /// **'No survey data yet'**
  String get sketchViewNoData;

  /// Title for the explorer view
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorerViewTitle;

  /// Title for the options view
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsViewTitle;

  /// Label for stretches/measured distances table
  ///
  /// In en, this message translates to:
  /// **'Stretches'**
  String get stretches;

  /// Label for reference points table
  ///
  /// In en, this message translates to:
  /// **'Reference Points'**
  String get referencePoints;

  /// Column header for 'from' station
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get columnFrom;

  /// Column header for 'to' station
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get columnTo;

  /// Column header for distance
  ///
  /// In en, this message translates to:
  /// **'Dist.'**
  String get columnDistance;

  /// Column header for azimuth/declination
  ///
  /// In en, this message translates to:
  /// **'Azi.'**
  String get columnAzimuth;

  /// Column header for inclination
  ///
  /// In en, this message translates to:
  /// **'Incl.'**
  String get columnInclination;

  /// Column header for station ID
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get columnId;

  /// Column header for east coordinate
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get columnEast;

  /// Column header for north coordinate
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get columnNorth;

  /// Column header for altitude
  ///
  /// In en, this message translates to:
  /// **'Alt.'**
  String get columnAltitude;

  /// Map status bar showing cave overview
  ///
  /// In en, this message translates to:
  /// **'Length: {length}m  Depth: {depth}m  Scale: {scale}'**
  String mapStatusOverview(String length, String depth, String scale);

  /// Map status bar showing selected station info
  ///
  /// In en, this message translates to:
  /// **'Station {id}: E {east}m, N {north}m, Alt {altitude}m'**
  String mapStatusStation(
      String id, String east, String north, String altitude);

  /// Label for outline (plan) view in sketch
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get sketchOutline;

  /// Label for side view (profile) in sketch
  ///
  /// In en, this message translates to:
  /// **'Side View'**
  String get sketchSideView;

  /// Scale indicator in sketch view
  ///
  /// In en, this message translates to:
  /// **'Scale: {scale}'**
  String sketchScale(String scale);

  /// Tooltip for move/pan mode
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get sketchModeMove;

  /// Tooltip for eraser mode
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get sketchModeErase;

  /// Undo action
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Redo action
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// Title shown in explorer toolbar
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorerTitle;

  /// Tooltip for add new item button in explorer
  ///
  /// In en, this message translates to:
  /// **'Add new'**
  String get explorerAddNew;

  /// Message shown when explorer is empty
  ///
  /// In en, this message translates to:
  /// **'No caves yet. Tap + to create one.'**
  String get explorerEmpty;

  /// Default name for a new cave
  ///
  /// In en, this message translates to:
  /// **'New Cave'**
  String get explorerNewCave;

  /// Title for the new cave dialog
  ///
  /// In en, this message translates to:
  /// **'Create New Cave'**
  String get explorerNewCaveTitle;

  /// Label for cave name input
  ///
  /// In en, this message translates to:
  /// **'Cave name'**
  String get explorerCaveName;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Menu item to add a new section
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get explorerAddSection;

  /// Menu item to add a new area
  ///
  /// In en, this message translates to:
  /// **'Add Area'**
  String get explorerAddArea;

  /// Menu item to delete an item
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get explorerDelete;

  /// Default name for a new section
  ///
  /// In en, this message translates to:
  /// **'New Section'**
  String get explorerNewSection;

  /// Title for the new section dialog
  ///
  /// In en, this message translates to:
  /// **'Create New Section'**
  String get explorerNewSectionTitle;

  /// Label for section name input
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get explorerSectionName;

  /// Placeholder text for options view
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsViewPlaceholder;

  /// Button to add a new stretch
  ///
  /// In en, this message translates to:
  /// **'Add Stretch'**
  String get addStretch;

  /// Title for add stretch dialog
  ///
  /// In en, this message translates to:
  /// **'Add Stretch'**
  String get addStretchTitle;

  /// Tooltip for delete stretch button
  ///
  /// In en, this message translates to:
  /// **'Delete stretch'**
  String get deleteStretch;

  /// Label for from station input
  ///
  /// In en, this message translates to:
  /// **'From station'**
  String get fromStation;

  /// Label for to station input
  ///
  /// In en, this message translates to:
  /// **'To station'**
  String get toStation;

  /// Label for distance input
  ///
  /// In en, this message translates to:
  /// **'Distance (m)'**
  String get distance;

  /// Label for azimuth input
  ///
  /// In en, this message translates to:
  /// **'Azimuth (°)'**
  String get azimuth;

  /// Label for inclination input
  ///
  /// In en, this message translates to:
  /// **'Inclination (°)'**
  String get inclination;

  /// Add button text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Error message for invalid number input
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// Error message for required field
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Context menu option to insert row above
  ///
  /// In en, this message translates to:
  /// **'Insert above'**
  String get insertAbove;

  /// Context menu option to insert row below
  ///
  /// In en, this message translates to:
  /// **'Insert below'**
  String get insertBelow;

  /// Context menu option to set current station for new measurements
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get startHere;

  /// Section header for Bluetooth settings
  ///
  /// In en, this message translates to:
  /// **'Bluetooth / Device'**
  String get optionsBluetoothSection;

  /// Label for DistoX device selection
  ///
  /// In en, this message translates to:
  /// **'DistoX Device'**
  String get optionsBluetoothDevice;

  /// Subtitle when no Bluetooth device is selected
  ///
  /// In en, this message translates to:
  /// **'No device selected'**
  String get optionsBluetoothDeviceNone;

  /// Label for auto-connect toggle
  ///
  /// In en, this message translates to:
  /// **'Auto Connect'**
  String get optionsAutoConnect;

  /// Description for auto-connect feature
  ///
  /// In en, this message translates to:
  /// **'Automatically reconnect when connection drops'**
  String get optionsAutoConnectDescription;

  /// Section header for smart mode settings
  ///
  /// In en, this message translates to:
  /// **'Smart Mode'**
  String get optionsSmartModeSection;

  /// Label for smart mode toggle
  ///
  /// In en, this message translates to:
  /// **'Smart Mode'**
  String get optionsSmartMode;

  /// Description for smart mode feature
  ///
  /// In en, this message translates to:
  /// **'Auto-detect 3 identical shots as survey shot'**
  String get optionsSmartModeDescription;

  /// Label for default shot direction
  ///
  /// In en, this message translates to:
  /// **'Shot Direction'**
  String get optionsShotDirection;

  /// Forward shot direction option
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get optionsShotDirectionForward;

  /// Backward shot direction option
  ///
  /// In en, this message translates to:
  /// **'Backward'**
  String get optionsShotDirectionBackward;

  /// Section header for unit settings
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get optionsUnitsSection;

  /// Label for length unit selection
  ///
  /// In en, this message translates to:
  /// **'Length Unit'**
  String get optionsLengthUnit;

  /// Meters length unit option
  ///
  /// In en, this message translates to:
  /// **'Meters (m)'**
  String get optionsLengthUnitMeters;

  /// Feet length unit option
  ///
  /// In en, this message translates to:
  /// **'Feet (ft)'**
  String get optionsLengthUnitFeet;

  /// Label for angle unit selection
  ///
  /// In en, this message translates to:
  /// **'Angle Unit'**
  String get optionsAngleUnit;

  /// Degrees angle unit option
  ///
  /// In en, this message translates to:
  /// **'Degrees (360°)'**
  String get optionsAngleUnitDegrees;

  /// Grad angle unit option
  ///
  /// In en, this message translates to:
  /// **'Grad (400g)'**
  String get optionsAngleUnitGrad;

  /// Section header for display settings
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get optionsDisplaySection;

  /// Label for grid toggle
  ///
  /// In en, this message translates to:
  /// **'Show Grid'**
  String get optionsShowGrid;

  /// Description for show grid feature
  ///
  /// In en, this message translates to:
  /// **'Display grid in sketch view'**
  String get optionsShowGridDescription;

  /// Section header for calibration
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get optionsCalibrationSection;

  /// Label for calibration screen
  ///
  /// In en, this message translates to:
  /// **'Device Calibration'**
  String get optionsCalibration;

  /// Description for calibration feature
  ///
  /// In en, this message translates to:
  /// **'Calibrate DistoX compass and clinometer'**
  String get optionsCalibrationDescription;

  /// Section header for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get optionsAboutSection;

  /// Label for about screen
  ///
  /// In en, this message translates to:
  /// **'About Mobile Topo'**
  String get optionsAbout;

  /// Label for a survey stretch (From→To measurement)
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get stretch;

  /// Label for a cross-section measurement (splay shot)
  ///
  /// In en, this message translates to:
  /// **'Cross-section'**
  String get crossSection;

  /// Label for current station in status bar
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentStation;

  /// Error message when Bluetooth is not available
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available on this device'**
  String get bluetoothNotAvailable;

  /// Prompt to enable Bluetooth
  ///
  /// In en, this message translates to:
  /// **'Please enable Bluetooth'**
  String get bluetoothEnablePrompt;

  /// Dialog title for device selection
  ///
  /// In en, this message translates to:
  /// **'Select DistoX Device'**
  String get bluetoothSelectDevice;

  /// Section header for paired devices
  ///
  /// In en, this message translates to:
  /// **'Paired Devices'**
  String get bluetoothPairedDevices;

  /// Section header for available devices
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get bluetoothAvailableDevices;

  /// Prompt to start scanning for devices
  ///
  /// In en, this message translates to:
  /// **'Tap Scan to find devices'**
  String get bluetoothScanPrompt;

  /// Status while connecting to device
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get bluetoothConnecting;

  /// Status while reconnecting to device
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get bluetoothReconnecting;

  /// Status when connected to device
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get bluetoothConnected;

  /// Button to disconnect from device
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Button to scan for devices
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// Button to stop scanning
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Error message when connection fails
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String connectionFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
