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

  /// Title of the dialog and context menu item for the comment of a table row
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

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
  /// **'Length: {length}{unit}  Depth: {depth}{unit}  Scale: {scale}'**
  String mapStatusOverview(
    String length,
    String depth,
    String unit,
    String scale,
  );

  /// Map and sketch status bar showing selected station info
  ///
  /// In en, this message translates to:
  /// **'Station {id}: E {east}{unit}, N {north}{unit}, Alt {altitude}{unit}'**
  String stationStatus(
    String id,
    String east,
    String north,
    String altitude,
    String unit,
  );

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

  /// Station menu: show the station's row in the data view (PocketTopo's '-> Data')
  ///
  /// In en, this message translates to:
  /// **'View in Data'**
  String get navigateToData;

  /// Station menu: show the station in the map view (PocketTopo's '-> Map')
  ///
  /// In en, this message translates to:
  /// **'View in Map'**
  String get navigateToMap;

  /// Station menu: show the station in the outline sketch (PocketTopo's '-> Outline')
  ///
  /// In en, this message translates to:
  /// **'View in Outline'**
  String get navigateToOutline;

  /// Station menu: show the station in the side view sketch (PocketTopo's '-> Side View')
  ///
  /// In en, this message translates to:
  /// **'View in Side View'**
  String get navigateToSideView;

  /// Outline menu option to also show the survey data of the rest of the cave
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get sketchShowAll;

  /// Station menu: place a cross section seen along the passage (PocketTopo's 'XSection |')
  ///
  /// In en, this message translates to:
  /// **'Vertical Cross Section'**
  String get sketchCrossSectionVertical;

  /// Side view station menu: place a cross section seen from above (PocketTopo's 'XSection –')
  ///
  /// In en, this message translates to:
  /// **'Horizontal Cross Section'**
  String get sketchCrossSectionHorizontal;

  /// Sketch status bar after choosing a cross section from the station menu
  ///
  /// In en, this message translates to:
  /// **'Tap where to draw the cross section of {station}'**
  String sketchPlaceCrossSection(String station);

  /// Side view station menu: turn around the direction of the shot leading to the station
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get sketchFlip;

  /// Side view station menu: turn around the shot leading to the station and all following shots of the series
  ///
  /// In en, this message translates to:
  /// **'Flip All'**
  String get sketchFlipAll;

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

  /// Explorer node listing the trips of a cave
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get explorerTrips;

  /// Shown under the trips node when a cave has no trips
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get explorerNoTrips;

  /// Menu item to add a new trip to a cave
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get explorerAddTrip;

  /// Menu item to import PocketTopo .top files into a cave, each as a new section
  ///
  /// In en, this message translates to:
  /// **'Import PocketTopo Files'**
  String get explorerImportPocketTopo;

  /// Message shown when a PocketTopo file cannot be read
  ///
  /// In en, this message translates to:
  /// **'{file} could not be imported: {error}'**
  String importPocketTopoFailed(String file, String error);

  /// Message shown after importing a PocketTopo file with measurements that have no station
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 measurement belongs to no station and was left out.} other{{count} measurements belong to no station and were left out.}}'**
  String importPocketTopoSkipped(int count);

  /// Menu item to save a cave's or section's survey data as a Therion .th file
  ///
  /// In en, this message translates to:
  /// **'Export Therion Survey (.th)'**
  String get explorerExportTherion;

  /// Menu item to save a cave's or section's data and sketches as the text PocketTopo exports for Therion, which xtherion imports
  ///
  /// In en, this message translates to:
  /// **'Export Therion Text (.txt)'**
  String get explorerExportTherionText;

  /// Message shown when an exported file cannot be saved
  ///
  /// In en, this message translates to:
  /// **'The file could not be saved: {error}'**
  String exportFailed(String error);

  /// Shown next to the active trip, which new measurements are assigned to
  ///
  /// In en, this message translates to:
  /// **'(active)'**
  String get tripActive;

  /// Button making a trip the one new measurements are assigned to
  ///
  /// In en, this message translates to:
  /// **'Make active'**
  String get tripMakeActive;

  /// Shown in place of the make active button when the trip is already the active one
  ///
  /// In en, this message translates to:
  /// **'Active trip'**
  String get tripIsActive;

  /// Confirmation shown before making a trip from another day the active one
  ///
  /// In en, this message translates to:
  /// **'This trip is from {date}, not today. New measurements will be assigned to it.'**
  String tripMakeActiveOtherDay(String date);

  /// Message shown when deleting a trip that measurements refer to
  ///
  /// In en, this message translates to:
  /// **'This trip cannot be deleted because measurements refer to it.'**
  String get tripInUse;

  /// Title of the page editing a trip
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get tripTitle;

  /// Length of the survey shots measured on a trip
  ///
  /// In en, this message translates to:
  /// **'Surveyed length'**
  String get tripLength;

  /// Label for the date of a trip
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get tripDate;

  /// Label for the unique ID of a trip, which tells trips of the same day apart
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get tripId;

  /// Label for the declination correction of a trip
  ///
  /// In en, this message translates to:
  /// **'Declination correction'**
  String get tripDeclination;

  /// Explanation of the declination correction
  ///
  /// In en, this message translates to:
  /// **'Angle from map north to magnetic north, positive when magnetic north lies east. Added to the azimuth of the trip\'s stretches.'**
  String get tripDeclinationHelp;

  /// Label for the comment of a trip
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get tripComment;

  /// Hint for the comment of a trip
  ///
  /// In en, this message translates to:
  /// **'Surveyors, conditions, …'**
  String get tripCommentHint;

  /// Context menu item showing a row's trip
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get trip;

  /// Trip bar warning when the cave has no trip
  ///
  /// In en, this message translates to:
  /// **'No trip – tap to start one'**
  String get tripBarNoTripWarning;

  /// Trip bar warning when the active trip is from an earlier day
  ///
  /// In en, this message translates to:
  /// **'Old trip: {trip}'**
  String tripBarOldTrip(String trip);

  /// Title of the dialog asking whether to keep the active trip
  ///
  /// In en, this message translates to:
  /// **'Check the trip'**
  String get tripCheckTitle;

  /// Asks whether to keep a trip from an earlier day
  ///
  /// In en, this message translates to:
  /// **'New measurements go to the trip {trip}, which is from an earlier day. A trip usually covers a single day.'**
  String tripCheckOldTrip(String trip);

  /// Asks whether to continue without a trip
  ///
  /// In en, this message translates to:
  /// **'This cave has no trip yet, so new measurements are not assigned to one.'**
  String get tripCheckNoTrip;

  /// Keeps the active trip despite it being from an earlier day
  ///
  /// In en, this message translates to:
  /// **'Keep trip'**
  String get tripKeepUsing;

  /// Continues measuring without a trip
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get tripContinueWithout;

  /// Starts a new trip
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get tripNew;

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

  /// Context menu option to switch a survey shot between forward and backward
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flipShot;

  /// Context menu option to turn a cross section into a survey shot to the next station
  ///
  /// In en, this message translates to:
  /// **'To survey shot'**
  String get toSurveyShot;

  /// Context menu option to reassign the stations of the following rows
  ///
  /// In en, this message translates to:
  /// **'Renumber'**
  String get renumber;

  /// Context menu option to start a new series from this station
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get startHere;

  /// Context menu option to continue surveying from the last station of this corridor
  ///
  /// In en, this message translates to:
  /// **'Continue here'**
  String get continueHere;

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

  /// Tooltip for cell edit mode toggle button
  ///
  /// In en, this message translates to:
  /// **'Edit cells'**
  String get cellEditMode;

  /// Bulk action bar of the data view: number of checked rows
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row selected} other{{count} rows selected}}'**
  String rowsSelected(int count);

  /// Tooltip for unchecking all rows in the data view's bulk action bar
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// Bulk action assigning a trip to all checked rows of the data view
  ///
  /// In en, this message translates to:
  /// **'Set trip'**
  String get setTrip;

  /// Title for calibration screen
  ///
  /// In en, this message translates to:
  /// **'Device Calibration'**
  String get calibrationTitle;

  /// Calibration start page: overview of the shots
  ///
  /// In en, this message translates to:
  /// **'Take 4 shots in each of 14 directions, turning the display up, right, down and left. The app shows where to aim next.'**
  String get calibrationIntroShots;

  /// Calibration start page: the precisely aimed horizontal directions
  ///
  /// In en, this message translates to:
  /// **'The first 4 directions are horizontal: forward, right, back and left. For each, pick a fixed point as far away as possible and hit it precisely with all 4 shots.'**
  String get calibrationIntroPrecise;

  /// Calibration start page: the roughly aimed directions
  ///
  /// In en, this message translates to:
  /// **'For the other 10 directions, aiming roughly is enough.'**
  String get calibrationIntroRough;

  /// Calibration start page: holding the device still
  ///
  /// In en, this message translates to:
  /// **'Hold the device still until each reading has settled.'**
  String get calibrationIntroSteady;

  /// Calibration start page: what happens after all shots
  ///
  /// In en, this message translates to:
  /// **'Afterwards, retake the directions the app marks, then write the calibration to the device.'**
  String get calibrationIntroRetake;

  /// Button to start calibration mode
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get calibrationStart;

  /// Button to write coefficients to device
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get calibrationWrite;

  /// Title for cancel calibration dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel Calibration?'**
  String get calibrationCancelTitle;

  /// Confirmation message for canceling calibration
  ///
  /// In en, this message translates to:
  /// **'You have unsaved calibration measurements. Discard and exit?'**
  String get calibrationCancelConfirm;

  /// Button to discard calibration and exit
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get calibrationDiscard;

  /// Error when trying to calibrate without connection
  ///
  /// In en, this message translates to:
  /// **'Connect to DistoX first'**
  String get calibrationNotConnected;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Warning text about magnetic environment
  ///
  /// In en, this message translates to:
  /// **'You must be in a magnetically clean environment (cave or forest). Buildings and metal objects will ruin the calibration.'**
  String get calibrationEnvironmentText;

  /// Short indicator shown when device is in calibration mode
  ///
  /// In en, this message translates to:
  /// **'CAL'**
  String get calibrationModeIndicator;

  /// Direction 0: forward/north
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get calibrationDirection0;

  /// Direction 1: right/east
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get calibrationDirection1;

  /// Direction 2: back/south
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get calibrationDirection2;

  /// Direction 3: left/west
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get calibrationDirection3;

  /// Direction 4: upper cube vertex between forward and right, about 35° up
  ///
  /// In en, this message translates to:
  /// **'Forward-Right, upper corner'**
  String get calibrationDirection4;

  /// Direction 5: upper cube vertex between right and back, about 35° up
  ///
  /// In en, this message translates to:
  /// **'Right-Back, upper corner'**
  String get calibrationDirection5;

  /// Direction 6: upper cube vertex between back and left, about 35° up
  ///
  /// In en, this message translates to:
  /// **'Back-Left, upper corner'**
  String get calibrationDirection6;

  /// Direction 7: upper cube vertex between left and forward, about 35° up
  ///
  /// In en, this message translates to:
  /// **'Left-Forward, upper corner'**
  String get calibrationDirection7;

  /// Direction 8: lower cube vertex between forward and right, about 35° down
  ///
  /// In en, this message translates to:
  /// **'Forward-Right, lower corner'**
  String get calibrationDirection8;

  /// Direction 9: lower cube vertex between right and back, about 35° down
  ///
  /// In en, this message translates to:
  /// **'Right-Back, lower corner'**
  String get calibrationDirection9;

  /// Direction 10: lower cube vertex between back and left, about 35° down
  ///
  /// In en, this message translates to:
  /// **'Back-Left, lower corner'**
  String get calibrationDirection10;

  /// Direction 11: lower cube vertex between left and forward, about 35° down
  ///
  /// In en, this message translates to:
  /// **'Left-Forward, lower corner'**
  String get calibrationDirection11;

  /// Direction 12: straight up
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get calibrationDirection12;

  /// Direction 13: straight down
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get calibrationDirection13;

  /// Fallback direction label
  ///
  /// In en, this message translates to:
  /// **'Direction {n}'**
  String calibrationDirectionN(int n);

  /// Device orientation for roll 0°, shown prominently for the next calibration shot
  ///
  /// In en, this message translates to:
  /// **'Display up'**
  String get calibrationDisplayUp;

  /// Device orientation for roll 90°, shown prominently for the next calibration shot
  ///
  /// In en, this message translates to:
  /// **'Display right'**
  String get calibrationDisplayRight;

  /// Device orientation for roll 180°, shown prominently for the next calibration shot
  ///
  /// In en, this message translates to:
  /// **'Display down'**
  String get calibrationDisplayDown;

  /// Device orientation for roll 270°, shown prominently for the next calibration shot
  ///
  /// In en, this message translates to:
  /// **'Display left'**
  String get calibrationDisplayLeft;

  /// Device orientation for a vertical calibration shot whose display faces forward
  ///
  /// In en, this message translates to:
  /// **'Display forward'**
  String get calibrationDisplayForward;

  /// Device orientation for a vertical calibration shot whose display faces backward, towards the person
  ///
  /// In en, this message translates to:
  /// **'Display backward'**
  String get calibrationDisplayBackward;

  /// Short warning for the shots of the four horizontal calibration directions, which must all hit one target point. Shares a row with the Undo button, so keep it short
  ///
  /// In en, this message translates to:
  /// **'Aim precisely'**
  String get calibrationAimPrecisely;

  /// Title of the confirmation that discards the most recent calibration shot so it can be taken again
  ///
  /// In en, this message translates to:
  /// **'Undo last shot'**
  String get calibrationUndoLastShot;

  /// Confirmation before discarding the most recent calibration shot
  ///
  /// In en, this message translates to:
  /// **'Discard the last shot and take it again?'**
  String get calibrationUndoConfirm;

  /// Button that discards the four shots of a calibration direction so they can be taken again
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get calibrationRetake;

  /// Title of the confirmation before writing a calibration whose error exceeds the limit
  ///
  /// In en, this message translates to:
  /// **'High calibration error'**
  String get calibrationHighErrorTitle;

  /// Confirmation before writing a calibration whose error exceeds the limit. The values are Heeb's error measure E in percent.
  ///
  /// In en, this message translates to:
  /// **'The calibration error is {error}, above the limit of {limit}. Retaking the flagged directions may bring it down.\n\nWrite these coefficients to the device anyway?'**
  String calibrationHighErrorConfirm(String error, String limit);

  /// Button that writes a calibration despite its high error
  ///
  /// In en, this message translates to:
  /// **'Write anyway'**
  String get calibrationWriteAnyway;

  /// Header of the list of calibration directions whose shots should be retaken
  ///
  /// In en, this message translates to:
  /// **'Directions to retake'**
  String get calibrationDirectionsToRetake;

  /// Shown once all calibration shots are taken and no direction needs a retake
  ///
  /// In en, this message translates to:
  /// **'All directions look good'**
  String get calibrationAllDirectionsGood;

  /// Likely cause of a calibration error: the shots are not spread over enough directions
  ///
  /// In en, this message translates to:
  /// **'The shots do not cover enough directions to judge the calibration. Follow the shown directions.'**
  String get calibrationProblemCoverage;

  /// Likely cause of a calibration error: the gravity readings differ between shots
  ///
  /// In en, this message translates to:
  /// **'The device moved during shots. Hold it still until each reading has settled.'**
  String get calibrationProblemUnsteady;

  /// Likely cause of a calibration error: the magnetic readings differ between shots
  ///
  /// In en, this message translates to:
  /// **'The magnetic field differed between shots. Move away from metal, vehicles and power lines.'**
  String get calibrationProblemMagnetic;

  /// Likely cause of a calibration error: the four shots of a precisely aimed direction point in different directions
  ///
  /// In en, this message translates to:
  /// **'The shots of the horizontal directions do not hit one point. Aim all four shots of each precisely at the same fixed target.'**
  String get calibrationProblemAiming;

  /// Instruction for retaking a calibration direction whose shots pointed elsewhere. Lower case; joined with other instructions and capitalized
  ///
  /// In en, this message translates to:
  /// **'aim in the shown direction'**
  String get calibrationFixDirection;

  /// Instruction for retaking a precisely aimed calibration direction whose shots missed each other's point. Lower case; joined with other instructions and capitalized
  ///
  /// In en, this message translates to:
  /// **'aim at the same point'**
  String get calibrationFixTarget;

  /// Instruction for retaking a calibration direction whose shots were held in the wrong orientation. Lower case; joined with other instructions and capitalized
  ///
  /// In en, this message translates to:
  /// **'turn the display as shown'**
  String get calibrationFixOrientation;

  /// Instruction for retaking a calibration direction whose gravity readings were unsteady. Lower case; joined with other instructions and capitalized
  ///
  /// In en, this message translates to:
  /// **'hold the device still'**
  String get calibrationFixSteady;

  /// Instruction for retaking a calibration direction whose magnetic readings were disturbed. Lower case; joined with other instructions and capitalized
  ///
  /// In en, this message translates to:
  /// **'keep away from metal'**
  String get calibrationFixMagnetic;

  /// Joins retake instructions; first holds all but the last, separated by commas
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String calibrationFixesJoined(String first, String last);
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
    'that was used.',
  );
}
