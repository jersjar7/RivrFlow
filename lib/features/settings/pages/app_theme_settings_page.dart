// lib/features/settings/pages/app_theme_settings_page.dart

import 'package:flutter/cupertino.dart';

/// Placeholder app theme settings page
class AppThemeSettingsPage extends StatelessWidget {
  const AppThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('App Theme')),
      child: const Center(
        child: Text(
          'App Theme Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
    );
  }
}
