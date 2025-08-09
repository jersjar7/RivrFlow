// lib/features/settings/pages/app_theme_settings_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum ThemeOption { light, dark, system }

/// App theme settings page with light, dark, and system options
class AppThemeSettingsPage extends StatefulWidget {
  const AppThemeSettingsPage({super.key});

  @override
  State<AppThemeSettingsPage> createState() => _AppThemeSettingsPageState();
}

class _AppThemeSettingsPageState extends State<AppThemeSettingsPage> {
  ThemeOption _selectedTheme = ThemeOption.system; // Default to system

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('App Theme'),
        previousPageTitle: 'Settings',
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Theme options section
            CupertinoListSection.insetGrouped(
              header: const Text('APPEARANCE'),
              footer: const Text(
                'Choose how RivrFlow looks. System will automatically switch between light and dark based on your device settings.',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                _buildThemeOption(
                  title: 'Light',
                  subtitle: 'Always use light appearance',
                  icon: CupertinoIcons.sun_max_fill,
                  themeOption: ThemeOption.light,
                ),
                _buildThemeOption(
                  title: 'Dark',
                  subtitle: 'Always use dark appearance',
                  icon: CupertinoIcons.moon_fill,
                  themeOption: ThemeOption.dark,
                ),
                _buildThemeOption(
                  title: 'System',
                  subtitle: 'Match device settings',
                  icon: CupertinoIcons.device_phone_portrait,
                  themeOption: ThemeOption.system,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Preview section
            CupertinoListSection.insetGrouped(
              header: const Text('PREVIEW'),
              children: [
                CupertinoListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.drop_fill,
                      color: CupertinoColors.white,
                      size: 18,
                    ),
                  ),
                  title: const Text('Sample River'),
                  subtitle: const Text('1,245 CFS • Optimal'),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.systemGrey3,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeOption themeOption,
  }) {
    final bool isSelected = _selectedTheme == themeOption;

    return CupertinoListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getIconBackgroundColor(themeOption),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: CupertinoColors.white, size: 18),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? const Icon(
              CupertinoIcons.checkmark,
              color: CupertinoColors.systemBlue,
              size: 20,
            )
          : null,
      onTap: () {
        setState(() {
          _selectedTheme = themeOption;
        });

        // Add haptic feedback
        HapticFeedback.selectionClick();

        // TODO: Implement actual theme switching logic
        print('Selected theme: ${themeOption.name}');
      },
    );
  }

  Color _getIconBackgroundColor(ThemeOption themeOption) {
    switch (themeOption) {
      case ThemeOption.light:
        return CupertinoColors.systemOrange;
      case ThemeOption.dark:
        return CupertinoColors.systemIndigo;
      case ThemeOption.system:
        return CupertinoColors.systemGrey;
    }
  }
}
