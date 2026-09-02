# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Repository Layout

The git root is **not** the Flutter project root. The Flutter package lives in
`mobile_topo/`, and all `flutter` and `dart` commands must be run from there.

Unless stated otherwise, paths in this document are relative to `mobile_topo/` —
so `lib/models/survey.dart` is `mobile_topo/lib/models/survey.dart` on disk.

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
    "Platform support" in `mobile_topo/README.md`.
- **Station IDs**: Format `a.b` where `a` is typically the series/corridor number and `b` is the point number
- **Cross-sections**: Multiple measurements at arbitrary angles per station for passage dimensions
- **Trip settings**: Metadata per survey session (date, declination correction, surveyors)
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
**git root**. mise is shell-activated, so `flutter`, `dart`, and `java` are on
`PATH` directly — **never prefix commands with `mise exec`**.

Prefer the mise tasks: each one sets its own working directory, so they work
from anywhere in the repo and remove the need to remember the `cd`.

```bash
mise run get           # flutter pub get
mise run analyze       # flutter analyze
mise run test          # flutter test
mise run run           # flutter run  (append -- -d <device_id> for a device)
mise run l10n          # flutter gen-l10n
mise run build-macos   # flutter build macos --debug
mise run build-apk     # flutter build apk --debug
mise run build-ios     # flutter build ios --no-codesign --debug
mise run doctor        # flutter doctor -v
```

For anything without a task, `cd mobile_topo` first — raw `flutter`/`dart`
commands fail at the git root because `pubspec.yaml` is not there:

```bash
cd mobile_topo
flutter test test/widget_test.dart    # single test file
flutter pub outdated
```

Setup prerequisites (Xcode, Android SDK, why CocoaPods must not be installed)
are documented in `mobile_topo/README.md`.

Two `flutter doctor` warnings are expected and must not be "fixed":
`CocoaPods not installed` (both Apple targets are Swift Package Manager only)
and `Chrome not found` (web target only).

## Architecture

Flutter application for cave surveying using MVC architecture.

```
mobile_topo/lib/
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
  - `MeasuredDistance`: A "stretch" between two stations with distance, azimuth, and inclination
  - `ReferencePoint`: Entrance coordinates with station ID, east, north, and altitude
  - `StationPosition`: Calculated 3D position of a station
  - `Survey`: Collection of stretches and reference points with position computation

- **`cave.dart`**: Explorer hierarchy
  - `Cave`: Top-level container with areas and sections
  - `Area`: Organizational container (can nest)
  - `Section`: Leaf node containing survey data and sketches

- **`sketch.dart`**: Drawing primitives
  - `Stroke`: Single polyline with color and width
  - `Sketch`: Collection of strokes
  - `SketchColors`: Available drawing colors
  - `SketchMode`: Drawing mode enum (move, draw, erase)

- **`explorer_path.dart`**: Navigation path helper for cave hierarchy

- **`settings.dart`**: App settings
  - `Settings`: Configuration options (smart mode, shot direction, units, etc.)
  - `LengthUnit`, `AngleUnit`, `ShotDirection`: Enums for measurement preferences

### Controllers (`lib/controllers/`)

State management classes using `ChangeNotifier`:

- **`selection_state.dart`**: Tracks currently selected section across views
- **`explorer_state.dart`**: Holds all caves and current navigation path
- **`settings_controller.dart`**: App settings state with change notification
- **`history.dart`**: Generic undo/redo stack for any type (max 50 items)

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

### Data Layer (`lib/data/`)

Persistence and serialization:

- **`cave_repository.dart`**: Abstract repository interface
- **`local_cave_repository.dart`**: File-based implementation
- **`cave_file.dart`**: JSON serialization for cave metadata
- **`section_file.dart`**: JSON serialization for section data
- **`sketch_serialization.dart`**: Binary serialization for sketches
- **`settings_repository.dart`**: SharedPreferences-based settings persistence

**File structure on disk:**
```
caves/
└── {cave-id}/
    ├── cave.json
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
- **`explorer_view.dart`**: Cave/section browser
- **`options_view.dart`**: Settings UI (smart mode, shot direction, units, DistoX connection)
- **`widgets/data_tables.dart`**: Reusable table components

### Localization (`lib/l10n/`)

- Uses Flutter's built-in localization with ARB files
- Template file: `app_en.arb` (English)
- To add a new language: create `app_<locale>.arb` and run `flutter gen-l10n`
- Access strings via `AppLocalizations.of(context)!.<key>`

### Dependency Injection (`main.dart`)

Uses the `provider` package for dependency injection:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SelectionState()),
    ChangeNotifierProvider.value(value: settingsController),
    ChangeNotifierProvider.value(value: distoXService),
    ChangeNotifierProvider.value(value: measurementService),
    Provider<CaveRepository>(create: (_) => LocalCaveRepository()),
    Provider<SettingsRepository>(create: (_) => settingsRepository),
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
