import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get notificationsEnabled => _notificationsEnabled;

  SettingsManager() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _stringToThemeMode(prefs.getString('selected_theme') ?? '기본');
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    notifyListeners();
  }

  Future<void> updateTheme(String theme) async {
    final newThemeMode = _stringToThemeMode(theme);
    if (_themeMode == newThemeMode) return;

    _themeMode = newThemeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', theme);
  }

  Future<void> updateSoundEnabled(bool enabled) async {
    if (_soundEnabled == enabled) return;
    _soundEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  ThemeMode _stringToThemeMode(String theme) {
    switch (theme) {
      case '라이트':
        return ThemeMode.light;
      case '다크':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String themeModeToString() {
    switch (_themeMode) {
      case ThemeMode.light:
        return '라이트';
      case ThemeMode.dark:
        return '다크';
      case ThemeMode.system:
      default:
        return '기본';
    }
  }
}
