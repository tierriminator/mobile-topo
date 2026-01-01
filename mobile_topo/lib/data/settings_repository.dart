import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

/// Repository for persisting app settings
class SettingsRepository {
  static const String _settingsKey = 'app_settings';

  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load settings from storage
  Future<Settings> load() async {
    await _ensureInitialized();
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
    final jsonString = jsonEncode(settings.toJson());
    await _prefs!.setString(_settingsKey, jsonString);
  }
}
