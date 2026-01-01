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

  /// Title for the map view
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapViewTitle;

  /// Title for the sketch view
  ///
  /// In en, this message translates to:
  /// **'Sketch'**
  String get sketchViewTitle;

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

  /// Placeholder text for options view
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsViewPlaceholder;
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
