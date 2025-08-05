// lib/features/map/services/map_marker_service.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/models/favorite_river.dart';

/// Dedicated service for managing map markers efficiently
/// Uses single annotation manager pattern with diff-based updates
class MapMarkerService {
  // Single annotation manager for all heart markers
  PointAnnotationManager? _annotationManager;
  MapboxMap? _mapboxMap;

  // Track current markers for efficient diff updates
  final Map<String, PointAnnotation> _heartMarkers = {};

  // Track which reach IDs currently have markers
  final Set<String> _currentMarkerReachIds = {};

  bool _isInitialized = false;

  /// Initialize the marker service with the map
  Future<void> initializeMarkers(MapboxMap mapboxMap) async {
    try {
      print('MAP_MARKER_SERVICE: Initializing marker service');

      _mapboxMap = mapboxMap;

      // Create single annotation manager for all heart markers
      _annotationManager = await _mapboxMap!.annotations
          .createPointAnnotationManager();

      _isInitialized = true;
      print('MAP_MARKER_SERVICE: ✅ Marker service initialized');
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error initializing markers: $e');
      _isInitialized = false;
    }
  }

  /// Update heart markers based on favorites list with diff-based approach
  Future<void> updateHeartMarkers(List<FavoriteRiver> favorites) async {
    if (!_isInitialized || _annotationManager == null) {
      print(
        'MAP_MARKER_SERVICE: ⚠️ Service not initialized, skipping marker update',
      );
      return;
    }

    try {
      print(
        'MAP_MARKER_SERVICE: Updating heart markers for ${favorites.length} favorites',
      );

      // Get favorites that have coordinates and can be displayed
      final favoritesWithCoords = favorites
          .where((f) => f.hasCoordinates)
          .toList();
      final newReachIds = favoritesWithCoords.map((f) => f.reachId).toSet();

      // Diff calculation: find what to add and remove
      final toRemove = _currentMarkerReachIds.difference(newReachIds);
      final toAdd = newReachIds.difference(_currentMarkerReachIds);

      print(
        'MAP_MARKER_SERVICE: Markers to add: ${toAdd.length}, to remove: ${toRemove.length}',
      );

      // Remove markers that are no longer favorites
      for (final reachId in toRemove) {
        await _removeMarker(reachId);
      }

      // Add markers for new favorites
      for (final reachId in toAdd) {
        final favorite = favoritesWithCoords.firstWhere(
          (f) => f.reachId == reachId,
        );
        await _addMarker(favorite);
      }

      print(
        'MAP_MARKER_SERVICE: ✅ Heart markers updated: ${_heartMarkers.length} total',
      );
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error updating heart markers: $e');
    }
  }

  /// Add a single heart marker for a favorite
  Future<void> addMarker(FavoriteRiver favorite) async {
    if (!_isInitialized || _annotationManager == null) {
      print(
        'MAP_MARKER_SERVICE: ⚠️ Service not initialized, cannot add marker',
      );
      return;
    }

    if (!favorite.hasCoordinates) {
      print(
        'MAP_MARKER_SERVICE: ⚠️ Cannot add marker for ${favorite.reachId} - no coordinates',
      );
      return;
    }

    await _addMarker(favorite);
  }

  /// Remove a single heart marker
  Future<void> removeMarker(String reachId) async {
    if (!_isInitialized || _annotationManager == null) {
      print(
        'MAP_MARKER_SERVICE: ⚠️ Service not initialized, cannot remove marker',
      );
      return;
    }

    await _removeMarker(reachId);
  }

  /// Internal method to add a marker
  Future<void> _addMarker(FavoriteRiver favorite) async {
    try {
      // Skip if marker already exists
      if (_heartMarkers.containsKey(favorite.reachId)) {
        return;
      }

      // Create heart marker annotation
      final heartAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(favorite.longitude!, favorite.latitude!),
        ),
        textField: '❤️',
        textSize: 20.0,
        textColor: Colors.red.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 2.0,
        textOffset: [0.0, -0.5], // Slight offset to center better
      );

