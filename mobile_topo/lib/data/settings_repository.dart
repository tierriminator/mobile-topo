import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

/// Repository for persisting app settings
class SettingsRepository {
  static const String _settingsKey = 'app_settings';

  SharedPreferences? _prefs;
  bool _initFailed = false;

  Future<void> _ensureInitialized() async {
    if (_initFailed) return;
    if (_prefs != null) return;

    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // SharedPreferences may fail on some platforms (e.g., macOS without entitlements)
      debugPrint('SharedPreferences initialization failed: $e');
      _initFailed = true;
    }
  }

  /// Load settings from storage
  Future<Settings> load() async {
    await _ensureInitialized();
    if (_prefs == null) {
      return const Settings();
    }

    final jsonString = _prefs!.getString(_settingsKey);
    if (jsonString == null) {
      return const Settings();
    }
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Settings.fromJson(json);
    } catch (e) {
      return const Settings();
    }
  }

  /// Save settings to storage
  Future<void> save(Settings settings) async {
    await _ensureInitialized();
    if (_prefs == null) {
      debugPrint('Cannot save settings: SharedPreferences not available');
      return;
    }

    final jsonString = jsonEncode(settings.toJson());
    await _prefs!.setString(_settingsKey, jsonString);
  }
}
