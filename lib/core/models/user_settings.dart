// lib/core/models/user_settings.dart
class UserSettings {
  final String userId; // Firebase Auth UID
  final List<String> favoriteReaches; // List of reach IDs
  final bool enableNotifications;
  final String preferredUnits; // "cfs" vs "cms"
  final bool showReturnPeriods;
  final bool enableDarkMode;

  // Additional settings for better UX
  final bool enableLocationServices;
  final int refreshIntervalMinutes; // Auto-refresh frequency
  final double
  notificationThreshold; // Flow threshold for alerts (in preferred units)
  final List<String> notificationReaches; // Specific reaches for notifications
  final String temperatureUnit; // "celsius" vs "fahrenheit"
  final bool enableSound; // Sound for notifications
  final bool enableVibration; // Vibration for notifications
  final String dateFormat; // "12h" vs "24h"
  final DateTime lastUpdated; // When settings were last modified

  UserSettings({
    required this.userId,
    required this.favoriteReaches,
    required this.enableNotifications,
    required this.preferredUnits,
    required this.showReturnPeriods,
    required this.enableDarkMode,
    required this.enableLocationServices,
    required this.refreshIntervalMinutes,
    required this.notificationThreshold,
    required this.notificationReaches,
    required this.temperatureUnit,
    required this.enableSound,
    required this.enableVibration,
    required this.dateFormat,
    required this.lastUpdated,
  });

  // Factory constructor with default values for new users
  factory UserSettings.defaultSettings(String userId) {
    return UserSettings(
      userId: userId,
      favoriteReaches: [],
      enableNotifications: true,
      preferredUnits: 'cfs',
      showReturnPeriods: true,
      enableDarkMode: false,
      enableLocationServices: true,
      refreshIntervalMinutes: 5,
      notificationThreshold: 1000.0, // 1000 CFS default
      notificationReaches: [],
      temperatureUnit: 'fahrenheit',
      enableSound: true,
      enableVibration: true,
      dateFormat: '12h',
      lastUpdated: DateTime.now(),
    );
  }

