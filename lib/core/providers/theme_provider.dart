// lib/core/providers/theme_provider.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum ThemeOption { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.system;
  Brightness _systemBrightness = Brightness.light;

  ThemeOption get themeOption => _themeOption;

  Brightness get currentBrightness {
    switch (_themeOption) {
      case ThemeOption.light:
        return Brightness.light;
      case ThemeOption.dark:
        return Brightness.dark;
      case ThemeOption.system:
        return _systemBrightness;
    }
  }

  CupertinoThemeData get themeData {
    return CupertinoThemeData(
      primaryColor: CupertinoColors.systemBlue,
      brightness: currentBrightness,
    );
  }

  void setTheme(ThemeOption option) {
    _themeOption = option;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness != brightness) {
      _systemBrightness = brightness;
      if (_themeOption == ThemeOption.system) {
        notifyListeners();
      }
    }
  }
}
