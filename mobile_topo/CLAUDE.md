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

Flutter application for cave surveying. Currently in early development with basic navigation and data table UI.

### Core Domain (`lib/topo.dart`)
- `Point`: Survey station with `corridorId` and `pointId` (maps to PocketTopo's `a.b` station ID format)
- `MeasuredDistance`: A "stretch" between two stations with distance, azimuth (declination), and inclination
- `ReferencePoint`: Entrance coordinates with station ID, east, north, and altitude

### UI Structure
- `main.dart`: App entry point with `MainScreen` providing bottom navigation between 5 views
- `views/`: Separate view widgets for Data, Map, Sketch, Files, and Options
- `table.dart`: `StretchesTable` and `ReferencePointsTable` widgets for displaying survey data

### Localization
- Uses Flutter's built-in localization with ARB files in `lib/l10n/`
- Template file: `app_en.arb` (English)
- To add a new language: create `app_<locale>.arb` and run `flutter gen-l10n`
- Access strings via `AppLocalizations.of(context)!.<key>`

### Key Patterns
- State management uses Flutter's built-in `StatefulWidget` pattern
- Linting configured via `flutter_lints` package