  // Factory constructor from Firebase/JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    try {
      return UserSettings(
        userId: json['userId'] as String,
        favoriteReaches:
            (json['favoriteReaches'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        enableNotifications: json['enableNotifications'] as bool? ?? true,
        preferredUnits: _validateUnits(json['preferredUnits'] as String?),
        showReturnPeriods: json['showReturnPeriods'] as bool? ?? true,
        enableDarkMode: json['enableDarkMode'] as bool? ?? false,
        enableLocationServices: json['enableLocationServices'] as bool? ?? true,
        refreshIntervalMinutes: _validateRefreshInterval(
          json['refreshIntervalMinutes'] as int?,
        ),
        notificationThreshold:
            (json['notificationThreshold'] as num?)?.toDouble() ?? 1000.0,
        notificationReaches:
            (json['notificationReaches'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        temperatureUnit: _validateTemperatureUnit(
          json['temperatureUnit'] as String?,
        ),
        enableSound: json['enableSound'] as bool? ?? true,
        enableVibration: json['enableVibration'] as bool? ?? true,
        dateFormat: _validateDateFormat(json['dateFormat'] as String?),
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Failed to parse UserSettings from JSON: $e');
    }
  }

  // Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'favoriteReaches': favoriteReaches,
      'enableNotifications': enableNotifications,
      'preferredUnits': preferredUnits,
      'showReturnPeriods': showReturnPeriods,
      'enableDarkMode': enableDarkMode,
      'enableLocationServices': enableLocationServices,
      'refreshIntervalMinutes': refreshIntervalMinutes,
      'notificationThreshold': notificationThreshold,
      'notificationReaches': notificationReaches,
      'temperatureUnit': temperatureUnit,
      'enableSound': enableSound,
      'enableVibration': enableVibration,
      'dateFormat': dateFormat,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Immutable update method
  UserSettings copyWith({
    List<String>? favoriteReaches,
    bool? enableNotifications,
    String? preferredUnits,
    bool? showReturnPeriods,
    bool? enableDarkMode,
    bool? enableLocationServices,
    int? refreshIntervalMinutes,
    double? notificationThreshold,
    List<String>? notificationReaches,
    String? temperatureUnit,
    bool? enableSound,
    bool? enableVibration,
    String? dateFormat,
  }) {
    return UserSettings(
      userId: userId,
      favoriteReaches: favoriteReaches ?? this.favoriteReaches,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      preferredUnits: preferredUnits != null
          ? _validateUnits(preferredUnits)
          : this.preferredUnits,
      showReturnPeriods: showReturnPeriods ?? this.showReturnPeriods,
      enableDarkMode: enableDarkMode ?? this.enableDarkMode,
      enableLocationServices:
          enableLocationServices ?? this.enableLocationServices,
      refreshIntervalMinutes: refreshIntervalMinutes != null
          ? _validateRefreshInterval(refreshIntervalMinutes)
          : this.refreshIntervalMinutes,
      notificationThreshold:
          notificationThreshold ?? this.notificationThreshold,
      notificationReaches: notificationReaches ?? this.notificationReaches,
      temperatureUnit: temperatureUnit != null
          ? _validateTemperatureUnit(temperatureUnit)
          : this.temperatureUnit,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      dateFormat: dateFormat != null
          ? _validateDateFormat(dateFormat)
          : this.dateFormat,
      lastUpdated: DateTime.now(),
    );
  }

  // Favorite reach management
  UserSettings addFavoriteReach(String reachId) {
    if (favoriteReaches.contains(reachId)) return this;

    return copyWith(favoriteReaches: [...favoriteReaches, reachId]);
  }

  UserSettings removeFavoriteReach(String reachId) {
    if (!favoriteReaches.contains(reachId)) return this;

    return copyWith(
      favoriteReaches: favoriteReaches.where((id) => id != reachId).toList(),
    );
  }

  UserSettings reorderFavorites(List<String> newOrder) {
    // Validate that all reaches are still present
    if (newOrder.length != favoriteReaches.length ||
        !newOrder.every((id) => favoriteReaches.contains(id))) {
      throw ArgumentError('Invalid reorder: missing or extra reaches');
    }

    return copyWith(favoriteReaches: newOrder);
  }

  // Notification reach management
  UserSettings addNotificationReach(String reachId) {
    if (notificationReaches.contains(reachId)) return this;

    return copyWith(notificationReaches: [...notificationReaches, reachId]);
  }

  UserSettings removeNotificationReach(String reachId) {
    if (!notificationReaches.contains(reachId)) return this;

    return copyWith(
      notificationReaches: notificationReaches
          .where((id) => id != reachId)
          .toList(),
    );
  }

  // Helper methods
  bool isFavorite(String reachId) => favoriteReaches.contains(reachId);
  bool hasNotificationsEnabled(String reachId) =>
      enableNotifications && notificationReaches.contains(reachId);

  bool get hasFavorites => favoriteReaches.isNotEmpty;
  bool get hasNotificationReaches => notificationReaches.isNotEmpty;

  // Units conversion helpers
  double convertFlow(double flowValue, String fromUnit) {
    if (fromUnit.toLowerCase() == preferredUnits.toLowerCase()) {
      return flowValue;
    }

    if (fromUnit.toLowerCase() == 'cfs' &&
        preferredUnits.toLowerCase() == 'cms') {
      return flowValue * 0.0283168; // CFS to CMS
    } else if (fromUnit.toLowerCase() == 'cms' &&
        preferredUnits.toLowerCase() == 'cfs') {
      return flowValue / 0.0283168; // CMS to CFS
    }

    return flowValue;
  }

  String formatFlow(double flowValue, {int decimals = 1}) {
    return '${flowValue.toStringAsFixed(decimals)} ${preferredUnits.toUpperCase()}';
  }

  String get flowUnitDisplay => preferredUnits.toUpperCase();
  String get temperatureUnitDisplay =>
      temperatureUnit == 'celsius' ? '°C' : '°F';

  // Refresh interval helpers
  Duration get refreshDuration => Duration(minutes: refreshIntervalMinutes);
  bool get isAutoRefreshEnabled => refreshIntervalMinutes > 0;

  // Validation helpers
  static String _validateUnits(String? units) {
    const validUnits = ['cfs', 'cms'];
    if (units == null || !validUnits.contains(units.toLowerCase())) {
      return 'cfs';
    }
    return units.toLowerCase();
  }

  static String _validateTemperatureUnit(String? unit) {
    const validUnits = ['celsius', 'fahrenheit'];
    if (unit == null || !validUnits.contains(unit.toLowerCase())) {
      return 'fahrenheit';
    }
    return unit.toLowerCase();
  }

  static String _validateDateFormat(String? format) {
    const validFormats = ['12h', '24h'];
    if (format == null || !validFormats.contains(format.toLowerCase())) {
      return '12h';
    }
    return format.toLowerCase();
  }

  static int _validateRefreshInterval(int? interval) {
    if (interval == null || interval < 0) return 5;
    if (interval > 60) return 60; // Max 1 hour
    return interval;
  }

  // Theme helpers
  bool get shouldUseDarkMode => enableDarkMode;

  // Notification helpers
  bool get canReceiveNotifications =>
      enableNotifications && (enableSound || enableVibration);

  String getNotificationSettings() {
    if (!enableNotifications) return 'Disabled';

    final features = <String>[];
    if (enableSound) features.add('Sound');
    if (enableVibration) features.add('Vibration');

    return features.isEmpty ? 'Silent' : features.join(' + ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'UserSettings{userId: $userId, favorites: ${favoriteReaches.length}, '
        'units: $preferredUnits, darkMode: $enableDarkMode, '
        'notifications: $enableNotifications}';
  }

  // Debug helper
  String toDebugString() {
    return '''
UserSettings Debug Info:
  User ID: $userId
  Favorites: ${favoriteReaches.length} reaches
  Preferred Units: $preferredUnits
  Dark Mode: $enableDarkMode
  Notifications: $enableNotifications
  Location Services: $enableLocationServices
  Refresh Interval: ${refreshIntervalMinutes}min
  Notification Threshold: ${formatFlow(notificationThreshold)}
  Notification Reaches: ${notificationReaches.length}
  Temperature Unit: $temperatureUnit
  Sound: $enableSound, Vibration: $enableVibration
  Date Format: $dateFormat
  Last Updated: $lastUpdated
''';
  }
}
