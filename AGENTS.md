# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Repository Layout

The git root **is** the Flutter project root: `pubspec.yaml`, `lib/`, `test/`
and the platform directories all live directly at the top level, so `flutter`
and `dart` commands work from anywhere in the repo. All paths in this document
are relative to the git root.

## Project Goal

This project aims to re-implement **PocketTopo** in Flutter for modern mobile devices (iOS/Android). PocketTopo is cave surveying software originally written for Windows Mobile by Beat Heeb.

### Target Features (from PocketTopo)

**Three Main Views:**
- **Data View**: Table of measured stretches (From, To, Distance, Declination, Inclination) and reference points (entrance coordinates with East, North, Altitude)
- **Map View**: Overview of the whole cave showing all stations and survey shots
- **Sketch View**: Drawing on top of survey data with separate outline (plan) and side view (profile) sketches

**Core Functionality:**
- **DistoX integration**: Bluetooth connection to receive measurements; supports "smart mode" (auto-detect 3 identical shots as a survey shot)
  - The DistoX speaks **Bluetooth Classic SPP (RFCOMM)**, not BLE. BLE packages
    (`flutter_blue_plus` and friends) cannot talk to it — do not suggest them.
  - Available on **Android and macOS only**. iOS cannot reach classic SPP
    devices without Apple MFi enrollment, which the DistoX does not have, so
    this is permanently out of reach rather than unimplemented. See
    "Platform support" in `README.md`.
- **Station IDs**: Format `a.b` where `a` is typically the series/corridor number and `b` is the point number
- **Cross-sections**: Multiple measurements at arbitrary angles per station for passage dimensions
- **Trips**: Metadata per survey session (date, declination correction, comment).
  Unlike PocketTopo, trip data is not copied into every measurement and the
  active trip is not a setting: each trip is its own file with an ID, stretches
  store only the trip ID, and new measurements always go to the cave's
  active trip: the one most recently created, or made active from its trip
  page (which asks first if the trip is not from today). Trips are created
  and edited from the explorer.
  When the active trip is from an earlier day or missing, a warning bar
  appears above the bottom navigation on every tab, and connecting the DistoX
  asks to keep it or start a new one
