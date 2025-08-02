// lib/core/services/reach_cache_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reach_data.dart';

/// Simple cache service for ReachData objects
/// Stores reach info permanently (6 months) to avoid repeated API calls for static data
class ReachCacheService {
  static final ReachCacheService _instance = ReachCacheService._internal();
  factory ReachCacheService() => _instance;
  ReachCacheService._internal();

  SharedPreferences? _prefs;

  // Cache configuration
  static const Duration _cacheMaxAge = Duration(days: 180); // 6 months
  static const String _keyPrefix = 'reach_cache_';

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      print('REACH_CACHE: Initialized successfully');
    } catch (e) {
      print('REACH_CACHE: Error initializing: $e');
    }
  }

  /// Get cached ReachData by reach ID
  /// Returns null if not cached or cache is stale
  Future<ReachData?> get(String reachId) async {
    try {
      await _ensureInitialized();

      final key = _keyPrefix + reachId;
      final cachedJson = _prefs!.getString(key);

      if (cachedJson == null) {
        print('REACH_CACHE: No cache found for reach: $reachId');
        return null;
      }

      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      final reachData = ReachData.fromJson(data);

      // Check if cache is stale (6 months)
      if (reachData.isCacheStale(maxAge: _cacheMaxAge)) {
        print(
          'REACH_CACHE: Cache stale for reach: $reachId (${reachData.cachedAt})',
        );
        // Remove stale cache
        await _prefs!.remove(key);
        return null;
      }

      print('REACH_CACHE: Cache hit for reach: $reachId');
      return reachData;
    } catch (e) {
      print('REACH_CACHE: Error getting cached reach $reachId: $e');
      return null;
    }
  }

  /// Store ReachData in cache
  Future<void> store(ReachData reachData) async {
    try {
      await _ensureInitialized();

      final key = _keyPrefix + reachData.reachId;
      final jsonString = jsonEncode(reachData.toJson());

      await _prefs!.setString(key, jsonString);
      print(
        'REACH_CACHE: Stored reach: ${reachData.reachId} (${reachData.displayName})',
      );
    } catch (e) {
      print('REACH_CACHE: Error storing reach ${reachData.reachId}: $e');
      // Don't throw - caching should not break the app
    }
  }

  /// Clear specific reach from cache
  Future<void> clearReach(String reachId) async {
    try {
      await _ensureInitialized();

      final key = _keyPrefix + reachId;
      await _prefs!.remove(key);
      print('REACH_CACHE: Cleared cache for reach: $reachId');
    } catch (e) {
      print('REACH_CACHE: Error clearing reach $reachId: $e');
    }
  }

  /// Clear all cached reaches
  Future<void> clear() async {
    try {
      await _ensureInitialized();

      final keys = _prefs!.getKeys();
      final reachKeys = keys.where((key) => key.startsWith(_keyPrefix));

      for (final key in reachKeys) {
        await _prefs!.remove(key);
      }

      print('REACH_CACHE: Cleared ${reachKeys.length} cached reaches');
    } catch (e) {
      print('REACH_CACHE: Error clearing all cache: $e');
    }
  }

  /// Check if reach is cached and valid
  Future<bool> isCached(String reachId) async {
    final cached = await get(reachId);
    return cached != null;
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      await _ensureInitialized();

      final keys = _prefs!.getKeys();
      final reachKeys = keys
          .where((key) => key.startsWith(_keyPrefix))
          .toList();

      int validCount = 0;
      int staleCount = 0;
      DateTime? oldestCache;
      DateTime? newestCache;

      for (final key in reachKeys) {
        try {
          final cachedJson = _prefs!.getString(key);
          if (cachedJson != null) {
            final data = jsonDecode(cachedJson) as Map<String, dynamic>;
            final reachData = ReachData.fromJson(data);

            if (reachData.isCacheStale(maxAge: _cacheMaxAge)) {
              staleCount++;
            } else {
              validCount++;
            }

            if (oldestCache == null ||
                reachData.cachedAt.isBefore(oldestCache)) {
              oldestCache = reachData.cachedAt;
            }
            if (newestCache == null ||
                reachData.cachedAt.isAfter(newestCache)) {
              newestCache = reachData.cachedAt;
            }
          }
        } catch (e) {
          // Skip invalid entries
          continue;
        }
      }

      return {
        'totalCached': reachKeys.length,
        'validCount': validCount,
        'staleCount': staleCount,
        'oldestCache': oldestCache?.toIso8601String(),
        'newestCache': newestCache?.toIso8601String(),
      };
    } catch (e) {
      print('REACH_CACHE: Error getting cache stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Force refresh a reach (clear cache and require fresh API call)
  Future<void> forceRefresh(String reachId) async {
    print('REACH_CACHE: Force refresh requested for reach: $reachId');
    await clearReach(reachId);
  }

  /// Clean up stale cache entries
  Future<int> cleanupStaleEntries() async {
    try {
      await _ensureInitialized();

      final keys = _prefs!.getKeys();
      final reachKeys = keys.where((key) => key.startsWith(_keyPrefix));
      int cleanedCount = 0;

      for (final key in reachKeys) {
        try {
          final cachedJson = _prefs!.getString(key);
          if (cachedJson != null) {
            final data = jsonDecode(cachedJson) as Map<String, dynamic>;
            final reachData = ReachData.fromJson(data);

            if (reachData.isCacheStale(maxAge: _cacheMaxAge)) {
              await _prefs!.remove(key);
              cleanedCount++;
            }
          }
        } catch (e) {
          // Remove invalid entries too
          await _prefs!.remove(key);
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        print('REACH_CACHE: Cleaned up $cleanedCount stale cache entries');
      }

      return cleanedCount;
    } catch (e) {
      print('REACH_CACHE: Error during cleanup: $e');
      return 0;
    }
  }

  /// Helper method to ensure SharedPreferences is initialized
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  /// Check if cache service is ready
  bool get isReady => _prefs != null;
}
