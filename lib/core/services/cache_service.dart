// lib/core/services/cache_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Simple cache service for secure storage and preferences
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Secure storage for sensitive data
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Shared preferences for non-sensitive caching
  SharedPreferences? _prefs;

  // Storage keys
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _lastLoginKey = 'last_login';

  // Biometric preference keys
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricAvailableKey = 'biometric_available';
  static const String _biometricTypeKey = 'biometric_type';

  // Recent searches keys
  static const String _recentSearchesKey = 'rivrflow_recent_searches';
  static const int _maxRecentSearches = 5;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      print('CACHE_SERVICE: Initialized successfully');
    } catch (e) {
      print('CACHE_SERVICE: Error initializing: $e');
    }
  }

  // MARK: - Secure Authentication Storage

  /// Store authentication token securely
  Future<void> storeAuthToken(String token) async {
    try {
      await _secureStorage.write(key: _authTokenKey, value: token);
      print('CACHE_SERVICE: Auth token stored securely');
    } catch (e) {
      print('CACHE_SERVICE: Error storing auth token: $e');
      throw Exception('Failed to store authentication token');
    }
  }

  /// Get stored authentication token
  Future<String?> getAuthToken() async {
    try {
      final token = await _secureStorage.read(key: _authTokenKey);
      print(
        'CACHE_SERVICE: Auth token retrieved: ${token != null ? "exists" : "null"}',
      );
      return token;
    } catch (e) {
      print('CACHE_SERVICE: Error getting auth token: $e');
      return null;
    }
  }

  /// Store user authentication data
  Future<void> storeAuthData({
    required String userId,
    required String email,
    String? authToken,
  }) async {
    try {
      await Future.wait([
        _secureStorage.write(key: _userIdKey, value: userId),
        _secureStorage.write(key: _userEmailKey, value: email),
        _secureStorage.write(
          key: _lastLoginKey,
          value: DateTime.now().toIso8601String(),
        ),
        if (authToken != null)
          _secureStorage.write(key: _authTokenKey, value: authToken),
      ]);
      print('CACHE_SERVICE: Auth data stored securely');
    } catch (e) {
      print('CACHE_SERVICE: Error storing auth data: $e');
      throw Exception('Failed to store authentication data');
    }
  }

  /// Get stored user ID
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      print('CACHE_SERVICE: Error getting user ID: $e');
      return null;
    }
  }

  /// Get stored user email
  Future<String?> getUserEmail() async {
    try {
      return await _secureStorage.read(key: _userEmailKey);
    } catch (e) {
      print('CACHE_SERVICE: Error getting user email: $e');
      return null;
    }
  }

  /// Get last login timestamp
  Future<DateTime?> getLastLogin() async {
    try {
      final timestamp = await _secureStorage.read(key: _lastLoginKey);
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      print('CACHE_SERVICE: Error getting last login: $e');
      return null;
    }
  }

  /// Check if user has stored auth data
  Future<bool> hasAuthData() async {
    try {
      final userId = await getUserId();
      return userId != null && userId.isNotEmpty;
    } catch (e) {
      print('CACHE_SERVICE: Error checking auth data: $e');
      return false;
    }
  }

  /// Clear all secure authentication data
  Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _authTokenKey),
        _secureStorage.delete(key: _userIdKey),
        _secureStorage.delete(key: _userEmailKey),
        _secureStorage.delete(key: _lastLoginKey),
      ]);
      print('CACHE_SERVICE: Auth data cleared');
    } catch (e) {
      print('CACHE_SERVICE: Error clearing auth data: $e');
    }
  }

  // MARK: - Biometric Preferences Caching

  /// Cache biometric availability
  Future<void> cacheBiometricAvailable(bool available) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setBool(_biometricAvailableKey, available);
      print('CACHE_SERVICE: Biometric availability cached: $available');
    } catch (e) {
      print('CACHE_SERVICE: Error caching biometric availability: $e');
    }
  }

  /// Get cached biometric availability
  bool? getCachedBiometricAvailable() {
    try {
      return _prefs?.getBool(_biometricAvailableKey);
    } catch (e) {
      print('CACHE_SERVICE: Error getting cached biometric availability: $e');
      return null;
    }
  }

  /// Cache biometric enabled status
  Future<void> cacheBiometricEnabled(bool enabled) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setBool(_biometricEnabledKey, enabled);
      print('CACHE_SERVICE: Biometric enabled status cached: $enabled');
    } catch (e) {
      print('CACHE_SERVICE: Error caching biometric enabled status: $e');
    }
  }

  /// Get cached biometric enabled status
  bool? getCachedBiometricEnabled() {
    try {
      return _prefs?.getBool(_biometricEnabledKey);
    } catch (e) {
      print('CACHE_SERVICE: Error getting cached biometric enabled status: $e');
      return null;
    }
  }

  /// Cache biometric type (fingerprint, face, etc.)
  Future<void> cacheBiometricType(String type) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setString(_biometricTypeKey, type);
      print('CACHE_SERVICE: Biometric type cached: $type');
    } catch (e) {
      print('CACHE_SERVICE: Error caching biometric type: $e');
    }
  }

  /// Get cached biometric type
  String? getCachedBiometricType() {
    try {
      return _prefs?.getString(_biometricTypeKey);
    } catch (e) {
      print('CACHE_SERVICE: Error getting cached biometric type: $e');
      return null;
    }
  }

  /// Clear all biometric preferences
  Future<void> clearBiometricPreferences() async {
    try {
      await _ensurePrefsInitialized();
      await Future.wait([
        _prefs!.remove(_biometricAvailableKey),
        _prefs!.remove(_biometricEnabledKey),
        _prefs!.remove(_biometricTypeKey),
      ]);
      print('CACHE_SERVICE: Biometric preferences cleared');
    } catch (e) {
      print('CACHE_SERVICE: Error clearing biometric preferences: $e');
    }
  }

  // MARK: - Recent Search Caching

  /// Load recent searches from cache
  Future<List<Map<String, dynamic>>> getRecentSearches() async {
    try {
      await _ensurePrefsInitialized();
      final jsonString = _prefs!.getString(_recentSearchesKey);
      if (jsonString == null) {
        print('CACHE_SERVICE: No recent searches found');
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final searches = jsonList.cast<Map<String, dynamic>>();
      print('CACHE_SERVICE: Loaded ${searches.length} recent searches');
      return searches;
    } catch (e) {
      print('CACHE_SERVICE: Error loading recent searches: $e');
      return [];
    }
  }

  /// Save recent searches to cache
  Future<void> storeRecentSearches(List<Map<String, dynamic>> searches) async {
    try {
      await _ensurePrefsInitialized();
      final jsonString = jsonEncode(searches);
      await _prefs!.setString(_recentSearchesKey, jsonString);
      print('CACHE_SERVICE: Stored ${searches.length} recent searches');
    } catch (e) {
      print('CACHE_SERVICE: Error storing recent searches: $e');
    }
  }

  /// Add a new search to recent searches (maintains max limit and deduplicates)
  Future<List<Map<String, dynamic>>> addRecentSearch(
    Map<String, dynamic> searchData,
  ) async {
    try {
      // Get current searches
      final currentSearches = await getRecentSearches();

      // Remove if already exists (based on placeName)
      final placeName = searchData['placeName'] as String?;
      final updated = currentSearches
          .where((search) => search['placeName'] != placeName)
          .toList();

      // Add to beginning
      updated.insert(0, searchData);

      // Keep only max recent searches
      final trimmed = updated.take(_maxRecentSearches).toList();

      // Save to cache
      await storeRecentSearches(trimmed);

      print('CACHE_SERVICE: Added recent search: $placeName');
      return trimmed;
    } catch (e) {
      print('CACHE_SERVICE: Error adding recent search: $e');
      return [];
    }
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.remove(_recentSearchesKey);
      print('CACHE_SERVICE: Recent searches cleared');
    } catch (e) {
      print('CACHE_SERVICE: Error clearing recent searches: $e');
    }
  }

  /// Get number of recent searches
  Future<int> getRecentSearchesCount() async {
    final searches = await getRecentSearches();
    return searches.length;
  }

  // MARK: - General Cache Methods

  /// Store string value in preferences
  Future<void> storeString(String key, String value) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setString(key, value);
      print('CACHE_SERVICE: String stored for key: $key');
    } catch (e) {
      print('CACHE_SERVICE: Error storing string for key $key: $e');
    }
  }

  /// Get string value from preferences
  String? getString(String key) {
    try {
      return _prefs?.getString(key);
    } catch (e) {
      print('CACHE_SERVICE: Error getting string for key $key: $e');
      return null;
    }
  }

  /// Store boolean value in preferences
  Future<void> storeBool(String key, bool value) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setBool(key, value);
      print('CACHE_SERVICE: Bool stored for key: $key');
    } catch (e) {
      print('CACHE_SERVICE: Error storing bool for key $key: $e');
    }
  }

  /// Get boolean value from preferences
  bool? getBool(String key) {
    try {
      return _prefs?.getBool(key);
    } catch (e) {
      print('CACHE_SERVICE: Error getting bool for key $key: $e');
      return null;
    }
  }

  /// Store integer value in preferences
  Future<void> storeInt(String key, int value) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.setInt(key, value);
      print('CACHE_SERVICE: Int stored for key: $key');
    } catch (e) {
      print('CACHE_SERVICE: Error storing int for key $key: $e');
    }
  }

  /// Get integer value from preferences
  int? getInt(String key) {
    try {
      return _prefs?.getInt(key);
    } catch (e) {
      print('CACHE_SERVICE: Error getting int for key $key: $e');
      return null;
    }
  }

  /// Remove value from preferences
  Future<void> remove(String key) async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.remove(key);
      print('CACHE_SERVICE: Value removed for key: $key');
    } catch (e) {
      print('CACHE_SERVICE: Error removing value for key $key: $e');
    }
  }

  /// Clear all non-secure cache data
  Future<void> clearAll() async {
    try {
      await _ensurePrefsInitialized();
      await _prefs!.clear();
      print('CACHE_SERVICE: All preferences cleared');
    } catch (e) {
      print('CACHE_SERVICE: Error clearing all preferences: $e');
    }
  }

  /// Clear everything (secure and non-secure)
  Future<void> clearEverything() async {
    await Future.wait([clearAuthData(), clearAll()]);
    print('CACHE_SERVICE: Everything cleared');
  }

  // MARK: - Helper Methods

  /// Ensure SharedPreferences is initialized
  Future<void> _ensurePrefsInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  /// Check if cache service is ready to use
  bool get isReady => _prefs != null;

  /// Get cache size estimation (number of stored keys)
  Future<int> getCacheSize() async {
    try {
      await _ensurePrefsInitialized();
      return _prefs!.getKeys().length;
    } catch (e) {
      print('CACHE_SERVICE: Error getting cache size: $e');
      return 0;
    }
  }

  /// Debug method to list all cached keys
  Future<Set<String>> getAllKeys() async {
    try {
      await _ensurePrefsInitialized();
      return _prefs!.getKeys();
    } catch (e) {
      print('CACHE_SERVICE: Error getting all keys: $e');
      return <String>{};
    }
  }
}
