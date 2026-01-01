# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

This project aims to re-implement **PocketTopo** in Flutter for modern mobile devices (iOS/Android). PocketTopo is cave surveying software originally written for Windows Mobile by Beat Heeb.

### Target Features (from PocketTopo)
- **DistoX integration**: Connect to DistoX laser distance meters via Bluetooth to receive survey measurements
- **Survey data management**: Table view showing measurement records (from/to stations, distance, azimuth, inclination)
- **Map view**: Display connected survey stations as a 2D cave map
- **Sketching**: Draw cave walls and features on top of survey shots (plan and profile views)
- **Export**: Support for Therion, VisualTopo, and DXF formats

### Reference
- Original PocketTopo: https://paperless.bheeb.ch/
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

Flutter application for cave surveying. Currently in early development with basic data table UI.

### Core Domain (`lib/topo.dart`)
- `Point`: Represents a survey point with corridor and point IDs
- `MeasuredDistance`: Represents a measurement between two points, storing distance, azimuth, and inclination

### UI Structure
- `main.dart`: App entry point with `MyApp` (root widget) and `MyHomePage` (main screen with stateful measurement data management)
- `table.dart`: Custom `DataTable` widget for displaying measurement data with editable cells

### Key Patterns
- State management uses Flutter's built-in `StatefulWidget` pattern
- The `table.dart` module is imported with alias `tbl` to avoid conflicts with Flutter's built-in DataTable
- Linting configured via `flutter_lints` package
