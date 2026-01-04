# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

This project aims to re-implement **PocketTopo** in Flutter for modern mobile devices (iOS/Android). PocketTopo is cave surveying software originally written for Windows Mobile by Beat Heeb.

### Target Features (from PocketTopo)

**Three Main Views:**
- **Data View**: Table of measured stretches (From, To, Distance, Declination, Inclination) and reference points (entrance coordinates with East, North, Altitude)
- **Map View**: Overview of the whole cave showing all stations and survey shots
- **Sketch View**: Drawing on top of survey data with separate outline (plan) and side view (profile) sketches

**Core Functionality:**
- **DistoX integration**: Bluetooth connection to receive measurements; supports "smart mode" (auto-detect 3 identical shots as a survey shot)
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

```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device_id>

# Build for release
flutter build apk          # Android
flutter build ios          # iOS
flutter build macos        # macOS

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code (linting)
flutter analyze
```

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
  - Supports Android (flutter_bluetooth_serial) and macOS (platform channel)

- **`distox_protocol.dart`**: DistoX binary protocol implementation
  - `DistoXProtocol`: Parses 8-byte measurement packets, builds commands
  - `DistoXMeasurement`: Parsed measurement (distance, azimuth, inclination)
  - `DistoXPacketType`, `DistoXCommand`: Protocol constants
  - Handles sequence bit tracking and duplicate detection

- **`bluetooth_channel.dart`**: Platform channel for macOS Bluetooth
  - `BluetoothChannel`: Method/event channel interface to native code
  - Used when flutter_bluetooth_serial is unavailable

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
