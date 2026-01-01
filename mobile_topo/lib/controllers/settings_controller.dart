import 'package:flutter/foundation.dart';
import '../models/settings.dart';

/// Controller for app settings with change notification
class SettingsController extends ChangeNotifier {
  Settings _settings;

  SettingsController([Settings? initialSettings])
      : _settings = initialSettings ?? const Settings();

  Settings get settings => _settings;

  bool get smartModeEnabled => _settings.smartModeEnabled;
  set smartModeEnabled(bool value) {
    if (_settings.smartModeEnabled != value) {
      _settings = _settings.copyWith(smartModeEnabled: value);
      notifyListeners();
    }
  }

  ShotDirection get shotDirection => _settings.shotDirection;
  set shotDirection(ShotDirection value) {
    if (_settings.shotDirection != value) {
      _settings = _settings.copyWith(shotDirection: value);
      notifyListeners();
    }
  }

  LengthUnit get lengthUnit => _settings.lengthUnit;
  set lengthUnit(LengthUnit value) {
    if (_settings.lengthUnit != value) {
      _settings = _settings.copyWith(lengthUnit: value);
      notifyListeners();
    }
  }

  AngleUnit get angleUnit => _settings.angleUnit;
  set angleUnit(AngleUnit value) {
    if (_settings.angleUnit != value) {
      _settings = _settings.copyWith(angleUnit: value);
      notifyListeners();
    }
  }

  bool get showGrid => _settings.showGrid;
  set showGrid(bool value) {
    if (_settings.showGrid != value) {
      _settings = _settings.copyWith(showGrid: value);
      notifyListeners();
    }
  }

  bool get autoConnect => _settings.autoConnect;
  set autoConnect(bool value) {
    if (_settings.autoConnect != value) {
      _settings = _settings.copyWith(autoConnect: value);
      notifyListeners();
    }
  }

  /// Update all settings at once
  void updateSettings(Settings newSettings) {
    if (_settings != newSettings) {
      _settings = newSettings;
      notifyListeners();
    }
  }
}
