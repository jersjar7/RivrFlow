// lib/core/services/favorites_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_river.dart';

/// Simple service for managing user's favorite rivers
/// Uses SharedPreferences with JSON storage - no over-engineering
class FavoritesService {
  static const String _favoritesKey = 'user_favorite_rivers';

  /// Load all favorites from storage
  Future<List<FavoriteRiver>> loadFavorites() async {
    try {
      print('FAVORITES_SERVICE: Loading favorites from storage');
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_favoritesKey);

      if (jsonString == null) {
        print('FAVORITES_SERVICE: No favorites found - returning empty list');
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final favorites = jsonList
          .map((json) => FavoriteRiver.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by display order to maintain user's arrangement
      favorites.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      print('FAVORITES_SERVICE: ✅ Loaded ${favorites.length} favorites');
      return favorites;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error loading favorites: $e');
      return [];
    }
  }

  /// Save all favorites to storage
  Future<bool> saveFavorites(List<FavoriteRiver> favorites) async {
    try {
      print('FAVORITES_SERVICE: Saving ${favorites.length} favorites');
      final prefs = await SharedPreferences.getInstance();

      final jsonList = favorites.map((favorite) => favorite.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await prefs.setString(_favoritesKey, jsonString);
      print('FAVORITES_SERVICE: ✅ Favorites saved successfully');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error saving favorites: $e');
      return false;
    }
  }

  /// Add a new favorite river
  Future<bool> addFavorite(String reachId, {String? customName}) async {
    try {
      print('FAVORITES_SERVICE: Adding favorite: $reachId');
      final favorites = await loadFavorites();

      // Check if already exists
      if (favorites.any((f) => f.reachId == reachId)) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId already in favorites');
        return false;
      }

      // Create new favorite with next display order
      final maxOrder = favorites.isEmpty
          ? -1
          : favorites
                .map((f) => f.displayOrder)
                .reduce((a, b) => a > b ? a : b);

      final newFavorite = FavoriteRiver(
        reachId: reachId,
        customName: customName,
        displayOrder: maxOrder + 1,
      );

      favorites.add(newFavorite);
      final success = await saveFavorites(favorites);

      if (success) {
        print('FAVORITES_SERVICE: ✅ Added favorite: $reachId');
      }
      return success;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error adding favorite: $e');
      return false;
    }
  }

  /// Remove a favorite river
  Future<bool> removeFavorite(String reachId) async {
    try {
      print('FAVORITES_SERVICE: Removing favorite: $reachId');
      final favorites = await loadFavorites();

      final originalLength = favorites.length;
      favorites.removeWhere((f) => f.reachId == reachId);

      if (favorites.length == originalLength) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId not found in favorites');
        return false;
      }

      final success = await saveFavorites(favorites);
      if (success) {
        print('FAVORITES_SERVICE: ✅ Removed favorite: $reachId');
      }
      return success;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error removing favorite: $e');
      return false;
    }
  }

  /// Check if a reach is favorited
  Future<bool> isFavorite(String reachId) async {
    try {
      final favorites = await loadFavorites();
      return favorites.any((f) => f.reachId == reachId);
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error checking favorite status: $e');
      return false;
    }
  }

  /// Reorder favorites (for drag-and-drop)
  Future<bool> reorderFavorites(List<FavoriteRiver> reorderedFavorites) async {
    try {
      print(
        'FAVORITES_SERVICE: Reordering ${reorderedFavorites.length} favorites',
      );

      // Update display orders to match new arrangement
      final updatedFavorites = <FavoriteRiver>[];
      for (int i = 0; i < reorderedFavorites.length; i++) {
        final favorite = reorderedFavorites[i].copyWith(displayOrder: i);
        updatedFavorites.add(favorite);
      }

      final success = await saveFavorites(updatedFavorites);
      if (success) {
        print('FAVORITES_SERVICE: ✅ Favorites reordered successfully');
      }
      return success;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error reordering favorites: $e');
      return false;
    }
  }

  /// Update a favorite's properties (name, image, flow data)
  Future<bool> updateFavorite(
    String reachId, {
    String? customName,
    String? riverName, // ← ADDED: NOAA river name
    String? customImageAsset,
    double? lastKnownFlow,
    DateTime? lastUpdated,
  }) async {
    try {
      print('FAVORITES_SERVICE: Updating favorite: $reachId');
      final favorites = await loadFavorites();

      final index = favorites.indexWhere((f) => f.reachId == reachId);
      if (index == -1) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId not found for update');
        return false;
      }

      favorites[index] = favorites[index].copyWith(
        customName: customName,
        riverName: riverName, // ← ADDED
        customImageAsset: customImageAsset,
        lastKnownFlow: lastKnownFlow,
        lastUpdated: lastUpdated,
      );

      final success = await saveFavorites(favorites);
      if (success) {
        print('FAVORITES_SERVICE: ✅ Updated favorite: $reachId');
      }
      return success;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error updating favorite: $e');
      return false;
    }
  }

  /// Get count of favorites for UI logic
  Future<int> getFavoritesCount() async {
    try {
      final favorites = await loadFavorites();
      return favorites.length;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error getting favorites count: $e');
      return 0;
    }
  }

  /// Clear all favorites (for testing or user request)
  Future<bool> clearAllFavorites() async {
    try {
      print('FAVORITES_SERVICE: Clearing all favorites');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      print('FAVORITES_SERVICE: ✅ All favorites cleared');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error clearing favorites: $e');
      return false;
    }
  }
}