      // Add to map using the annotation manager
      final annotation = await _annotationManager!.create(
        heartAnnotationOptions,
      );

      // Track the marker
      _heartMarkers[favorite.reachId] = annotation;
      _currentMarkerReachIds.add(favorite.reachId);

      print('MAP_MARKER_SERVICE: ✅ Added heart marker for ${favorite.reachId}');
    } catch (e) {
      print(
        'MAP_MARKER_SERVICE: ❌ Error adding marker for ${favorite.reachId}: $e',
      );
    }
  }

  /// Internal method to remove a marker
  Future<void> _removeMarker(String reachId) async {
    try {
      final annotation = _heartMarkers[reachId];
      if (annotation == null) {
        return; // Marker doesn't exist
      }

      // Remove from map
      await _annotationManager!.delete(annotation);

      // Remove from tracking
      _heartMarkers.remove(reachId);
      _currentMarkerReachIds.remove(reachId);

      print('MAP_MARKER_SERVICE: ✅ Removed heart marker for $reachId');
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error removing marker for $reachId: $e');
    }
  }

  /// Get markers currently in viewport (for lazy loading optimization)
  /// This can be used when there are many favorites to only show markers in view
  Future<List<String>> getMarkersInViewport() async {
    if (!_isInitialized || _mapboxMap == null) {
      return [];
    }

    try {
      // Filter markers that are in viewport
      final markersInView = <String>[];
      for (final entry in _heartMarkers.entries) {
        final reachId = entry.key;
        // Find the favorite to get coordinates
        // This is a simplified approach - in practice you might want to cache coordinates
        // For now, assume all current markers are in reasonable view distance
        markersInView.add(reachId);
      }

      return markersInView;
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error getting viewport markers: $e');
      return [];
    }
  }

  /// Update markers based on viewport (lazy loading)
  /// Only show markers that are in or near the current viewport
  Future<void> updateMarkersForViewport(
    List<FavoriteRiver> allFavorites,
  ) async {
    if (!_isInitialized) return;

    try {
      // Get map bounds with some padding for smoother experience
      final bounds = await _mapboxMap!.getBounds();
      final southwest = bounds.bounds.southwest;
      final northeast = bounds.bounds.northeast;

      // Add some padding to show markers just outside viewport
      const padding = 0.1; // degrees
      final minLat = southwest.coordinates.lat - padding;
      final maxLat = northeast.coordinates.lat + padding;
      final minLng = southwest.coordinates.lng - padding;
      final maxLng = northeast.coordinates.lng + padding;

      // Filter favorites that should be visible
      final visibleFavorites = allFavorites.where((favorite) {
        if (!favorite.hasCoordinates) return false;

        final lat = favorite.latitude!;
        final lng = favorite.longitude!;

        return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
      }).toList();

      // Update markers to only show visible ones
      await updateHeartMarkers(visibleFavorites);

      print(
        'MAP_MARKER_SERVICE: Updated markers for viewport: ${visibleFavorites.length} visible',
      );
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error updating viewport markers: $e');
    }
  }

  /// Clear all markers
  Future<void> clearAllMarkers() async {
    if (!_isInitialized || _annotationManager == null) return;

    try {
      // Remove all markers
      for (final reachId in _currentMarkerReachIds.toList()) {
        await _removeMarker(reachId);
      }

      print('MAP_MARKER_SERVICE: ✅ Cleared all markers');
    } catch (e) {
      print('MAP_MARKER_SERVICE: ❌ Error clearing markers: $e');
    }
  }

  /// Get current marker count
  int get markerCount => _heartMarkers.length;

  /// Check if service is ready
  bool get isInitialized => _isInitialized && _annotationManager != null;

  /// Dispose of the service and clean up resources
  void dispose() {
    print('MAP_MARKER_SERVICE: Disposing marker service');

    _heartMarkers.clear();
    _currentMarkerReachIds.clear();
    _annotationManager = null;
    _mapboxMap = null;
    _isInitialized = false;

    print('MAP_MARKER_SERVICE: ✅ Marker service disposed');
  }
}
