import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._preferences)
      : _themeMode = _preferences.getBool(_darkModePreferenceKey) ?? false
            ? ThemeMode.dark
            : ThemeMode.light;

  static const _darkModePreferenceKey = 'dark_mode_enabled';

  final SharedPreferences _preferences;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> setDarkMode(bool enabled) async {
    final saved = await _preferences.setBool(_darkModePreferenceKey, enabled);
    if (!saved) {
      throw StateError('Could not save the appearance preference.');
    }

    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
