// lib/core/services/theme_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

class ThemeService {
  static const String _themeKey = 'app_theme';

  static Future<ThemeOption> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);

    switch (themeString) {
      case 'light':
        return ThemeOption.light;
      case 'dark':
        return ThemeOption.dark;
      case 'system':
      default:
        return ThemeOption.system;
    }
  }

  static Future<void> saveTheme(ThemeOption theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }
}
