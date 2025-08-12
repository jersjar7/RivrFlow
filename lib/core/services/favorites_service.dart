// lib/core/services/favorites_service.dart

import '../models/favorite_river.dart';
import '../services/auth_service.dart';
import '../../features/auth/services/user_settings_service.dart';

/// Simple service for managing user's favorite rivers
/// Uses Firestore via UserSettings.favoriteReachIds - no local storage
class FavoritesService {
  final UserSettingsService _userSettingsService = UserSettingsService();
  final AuthService _authService = AuthService();

  /// Get current user ID or return null if not signed in
  String? get _currentUserIdOrNull => _authService.currentUser?.uid;

  /// Load all favorites from Firestore
  Future<List<FavoriteRiver>> loadFavorites() async {
    try {
      print('FAVORITES_SERVICE: Loading favorites from Firestore');

      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - returning empty list');
        return [];
      }

      final userSettings = await _userSettingsService.getUserSettings(userId);
      if (userSettings == null) {
        print(
          'FAVORITES_SERVICE: No user settings found - returning empty list',
        );
        return [];
      }

      // Convert simple reach IDs to FavoriteRiver objects
      final favorites = <FavoriteRiver>[];
      for (int i = 0; i < userSettings.favoriteReachIds.length; i++) {
        final reachId = userSettings.favoriteReachIds[i];
        favorites.add(
          FavoriteRiver(
            reachId: reachId,
            displayOrder: i, // Use array index as display order
          ),
        );
      }

      print(
        'FAVORITES_SERVICE: ✅ Loaded ${favorites.length} favorites from cloud',
      );
      return favorites;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error loading favorites: $e');
      return [];
    }
  }

  /// Save all favorites to Firestore
  Future<bool> saveFavorites(List<FavoriteRiver> favorites) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - cannot save');
        return false;
      }

      print('FAVORITES_SERVICE: Saving ${favorites.length} favorites to cloud');

      // Sort by display order first
      final sortedFavorites = List<FavoriteRiver>.from(favorites);
      sortedFavorites.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Extract just the reach IDs in order
      final reachIds = sortedFavorites.map((f) => f.reachId).toList();

      // Update user settings
      await _userSettingsService.updateUserSettings(userId, {
        'favoriteReachIds': reachIds,
      });

      print('FAVORITES_SERVICE: ✅ Favorites saved to cloud successfully');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error saving favorites: $e');
      return false;
    }
  }

  /// Add a new favorite river
  Future<bool> addFavorite(
    String reachId, {
    String? customName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - cannot add favorite');
        return false;
      }

      print('FAVORITES_SERVICE: Adding favorite: $reachId');

      final userSettings = await _userSettingsService.getUserSettings(userId);
      if (userSettings == null) {
        print('FAVORITES_SERVICE: ❌ No user settings found');
        return false;
      }

      // Check if already exists
      if (userSettings.favoriteReachIds.contains(reachId)) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId already in favorites');
        return false;
      }

      // Add to the end of the list
      final updatedReachIds = [...userSettings.favoriteReachIds, reachId];

      // Update user settings
      await _userSettingsService.updateUserSettings(userId, {
        'favoriteReachIds': updatedReachIds,
      });

      print('FAVORITES_SERVICE: ✅ Added favorite: $reachId');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error adding favorite: $e');
      return false;
    }
  }

  /// Remove a favorite river
  Future<bool> removeFavorite(String reachId) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - cannot remove favorite');
        return false;
      }

      print('FAVORITES_SERVICE: Removing favorite: $reachId');

      final userSettings = await _userSettingsService.getUserSettings(userId);
      if (userSettings == null) {
        print('FAVORITES_SERVICE: ❌ No user settings found');
        return false;
      }

      // Check if exists
      if (!userSettings.favoriteReachIds.contains(reachId)) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId not found in favorites');
        return false;
      }

      // Remove from list
      final updatedReachIds = userSettings.favoriteReachIds
          .where((id) => id != reachId)
          .toList();

      // Update user settings
      await _userSettingsService.updateUserSettings(userId, {
        'favoriteReachIds': updatedReachIds,
      });

      print('FAVORITES_SERVICE: ✅ Removed favorite: $reachId');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error removing favorite: $e');
      return false;
    }
  }

  /// Check if a reach is favorited
  Future<bool> isFavorite(String reachId) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) return false;

      final userSettings = await _userSettingsService.getUserSettings(userId);
      if (userSettings == null) return false;

      return userSettings.favoriteReachIds.contains(reachId);
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error checking favorite status: $e');
      return false;
    }
  }

  /// Reorder favorites (for drag-and-drop)
  Future<bool> reorderFavorites(List<FavoriteRiver> reorderedFavorites) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - cannot reorder');
        return false;
      }

      print(
        'FAVORITES_SERVICE: Reordering ${reorderedFavorites.length} favorites',
      );

      // Extract reach IDs in the new order
      final reorderedReachIds = reorderedFavorites
          .map((f) => f.reachId)
          .toList();

      // Update user settings with new order
      await _userSettingsService.updateUserSettings(userId, {
        'favoriteReachIds': reorderedReachIds,
      });

      print('FAVORITES_SERVICE: ✅ Favorites reordered successfully');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error reordering favorites: $e');
      return false;
    }
  }

  /// Update a favorite's properties
  Future<bool> updateFavorite(
    String reachId, {
    String? customName,
    String? riverName,
    String? customImageAsset,
    double? lastKnownFlow,
    DateTime? lastUpdated,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) return false;

      print('FAVORITES_SERVICE: Update favorite called for: $reachId');

      // Check if favorite exists
      final isFav = await isFavorite(reachId);
      if (!isFav) {
        print('FAVORITES_SERVICE: ⚠️ Reach $reachId not found for update');
        return false;
      }

      print(
        'FAVORITES_SERVICE: ⚠️ Note: Extra properties not persisted in simplified cloud storage',
      );
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error updating favorite: $e');
      return false;
    }
  }

  /// Get count of favorites
  Future<int> getFavoritesCount() async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) return 0;

      final userSettings = await _userSettingsService.getUserSettings(userId);
      if (userSettings == null) return 0;

      return userSettings.favoriteReachIds.length;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error getting favorites count: $e');
      return 0;
    }
  }

  /// Clear all favorites
  Future<bool> clearAllFavorites() async {
    try {
      final userId = _currentUserIdOrNull;
      if (userId == null) {
        print('FAVORITES_SERVICE: No user signed in - cannot clear');
        return false;
      }

      print('FAVORITES_SERVICE: Clearing all favorites');

      // Update user settings with empty list
      await _userSettingsService.updateUserSettings(userId, {
        'favoriteReachIds': <String>[],
      });

      print('FAVORITES_SERVICE: ✅ All favorites cleared');
      return true;
    } catch (e) {
      print('FAVORITES_SERVICE: ❌ Error clearing favorites: $e');
      return false;
    }
  }
}