- **Automatic declination**: a trip's declination is either set by hand or
  computed (the default for new trips and PocketTopo's "auto" trips) from
  the trip date with the IGRF-14 magnetic model. It is computed at the
  cave's first reference point if it fits the cave's coordinate system,
  else at the Hölloch entrance; the cave page warns about the latter.
  The model gives it against true north; positions use it against grid
  north, adding the meridian convergence where it is computed, in the
  cave's coordinate system. Manual declinations are against map north, as in
  PocketTopo, and the Therion export writes them as `grid-angle`
- **Coordinate systems**: each cave picks the system its reference points
  are given in: Swiss grid, UTM with zone and hemisphere, or
  WGS84 longitude/latitude. New caves start with the one set in the
  options (Swiss grid by default). Each reference point keeps its coordinates as
  entered along with the system they were entered in, so changing the
  cave's system changes no data. They are shown and edited converted to
  the cave's system, East and North in its unit (metres or degrees), and
  stored in it once East or North is edited. Points without a system (old
  files, imports) take the cave's. For positions and exports, degrees
  become metres in the UTM zone of the cave
- **Undo/Redo**: Separate undo stacks for data view, outline sketch, and side view sketch

**Import/Export:**
- Import: Toporobot format
- Export: Text, Toporobot, Therion, DXF (outline and side view drawings)
- Native format: `.top` binary files

### Reference
- PocketTopo manual: `docs/pocket_topo/PocketTopoManual.txt`
- Original PocketTopo website: https://paperless.bheeb.ch/
- Similar Android app (SexyTopo): https://github.com/richsmith/sexytopo

## Build and Development Commands

The toolchain is pinned with [mise](https://mise.jdx.dev/) in `mise.toml` at the
repo root. mise is shell-activated, so `flutter`, `dart`, and `java` are on
`PATH` directly — **never prefix commands with `mise exec`**.

Prefer the mise tasks: they run in the repo root regardless of where you invoke
them from.

```bash
mise run get           # flutter pub get
mise run analyze       # flutter analyze
mise run test          # flutter test
mise run run           # flutter run  (append -- -d <device_id> for a device)
mise run l10n          # flutter gen-l10n
mise run icons         # render app icons from assets/logo/*.svg (macOS only)
mise run build-macos   # flutter build macos --debug
mise run build-apk     # flutter build apk --debug
mise run build-apk-release  # signed release APK; releases: "Releasing" in README.md
mise run build-ios     # flutter build ios --no-codesign --debug
mise run doctor        # flutter doctor -v
```

For anything without a task, run `flutter`/`dart` directly from the repo root:

```bash
flutter test test/widget_test.dart    # single test file
flutter pub outdated
```

Setup prerequisites (Xcode, Android SDK, why CocoaPods must not be installed)
are documented in `README.md`.

Two `flutter doctor` warnings are expected and must not be "fixed":
`CocoaPods not installed` (both Apple targets are Swift Package Manager only)
and `Chrome not found` (web target only).

## Architecture

Flutter application for cave surveying using MVC architecture.

```
lib/
├── models/           # Domain models (pure data classes)
├── controllers/      # State management
├── services/         # Business logic and external device communication
├── data/             # Data persistence layer
├── views/            # UI layer
│   └── widgets/      # Reusable UI components
├── l10n/             # Localization
└── main.dart         # App entry point
```

### Models (`lib/models/`)

Pure domain objects without serialization logic:

- **`survey.dart`**: Core survey data types
  - `Point`: Survey station with `corridorId` and `pointId` (maps to PocketTopo's `a.b` format)
  - `MeasuredDistance`: A "stretch" between two stations with distance, azimuth, inclination and an optional comment
  - `ReferencePoint`: Entrance coordinates with station ID, east, north, altitude, the coordinate system they were entered in and an optional comment
  - `StationPosition`: Calculated 3D position of a station
  - `Survey`: Collection of stretches and reference points with position computation

- **`trip.dart`**: `Trip` with ID, date, declination correction or
  automatic declination, comment, creation time and the time it was last
  made active

- **`cave.dart`**: Explorer hierarchy
  - `Cave`: Top-level container with areas, sections, trips and the
    coordinate system of its reference points; the trip most recently
    created or made active is the active one. Its first reference point
    gives its coordinates. `declinationOf` gives a trip's declination,
    computing automatic ones at `declinationPosition`; `corrected` (and so
    `combinedSurvey`) applies it to each stretch's azimuth and puts the
    reference points in metres
  - `Area`: Organizational container (can nest)
  - `Section`: Leaf node containing survey data and sketches

- **`geo_position.dart`**: `GeoPosition` in WGS84 degrees

- **`coordinate_system.dart`**: `CoordinateSystem` (`SwissGrid` with LV95
  and LV03 told apart by size, `Utm`, `Wgs84`) converting East and North
  to and from a `GeoPosition`. The projections are computed by the
  `proj4dart` package from their EPSG definitions, as PROJ (and so
  Therion) has them; do not hand-roll projection formulas

- **`magnetic_declination.dart`**: `MagneticDeclination.at` computes the
  declination for a position and date from the IGRF-14, whose coefficients
  `igrf_coefficients.dart` holds verbatim from IAGA's table

- **`sketch.dart`**: Drawing primitives
  - `Stroke`: Single polyline with color and width
  - `Sketch`: Collection of strokes and cross sections
  - `SketchColors`: Available drawing colors
  - `SketchMode`: Drawing mode enum (move, draw, erase)

- **`cross_section.dart`**: `CrossSection` placed in a sketch (PocketTopo's
  "XSection"): a station copy whose cross section measurements are projected
  from the current survey data when drawn, either vertical (looking along the
  passage) or horizontal (seen from above, north up)

- **`side_view.dart`**: `SideView` lays out the extended elevation for the
  side view sketch: shots run left to right in survey direction, splays are
  projected onto the survey direction at their station

- **`explorer_path.dart`**: Navigation path helper for cave hierarchy

- **`settings.dart`**: App settings
  - `Settings`: Configuration options (smart mode, shot direction, units, etc.)
  - `LengthUnit`, `AngleUnit`, `ShotDirection`: Enums for measurement preferences.
    Data is always stored in meters and degrees; the unit enums convert to
    and from the unit chosen for display and editing

### Controllers (`lib/controllers/`)

State management classes using `ChangeNotifier`:

- **`selection_state.dart`**: Tracks currently selected section across views
- **`explorer_state.dart`**: Holds all caves and current navigation path
- **`settings_controller.dart`**: App settings state with change notification
- **`history.dart`**: Generic undo/redo stack for any type (max 50 items)
- **`view_navigation.dart`**: Requests to show a station in another view
  (PocketTopo's "-> Map" etc.) or the data view's reference points;
  `MainScreen` switches the tab and the target view takes the request

### Services (`lib/services/`)

Business logic and external device communication:

- **`distox_service.dart`**: DistoX Bluetooth connection management
  - `DistoXService`: Handles discovery, connection, auto-reconnect
  - `DistoXDevice`: Represents a discovered DistoX device
  - `DistoXConnectionState`: Connection state enum
  - Delegates all platform work to `BluetoothAdapter`; see `bluetooth_channel.dart`

- **`distox_protocol.dart`**: DistoX binary protocol implementation
  - `DistoXProtocol`: Parses 8-byte measurement packets, builds commands
  - `DistoXMeasurement`: Parsed measurement (distance, azimuth, inclination)
  - `DistoXPacketType`, `DistoXCommand`: Protocol constants
  - Handles sequence bit tracking and duplicate detection

- **`bluetooth_adapter.dart`**: Platform-agnostic Bluetooth interface
  - `BluetoothAdapter`: The seam every platform implements; `main.dart` picks one
  - Implementations: `bluetooth_adapter_android.dart`, `bluetooth_adapter_macos.dart`

- **`bluetooth_channel.dart`**: Platform channel shared by Android and macOS
  - `BluetoothChannel`: Method/event channel interface to native RFCOMM code
  - Native sides: `android/.../BluetoothPlugin.kt` (`BluetoothSocket`) and
    `macos/Runner/BluetoothPlugin.swift` (`IOBluetooth`). There is no
    third-party Bluetooth package — classic SPP support is written in-house.
  - `requestEnable`/`ensurePermissions` are Android-only; they degrade
    gracefully on macOS via `MissingPluginException`

- **`measurement_service.dart`**: Measurement processing and smart mode
  - `MeasurementService`: Routes DistoX measurements to survey data
  - Manages current/next station tracking
  - Applies smart mode detection via SmartModeDetector

- **`smart_mode_detector.dart`**: Smart mode triple detection
  - `SmartModeDetector`: Detects 3 nearly identical measurements
  - `RawMeasurement`: Input measurement with timestamp
  - `DetectedShot`: Output shot (splay or survey shot)
  - Thresholds: distance <0.05m, angular difference <1.7°
  - Emits each measurement immediately, then notifies when triple detected

- **`location_service.dart`**: `LocationService`, the device position for
  measuring reference points; `GeolocatorLocationService` implements it
  with the `geolocator` plugin at the best accuracy, on Android from the
  satellite receiver with sea level altitudes (`useMSLAltitude`)

- **`position_average.dart`**: `PositionAverage` averages position fixes
  weighted by the inverse square of their accuracy and reports their
  scatter

### Data Layer (`lib/data/`)

Persistence and serialization:

- **`cave_repository.dart`**: Abstract repository interface
- **`local_cave_repository.dart`**: File-based implementation
- **`cave_file.dart`**: JSON serialization for cave metadata
- **`section_file.dart`**: JSON serialization for section data
- **`sketch_serialization.dart`**: Binary serialization for sketches
  (format version 2 adds cross sections; version 1 files still load)
- **`settings_repository.dart`**: SharedPreferences-based settings persistence
- **`pocket_topo_file.dart`**: Reads PocketTopo `.top` files (format in
  `docs/pocket_topo/PocketTopoFileFormat.txt`) into trips, a survey and
  sketches; repeated measurements of a survey shot are averaged
- **`therion_file.dart`**: Writes sections for Therion, either as a `.th`
  survey file (a centreline per trip, fixed stations as entered with the
  cave's coordinate system as `cs`) or as the `.txt` PocketTopo exports
  for Therion, which xtherion imports with the sketches (fixed stations in
  metres, as the format has no coordinate system)

**File structure on disk:**
```
caves/
└── {cave-id}/
    ├── cave.json
    ├── trips/
    │   └── {trip-id}.json
    └── sections/
        └── {section-id}/
            ├── section.json
            ├── outline.sketch
            └── sideview.sketch
```

### Views (`lib/views/`)

UI widgets:

- **`data_view.dart`**: Table of stretches and reference points, handles DistoX measurements
- **`map_view.dart`**: 2D overview of survey with pan/zoom
- **`sketch_view.dart`**: Drawing canvas with outline/side view toggle
- **`explorer_view.dart`**: Cave/section browser; an expanded cave shows
  a sections node (expanded by default) and a trips node, each with a plus
  button: the sections one adds an empty section or imports PocketTopo
  files, each as a new section of the cave, adding the trips the cave
  does not have yet (same day, declination and comment). Tapping a node
  with children expands it; a cave's page opens from the info button at
  the end of its row, a section's page when the section is tapped. A new
  cave or section gets the default name and its page opens right away,
  editing the name, as a new trip's does. The pages export and delete
  them, a section after
  asking, along with the trips no other section uses unless the user
  keeps them
- **`cave_page.dart`**: Cave overview page titled with the cave's
  editable name: surveyed length and height difference of the whole cave,
  its coordinate system, the coordinates the automatic declination uses
  in that system (the first reference
  point's, or the Hölloch's with a warning and a way to the reference
  points), exporting the cave for Therion under the name as edited, and
  deleting it
- **`section_page.dart`**: Section overview page titled with the
  section's editable name: surveyed length, height difference, number of
  stations and of trips measured on, a button opening the section in the
  data, map and sketch views, exporting it for Therion under the name as
  edited, and deleting it
- **`options_view.dart`**: Settings UI (smart mode, shot direction, units and the coordinate system for new caves, DistoX connection)
- **`widgets/coordinate_system_field.dart`**: Picks a coordinate system, with zone and hemisphere for UTM; used on the cave page and in the options
- **`widgets/data_tables.dart`**: Reusable table components
- **`widgets/station_markers.dart`**: Station hit testing, drawing and status
  text shared by the map and sketch views
- **`trip_page.dart`**: Trip edit page opened from the explorer
- **`widgets/trip_picker.dart`**: Picks a trip by day from a calendar, then
  from a list if several trips share the day; used to change a shot's trip
  in the data view
- **`widgets/position_measurement_dialog.dart`**: Measures the device
  position for a reference point (from its row menu), averaging fixes
  until the user takes the position, which is stored as WGS84 degrees
- **`widgets/choice_sheet.dart`**: Bottom sheet choosing one of a few
  options, each with an icon and a line of help; also the Therion export
  format choice of the cave and section pages
- **`widgets/trip_bar.dart`**: Trip warning bar and the trip check dialog,
  both driven by `MainScreen` in `main.dart`

### Localization (`lib/l10n/`)

- Uses Flutter's built-in localization with ARB files
- Template file: `app_en.arb` (English)
- German: `app_de.arb`, using the terms of PocketTopo's German manual
  (Messdaten, Fixpunkte, Plan, Grundriss, Seitenriss, Querschnitt, Tour,
  Messpunkt) and of the DistoX2 German calibration manual (Display oben,
  rechts, unten, links), in Swiss spelling (ss for ß, «» quotes) as
  PocketTopo has it. Every new string needs a German translation too
- To add a new language: create `app_<locale>.arb`, run `flutter gen-l10n`
  and list the language in `CFBundleLocalizations` of `ios/Runner/Info.plist`
  and `macos/Runner/Info.plist` and in
  `android/app/src/main/res/xml/locales_config.xml`, which offer it in the
  system's per-app language settings
- Without a translation for any of the device's languages the app falls
  back to English (`preferred-supported-locales` in `l10n.yaml`)
- Access strings via `AppLocalizations.of(context)!.<key>`

### Dependency Injection (`main.dart`)

Uses the `provider` package for dependency injection:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SelectionState()),
    ChangeNotifierProvider(create: (_) => ViewNavigation()),
    ChangeNotifierProvider.value(value: settingsController),
    ChangeNotifierProvider.value(value: distoXService),
    ChangeNotifierProvider.value(value: measurementService),
    Provider<CaveRepository>(create: (_) => LocalCaveRepository()),
    Provider<SettingsRepository>(create: (_) => settingsRepository),
    Provider<LocationService>(create: (_) => const GeolocatorLocationService()),
  ],
  child: const MyApp(),
)
```

Access in views:
- `context.watch<SelectionState>()` - Listen and rebuild on changes
- `context.watch<DistoXService>()` - Listen to connection state changes
- `context.read<MeasurementService>()` - Set up measurement callbacks
- `context.read<CaveRepository>()` - One-time access without rebuilding

### Key Patterns

- **MVC separation**: Models are pure data, controllers manage state, views handle UI
- **Provider pattern**: Dependencies injected via widget tree using `provider` package
- **State management**: `ChangeNotifier` with `context.watch()` for automatic rebuilds
- **Repository pattern**: Abstract interface for data persistence
- **Linting**: Configured via `flutter_lints` package
