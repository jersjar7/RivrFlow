// lib/core/providers/favorites_provider.dart

import 'package:flutter/foundation.dart';
import '../models/favorite_river.dart';
import '../services/favorites_service.dart';
import '../services/forecast_service.dart';

/// State management for user's favorite rivers
/// Coordinates with ForecastService for flow data and handles background refresh
class FavoritesProvider with ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();
  final ForecastService _forecastService = ForecastService();

  // Current state
  List<FavoriteRiver> _favorites = [];
  Set<String> _favoriteReachIds = {}; // O(1) lookup for isFavorite()
  bool _isLoading = false;
  String? _errorMessage;

  // Track loading state per favorite for individual refresh indicators
  final Set<String> _refreshingReachIds = {};

  // Getters
  List<FavoriteRiver> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get favoritesCount => _favorites.length;
  bool get isEmpty => _favorites.isEmpty;
  bool get shouldShowSearch => _favorites.length >= 4;

  /// Check if a specific favorite is being refreshed
  bool isRefreshing(String reachId) => _refreshingReachIds.contains(reachId);

  /// Check if a reach is favorited - O(1) lookup
  bool isFavorite(String reachId) {
    return _favoriteReachIds.contains(reachId);
  }

  /// Get favorites that have coordinates for map markers
  List<FavoriteRiver> getFavoritesWithCoordinates() {
    return _favorites.where((f) => f.hasCoordinates).toList();
  }

  /// Compare favorites lists and return what changed for efficient marker updates
  Map<String, dynamic> diffFavorites(List<FavoriteRiver> oldFavorites) {
    final oldReachIds = oldFavorites.map((f) => f.reachId).toSet();
    final newReachIds = _favorites.map((f) => f.reachId).toSet();

    return {
      'added': newReachIds.difference(oldReachIds).toList(),
      'removed': oldReachIds.difference(newReachIds).toList(),
    };
  }

  /// Initialize favorites and start background refresh
  Future<void> initializeAndRefresh() async {
    print('FAVORITES_PROVIDER: Initializing favorites');

    _setLoading(true);
    _clearError();

    try {
      // Load favorites from storage first
      await _loadFavoritesFromStorage();

      // Start background refresh after short delay (let UI show cached data)
      Future.delayed(const Duration(milliseconds: 500), () {
        _refreshAllFavoritesInBackground();
      });
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error during initialization: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load favorites from storage and update lookup set
  Future<void> _loadFavoritesFromStorage() async {
    try {
      _favorites = await _favoritesService.loadFavorites();
      _updateFavoriteReachIds(); // Update lookup set
      print(
        'FAVORITES_PROVIDER: ✅ Loaded ${_favorites.length} favorites from storage',
      );
      notifyListeners();
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error loading favorites: $e');
      rethrow;
    }
  }

  /// Update the lookup set when favorites list changes
  void _updateFavoriteReachIds() {
    _favoriteReachIds = _favorites.map((f) => f.reachId).toSet();
  }

  /// Add a new favorite river with coordinates from API
  Future<bool> addFavorite(String reachId, {String? customName}) async {
    print('FAVORITES_PROVIDER: Adding favorite: $reachId');

    try {
      // Check if already exists using O(1) lookup
      if (isFavorite(reachId)) {
        print('FAVORITES_PROVIDER: ⚠️ Reach $reachId already favorited');
        return false;
      }

      // Fetch coordinates from API
      double? latitude, longitude;
      try {
        final forecast = await _forecastService.loadCompleteReachData(reachId);
        latitude = forecast.reach.latitude;
        longitude = forecast.reach.longitude;
        print(
          'FAVORITES_PROVIDER: ✅ Got coordinates for $reachId: $latitude, $longitude',
        );
      } catch (e) {
        print(
          'FAVORITES_PROVIDER: ⚠️ Could not get coordinates for $reachId: $e',
        );
        // Continue without coordinates - can be added later
      }

      // Add to storage with coordinates
      final success = await _favoritesService.addFavorite(
        reachId,
        customName: customName,
        latitude: latitude,
        longitude: longitude,
      );
      if (!success) return false;

      // Reload from storage to get updated list
      await _loadFavoritesFromStorage();

      // Start background data loading for the new favorite
      _loadFavoriteDataInBackground(reachId);

      print('FAVORITES_PROVIDER: ✅ Added favorite: $reachId');
      return true;
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error adding favorite: $e');
      _setError(e.toString());
      return false;
    }
  }

  /// Remove a favorite river
  Future<bool> removeFavorite(String reachId) async {
    print('FAVORITES_PROVIDER: Removing favorite: $reachId');

    try {
      final success = await _favoritesService.removeFavorite(reachId);
      if (!success) return false;

      // Reload from storage
      await _loadFavoritesFromStorage();

      // Clear any loading state
      _refreshingReachIds.remove(reachId);

      print('FAVORITES_PROVIDER: ✅ Removed favorite: $reachId');
      return true;
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error removing favorite: $e');
      _setError(e.toString());
      return false;
    }
  }

  /// Reorder favorites (for drag-and-drop)
  Future<bool> reorderFavorites(int oldIndex, int newIndex) async {
    print(
      'FAVORITES_PROVIDER: Reordering favorite from $oldIndex to $newIndex',
    );

    try {
      // Update local list immediately for UI responsiveness
      final reorderedFavorites = List<FavoriteRiver>.from(_favorites);
      final item = reorderedFavorites.removeAt(oldIndex);
      reorderedFavorites.insert(newIndex, item);

      _favorites = reorderedFavorites;
      _updateFavoriteReachIds(); // Update lookup set
      notifyListeners();

      // Persist the reordering
      final success = await _favoritesService.reorderFavorites(_favorites);
      if (!success) {
        // Revert on failure
        await _loadFavoritesFromStorage();
        return false;
      }

      print('FAVORITES_PROVIDER: ✅ Reordered favorites successfully');
      return true;
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error reordering favorites: $e');
      _setError(e.toString());
      await _loadFavoritesFromStorage(); // Revert
      return false;
    }
  }

  /// Update favorite properties (name, image)
  Future<bool> updateFavorite(
    String reachId, {
    String? customName,
    String? riverName,
    String? customImageAsset,
  }) async {
    print('FAVORITES_PROVIDER: Updating favorite: $reachId');

    try {
      final success = await _favoritesService.updateFavorite(
        reachId,
        customName: customName,
        riverName: riverName,
        customImageAsset: customImageAsset,
      );

      if (success) {
        await _loadFavoritesFromStorage();
        print('FAVORITES_PROVIDER: ✅ Updated favorite: $reachId');
      }

      return success;
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Error updating favorite: $e');
      _setError(e.toString());
      return false;
    }
  }

  /// Refresh all favorites flow data (pull-to-refresh)
  Future<void> refreshAllFavorites() async {
    print('FAVORITES_PROVIDER: Manual refresh of all favorites');

    _clearError();

    // Refresh each favorite
    final refreshTasks = _favorites
        .map((favorite) => _refreshSingleFavorite(favorite.reachId))
        .toList();

    await Future.wait(refreshTasks);
    print('FAVORITES_PROVIDER: ✅ Manual refresh completed');
  }

  /// Background refresh of all favorites (app launch)
  Future<void> _refreshAllFavoritesInBackground() async {
    print(
      'FAVORITES_PROVIDER: Starting background refresh of ${_favorites.length} favorites',
    );

    // Refresh favorites one by one to show progressive updates
    for (final favorite in _favorites) {
      await _refreshSingleFavorite(favorite.reachId);
      // Small delay between requests to be API-friendly
      await Future.delayed(const Duration(milliseconds: 200));
    }

    print('FAVORITES_PROVIDER: ✅ Background refresh completed');
  }

  /// Load favorite data in background (when new favorite added)
  Future<void> _loadFavoriteDataInBackground(String reachId) async {
    await _refreshSingleFavorite(reachId);
  }

  /// Refresh a single favorite's flow data
  Future<void> _refreshSingleFavorite(String reachId) async {
    try {
      _refreshingReachIds.add(reachId);
      notifyListeners();

      // Use existing ForecastService to get fresh data
      final forecast = await _forecastService.loadCompleteReachData(reachId);
      final currentFlow = _forecastService.getCurrentFlow(forecast);
      final riverName = forecast.reach.riverName;

      // Also get coordinates if not cached yet
      final currentFavorite = _favorites.firstWhere(
        (f) => f.reachId == reachId,
      );
      double? latitude = currentFavorite.latitude;
      double? longitude = currentFavorite.longitude;

      if (!currentFavorite.hasCoordinates) {
        latitude = forecast.reach.latitude;
        longitude = forecast.reach.longitude;
        print('FAVORITES_PROVIDER: ✅ Got missing coordinates for $reachId');
      }

      // Update the favorite with fresh flow data, river name, and coordinates
      await _favoritesService.updateFavorite(
        reachId,
        riverName: riverName,
        lastKnownFlow: currentFlow,
        lastUpdated: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      // Update local list
      final index = _favorites.indexWhere((f) => f.reachId == reachId);
      if (index != -1) {
        _favorites[index] = _favorites[index].copyWith(
          riverName: riverName,
          lastKnownFlow: currentFlow,
          lastUpdated: DateTime.now(),
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (e) {
      print('FAVORITES_PROVIDER: ❌ Failed to refresh $reachId: $e');
      // Individual failures don't break the whole list
    } finally {
      _refreshingReachIds.remove(reachId);
      notifyListeners();
    }
  }

  /// Filter favorites by search query
  List<FavoriteRiver> filterFavorites(String query) {
    if (query.isEmpty) return _favorites;

    final lowerQuery = query.toLowerCase();
    return _favorites.where((favorite) {
      return favorite.displayName.toLowerCase().contains(lowerQuery) ||
          favorite.reachId.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear all favorites (for testing)
  Future<void> clearAllFavorites() async {
    await _favoritesService.clearAllFavorites();
    _favorites.clear();
    _favoriteReachIds.clear(); // Clear lookup set
    _refreshingReachIds.clear();
    _clearError();
    notifyListeners();
    print('FAVORITES_PROVIDER: ✅ Cleared all favorites');
  }
}
