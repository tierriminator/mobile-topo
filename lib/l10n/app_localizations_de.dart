// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Mobile Topo';

  @override
  String get dataViewTitle => 'Daten';

  @override
  String get dataViewNoSection => 'Abschnitt im Explorer wählen';

  @override
  String get dataViewNoStretches => 'Noch keine Messdaten';

  @override
  String get dataViewNoReferencePoints => 'Noch keine Fixpunkte';

  @override
  String get mapViewTitle => 'Plan';

  @override
  String get mapViewNoSection => 'Abschnitt im Explorer wählen';

  @override
  String get mapViewNoData => 'Noch keine Vermessungsdaten';

  @override
  String get sketchViewTitle => 'Skizze';

  @override
  String get sketchViewNoSection => 'Abschnitt im Explorer wählen';

  @override
  String get sketchViewNoData => 'Noch keine Vermessungsdaten';

  @override
  String get explorerViewTitle => 'Explorer';

  @override
  String get optionsViewTitle => 'Optionen';

  @override
  String get stretches => 'Messdaten';

  @override
  String get referencePoints => 'Fixpunkte';

  @override
  String get columnFrom => 'Von';

  @override
  String get columnTo => 'Nach';

  @override
  String get columnDistance => 'Dist.';

  @override
  String get columnAzimuth => 'Azi.';

  @override
  String get columnInclination => 'Inkl.';

  @override
  String get comment => 'Kommentar';

  @override
  String get columnId => 'ID';

  @override
  String get columnEast => 'Ost';

  @override
  String get columnLongitude => 'Länge';

  @override
  String get columnLatitude => 'Breite';

  @override
  String get columnNorth => 'Nord';

  @override
  String get columnAltitude => 'Höhe';

  @override
  String mapStatusOverview(
    String length,
    String depth,
    String unit,
    String scale,
  ) {
    return 'Länge: $length$unit  Tiefe: $depth$unit  Massstab: $scale';
  }

  @override
  String stationStatus(
    String id,
    String east,
    String north,
    String altitude,
    String unit,
  ) {
    return 'Messpunkt $id: O $east$unit, N $north$unit, H $altitude$unit';
  }

  @override
  String get sketchOutline => 'Grundriss';

  @override
  String get sketchSideView => 'Seitenriss';

  @override
  String sketchScale(String scale) {
    return 'Massstab: $scale';
  }

  @override
  String get sketchModeMove => 'Verschieben';

  @override
  String get sketchModeErase => 'Löschen';

  @override
  String get navigateToData => 'In Daten zeigen';

  @override
  String get navigateToMap => 'Im Plan zeigen';

  @override
  String get navigateToOutline => 'Im Grundriss zeigen';

  @override
  String get navigateToSideView => 'Im Seitenriss zeigen';

  @override
  String get sketchShowAll => 'Alles zeigen';

  @override
  String get sketchCrossSectionVertical => 'Vertikaler Querschnitt';

  @override
  String get sketchCrossSectionHorizontal => 'Horizontaler Querschnitt';

  @override
  String sketchPlaceCrossSection(String station) {
    return 'Antippen, wo der Querschnitt von $station liegen soll';
  }

  @override
  String get sketchFlip => 'Spiegeln';

  @override
  String get sketchFlipAll => 'Alle spiegeln';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get explorerTitle => 'Explorer';

  @override
  String get explorerAddNew => 'Hinzufügen';

  @override
  String get explorerEmpty => 'Noch keine Höhlen. Mit + eine neue anlegen.';

  @override
  String get explorerNewCave => 'Neue Höhle';

  @override
  String get explorerNewCaveTitle => 'Neue Höhle anlegen';

  @override
  String get explorerCaveName => 'Name der Höhle';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Anlegen';

  @override
  String get explorerAddSection => 'Abschnitt hinzufügen';

  @override
  String get explorerAddArea => 'Gebiet hinzufügen';

  @override
  String get explorerDelete => 'Löschen';

  @override
  String get explorerNewSection => 'Neuer Abschnitt';

  @override
  String get explorerNewSectionTitle => 'Neuen Abschnitt anlegen';

  @override
  String get explorerSectionName => 'Name des Abschnitts';

  @override
  String get caveOverview => 'Höhlenübersicht';

  @override
  String get caveRename => 'Umbenennen';

  @override
  String get caveLength => 'Vermessene Länge';

  @override
  String get caveHeight => 'Höhenunterschied';

  @override
  String caveCoordinates(String station) {
    return 'Koordinaten von $station';
  }

  @override
  String get caveAltitude => 'Höhe';

  @override
  String get caveDefaultCoordinates => 'Koordinaten des Höllochs (Standard)';

  @override
  String get caveNoReferencePoint => 'Die Höhle hat noch keinen Fixpunkt.';

  @override
  String caveNotInCoordinateSystem(String station) {
    return 'Der Fixpunkt $station passt nicht zum Koordinatensystem.';
  }

  @override
  String get measurePosition => 'Position messen';

  @override
  String get measurePositionTitle => 'Position messen';

  @override
  String get measurePositionHint =>
      'Das Gerät unter freiem Himmel ruhig halten. Je länger gemessen wird, desto genauer ist die gemittelte Position.';

  @override
  String get measurePositionWaiting => 'Warten auf die erste Position…';

  @override
  String get measurePositionFixes => 'Gemessene Positionen';

  @override
  String get measurePositionAccuracy => 'Aktuelle Genauigkeit';

  @override
  String get measurePositionScatter => 'Streuung';

  @override
  String get measurePositionUse => 'Position übernehmen';

  @override
  String measurePositionFailed(String error) {
    return 'Die Position konnte nicht gemessen werden: $error';
  }

  @override
  String get locationDisabled => 'Die Ortungsdienste sind ausgeschaltet.';

  @override
  String get locationDenied => 'Mobile Topo darf den Standort nicht verwenden.';

  @override
  String get locationImprecise =>
      'Mobile Topo darf nur den ungefähren Standort verwenden, der für einen Fixpunkt zu ungenau ist. Bitte den genauen Standort erlauben.';

  @override
  String get locationOpenSettings => 'Einstellungen öffnen';

  @override
  String get optionsDefaultCoordinateSystem => 'Standard-Koordinatensystem';

  @override
  String get caveCoordinateSystem => 'Koordinatensystem';

  @override
  String get coordinateSystemSwiss => 'Schweizer Landeskoordinaten (LV95/LV03)';

  @override
  String get coordinateSystemUtm => 'UTM';

  @override
  String get coordinateSystemWgs84 => 'WGS84 Länge/Breite';

  @override
  String get caveUtmZone => 'Zone';

  @override
  String get caveUtmNorth => 'Nord';

  @override
  String get caveUtmSouth => 'Süd';

  @override
  String get caveLongitude => 'Länge';

  @override
  String get caveLatitude => 'Breite';

  @override
  String get caveShowReferencePoints => 'Fixpunkte';

  @override
  String get sectionRename => 'Umbenennen';

  @override
  String get sectionSelect => 'Öffnen';

  @override
  String get sectionIsSelected => 'Geöffneter Abschnitt';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get exportFormat => 'Exportformat';

  @override
  String get exportTherionSurvey => 'Therion-Vermessung (.th)';

  @override
  String get exportTherionText => 'Therion-Text (.txt)';

  @override
  String get exportTherionSurveyHelp =>
      'Vermessungsdatei mit Polygonzug und Fixpunkten';

  @override
  String get exportTherionTextHelp =>
      'Wie PocketTopo ihn exportiert, damit xtherion ihn mit den Skizzen importiert';

  @override
  String get sectionLength => 'Vermessene Länge';

  @override
  String get sectionHeight => 'Höhenunterschied';

  @override
  String get sectionStations => 'Messpunkte';

  @override
  String get sectionTrips => 'Touren';

  @override
  String get explorerDeleteCaveTitle => 'Höhle löschen';

  @override
  String explorerDeleteCaveMessage(String name) {
    return '«$name» wird mit allen Abschnitten, Messungen, Skizzen und Touren gelöscht. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get explorerDeleteSectionTitle => 'Abschnitt löschen';

  @override
  String explorerDeleteSectionMessage(String name) {
    return '«$name» wird mit allen Messungen und Skizzen gelöscht. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String explorerDeleteSectionTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Auch die $count Touren löschen, die nur dieser Abschnitt verwendet',
      one: 'Auch die Tour löschen, die nur dieser Abschnitt verwendet',
    );
    return '$_temp0';
  }

  @override
  String get explorerTrips => 'Touren';

  @override
  String get explorerNoTrips => 'Noch keine Touren';

  @override
  String get explorerAddTrip => 'Tour hinzufügen';

  @override
  String get explorerSections => 'Abschnitte';

  @override
  String get explorerNoSections => 'Noch keine Abschnitte';

  @override
  String get explorerNewSectionHelp =>
      'Ein leerer Abschnitt für neue Messungen';

  @override
  String get explorerImportPocketTopo => 'PocketTopo-Dateien importieren';

  @override
  String get explorerImportPocketTopoHelp =>
      'Jede .top-Datei wird ein Abschnitt, mit ihren Touren';

  @override
  String importPocketTopoFailed(String file, String error) {
    return '$file konnte nicht importiert werden: $error';
  }

  @override
  String importPocketTopoSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Messungen gehören zu keinem Messpunkt und wurden ausgelassen.',
      one: '1 Messung gehört zu keinem Messpunkt und wurde ausgelassen.',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Die Datei konnte nicht gespeichert werden: $error';
  }

  @override
  String get tripActive => '(aktiv)';

  @override
  String get tripMakeActive => 'Aktivieren';

  @override
  String get tripIsActive => 'Aktive Tour';

  @override
  String tripMakeActiveOtherDay(String date) {
    return 'Diese Tour ist vom $date, nicht von heute. Neue Messungen werden ihr zugeordnet.';
  }

  @override
  String get tripInUse =>
      'Diese Tour kann nicht gelöscht werden, weil Messungen darauf verweisen.';

  @override
  String get tripTitle => 'Tour';

  @override
  String get tripLength => 'Vermessene Länge';

  @override
  String get tripDate => 'Datum';

  @override
  String get tripId => 'ID';

  @override
  String get tripDeclination => 'Deklinationskorrektur';

  @override
  String get tripDeclinationHelp =>
      'Winkel von Karten-Nord zu magnetisch Nord, positiv wenn magnetisch Nord östlich liegt. Wird zum Azimut der Messstrecken dieser Tour addiert.';

  @override
  String get tripAutoDeclination => 'Automatische Deklination';

  @override
  String get tripComment => 'Kommentar';

  @override
  String get tripCommentHint => 'Beteiligte, Zustand der Höhle, …';

  @override
  String get trip => 'Tour';

  @override
  String get tripBarNoTripWarning =>
      'Keine Tour – antippen, um eine zu starten';

  @override
  String tripBarOldTrip(String trip) {
    return 'Alte Tour: $trip';
  }

  @override
  String get tripCheckTitle => 'Tour prüfen';

  @override
  String tripCheckOldTrip(String trip) {
    return 'Neue Messungen gehen an die Tour $trip, die von einem früheren Tag ist. Eine Tour umfasst meist einen einzigen Tag.';
  }

  @override
  String get tripCheckNoTrip =>
      'Diese Höhle hat noch keine Tour, deshalb werden neue Messungen keiner zugeordnet.';

  @override
  String get tripKeepUsing => 'Tour behalten';

  @override
  String get tripContinueWithout => 'Weiter';

  @override
  String get tripNew => 'Neue Tour';

  @override
  String get optionsViewPlaceholder => 'Optionen';

  @override
  String get addStretch => 'Messstrecke hinzufügen';

  @override
  String get addStretchTitle => 'Messstrecke hinzufügen';

  @override
  String get deleteStretch => 'Messstrecke löschen';

  @override
  String get fromStation => 'Von Messpunkt';

  @override
  String get toStation => 'Nach Messpunkt';

  @override
  String get distance => 'Distanz (m)';

  @override
  String get azimuth => 'Azimut (°)';

  @override
  String get inclination => 'Inklination (°)';

  @override
  String get add => 'Hinzufügen';

  @override
  String get invalidNumber => 'Ungültige Zahl';

  @override
  String get required => 'Erforderlich';

  @override
  String get insertAbove => 'Oberhalb einfügen';

  @override
  String get insertBelow => 'Unterhalb einfügen';

  @override
  String get flipShot => 'Richtung umkehren';

  @override
  String get toSurveyShot => 'Zur Messstrecke machen';

  @override
  String get renumber => 'Umnummerieren';

  @override
  String get startHere => 'Hier starten';

  @override
  String get continueHere => 'Hier fortsetzen';

  @override
  String get optionsBluetoothSection => 'Bluetooth / Gerät';

  @override
  String get optionsBluetoothDevice => 'DistoX-Gerät';

  @override
  String get optionsBluetoothDeviceNone => 'Kein Gerät gewählt';

  @override
  String get optionsAutoConnect => 'Automatisch verbinden';

  @override
  String get optionsAutoConnectDescription =>
      'Bei Verbindungsabbruch automatisch neu verbinden';

  @override
  String get optionsSmartModeSection => 'Smart-Modus';

  @override
  String get optionsSmartMode => 'Smart-Modus';

  @override
  String get optionsSmartModeDescription =>
      '3 gleiche Messungen automatisch als Messstrecke erkennen';

  @override
  String get optionsShotDirection => 'Messrichtung';

  @override
  String get optionsShotDirectionForward => 'Vorwärts';

  @override
  String get optionsShotDirectionBackward => 'Rückwärts';

  @override
  String get optionsUnitsSection => 'Einheiten';

  @override
  String get optionsLengthUnit => 'Längeneinheit';

  @override
  String get optionsLengthUnitMeters => 'Meter (m)';

  @override
  String get optionsLengthUnitFeet => 'Fuss (ft)';

  @override
  String get optionsAngleUnit => 'Winkeleinheit';

  @override
  String get optionsAngleUnitDegrees => 'Grad (360°)';

  @override
  String get optionsAngleUnitGrad => 'Gon (400g)';

  @override
  String get optionsDisplaySection => 'Anzeige';

  @override
  String get optionsShowGrid => 'Raster anzeigen';

  @override
  String get optionsShowGridDescription =>
      'Raster in der Skizzenansicht anzeigen';

  @override
  String get optionsCalibrationSection => 'Kalibrierung';

  @override
  String get optionsCalibration => 'Gerätekalibrierung';

  @override
  String get optionsCalibrationDescription =>
      'Kompass und Neigungsmesser des DistoX kalibrieren';

  @override
  String get optionsAboutSection => 'Über';

  @override
  String get optionsAbout => 'Über Mobile Topo';

  @override
  String get stretch => 'Messstrecke';

  @override
  String get crossSection => 'Querschnitt';

  @override
  String get currentStation => 'Aktuell';

  @override
  String get bluetoothNotAvailable =>
      'Bluetooth ist auf diesem Gerät nicht verfügbar';

  @override
  String get bluetoothEnablePrompt => 'Bitte Bluetooth einschalten';

  @override
  String get bluetoothSelectDevice => 'DistoX-Gerät wählen';

  @override
  String get bluetoothPairedDevices => 'Gekoppelte Geräte';

  @override
  String get bluetoothAvailableDevices => 'Verfügbare Geräte';

  @override
  String get bluetoothScanPrompt => 'Suchen antippen, um Geräte zu finden';

  @override
  String get bluetoothConnecting => 'Verbinden...';

  @override
  String get bluetoothReconnecting => 'Neu verbinden...';

  @override
  String get bluetoothConnected => 'Verbunden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get scan => 'Suchen';

  @override
  String get stop => 'Stopp';

  @override
  String connectionFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get cellEditMode => 'Zellen bearbeiten';

  @override
  String rowsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen ausgewählt',
      one: '1 Zeile ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get clearSelection => 'Auswahl aufheben';

  @override
  String get setTrip => 'Tour zuordnen';

  @override
  String get calibrationTitle => 'Gerätekalibrierung';

  @override
  String get calibrationIntroShots =>
      'In jede von 14 Richtungen 4 Messungen machen, mit dem Display oben, rechts, unten und links. Die App zeigt, wohin als Nächstes zu zielen ist.';

  @override
  String get calibrationIntroPrecise =>
      'Die ersten 4 Richtungen sind horizontal: vorne, rechts, hinten und links. Für jede einen möglichst weit entfernten festen Zielpunkt wählen und ihn mit allen 4 Messungen genau treffen.';

  @override
  String get calibrationIntroRough =>
      'Für die anderen 10 Richtungen genügt ungefähres Zielen.';

  @override
  String get calibrationIntroSteady =>
      'Das Gerät ruhig halten, bis sich jeder Messwert stabilisiert hat.';

  @override
  String get calibrationIntroRetake =>
      'Danach die markierten Richtungen wiederholen und die Kalibrierung auf das Gerät schreiben.';

  @override
  String get calibrationStart => 'Starten';

  @override
  String get calibrationWrite => 'Schreiben';

  @override
  String get calibrationCancelTitle => 'Kalibrierung abbrechen?';

  @override
  String get calibrationCancelConfirm =>
      'Es gibt ungespeicherte Kalibrierungsmessungen. Verwerfen und beenden?';

  @override
  String get calibrationDiscard => 'Verwerfen';

  @override
  String get calibrationNotConnected => 'Zuerst mit dem DistoX verbinden';

  @override
  String get delete => 'Löschen';

  @override
  String get calibrationEnvironmentText =>
      'Die Umgebung muss magnetisch ungestört sein (Höhle oder Wald). Gebäude und Metallgegenstände verderben die Kalibrierung.';

  @override
  String get calibrationModeIndicator => 'CAL';

  @override
  String get calibrationDirection0 => 'Vorne';

  @override
  String get calibrationDirection1 => 'Rechts';

  @override
  String get calibrationDirection2 => 'Hinten';

  @override
  String get calibrationDirection3 => 'Links';

  @override
  String get calibrationDirection4 => 'Vorne-rechts, obere Ecke';

  @override
  String get calibrationDirection5 => 'Rechts-hinten, obere Ecke';

  @override
  String get calibrationDirection6 => 'Hinten-links, obere Ecke';

  @override
  String get calibrationDirection7 => 'Links-vorne, obere Ecke';

  @override
  String get calibrationDirection8 => 'Vorne-rechts, untere Ecke';

  @override
  String get calibrationDirection9 => 'Rechts-hinten, untere Ecke';

  @override
  String get calibrationDirection10 => 'Hinten-links, untere Ecke';

  @override
  String get calibrationDirection11 => 'Links-vorne, untere Ecke';

  @override
  String get calibrationDirection12 => 'Oben';

  @override
  String get calibrationDirection13 => 'Unten';

  @override
  String calibrationDirectionN(int n) {
    return 'Richtung $n';
  }

  @override
  String get calibrationDisplayUp => 'Display oben';

  @override
  String get calibrationDisplayRight => 'Display rechts';

  @override
  String get calibrationDisplayDown => 'Display unten';

  @override
  String get calibrationDisplayLeft => 'Display links';

  @override
  String get calibrationDisplayForward => 'Display vorne';

  @override
  String get calibrationDisplayBackward => 'Display hinten';

  @override
  String get calibrationAimPrecisely => 'Genau zielen';

  @override
  String get calibrationUndoLastShot => 'Letzte Messung verwerfen';

  @override
  String get calibrationUndoConfirm =>
      'Die letzte Messung verwerfen und wiederholen?';

  @override
  String get calibrationRetake => 'Wiederholen';

  @override
  String get calibrationHighErrorTitle => 'Hoher Kalibrierungsfehler';

  @override
  String calibrationHighErrorConfirm(String error, String limit) {
    return 'Der Kalibrierungsfehler beträgt $error und liegt über der Grenze von $limit. Das Wiederholen der markierten Richtungen kann ihn senken.\n\nDiese Koeffizienten trotzdem auf das Gerät schreiben?';
  }

  @override
  String get calibrationWriteAnyway => 'Trotzdem schreiben';

  @override
  String get calibrationDirectionsToRetake => 'Zu wiederholende Richtungen';

  @override
  String get calibrationAllDirectionsGood => 'Alle Richtungen sind in Ordnung';

  @override
  String get calibrationProblemCoverage =>
      'Die Messungen decken zu wenige Richtungen ab, um die Kalibrierung zu beurteilen. Den angezeigten Richtungen folgen.';

  @override
  String get calibrationProblemUnsteady =>
      'Das Gerät hat sich während der Messungen bewegt. Es ruhig halten, bis sich jeder Messwert stabilisiert hat.';

  @override
  String get calibrationProblemMagnetic =>
      'Das Magnetfeld war nicht bei allen Messungen gleich. Abstand zu Metall, Fahrzeugen und Stromleitungen halten.';

  @override
  String get calibrationProblemAiming =>
      'Die Messungen der horizontalen Richtungen treffen nicht denselben Punkt. Alle vier Messungen jeder Richtung genau auf denselben festen Zielpunkt richten.';

  @override
  String get calibrationFixDirection => 'in die angezeigte Richtung zielen';

  @override
  String get calibrationFixTarget => 'auf denselben Punkt zielen';

  @override
  String get calibrationFixOrientation => 'das Display wie angezeigt drehen';

  @override
  String get calibrationFixSteady => 'das Gerät ruhig halten';

  @override
  String get calibrationFixMagnetic => 'Abstand zu Metall halten';

  @override
  String calibrationFixesJoined(String first, String last) {
    return '$first und $last';
  }
}
