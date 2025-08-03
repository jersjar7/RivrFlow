// lib/features/map/services/map_vector_tiles_service.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/config.dart';

/// Service for managing vector tiles display on the map
/// Handles loading/removing river reaches from vector tiles
class MapVectorTilesService {
  MapboxMap? _mapboxMap;
  bool _isLoaded = false;

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    _mapboxMap = map;
    print('✅ Vector tiles service ready');
  }

  /// Load river reaches vector tiles
  Future<void> loadRiverReaches() async {
    if (_mapboxMap == null) {
      throw Exception('MapboxMap not set');
    }

    if (_isLoaded) {
      print('ℹ️ Vector tiles already loaded');
      return;
    }

    try {
      print('🚀 Loading river reaches vector tiles...');

      // Remove existing source/layers if they exist
      await _removeExistingLayers();

      // Add vector source
      await _addVectorSource();

      // Add styled layer
      await _addStyledLayer();

      _isLoaded = true;
      print('✅ River reaches vector tiles loaded successfully');
    } catch (e) {
      print('❌ Failed to load vector tiles: $e');
      rethrow;
    }
  }

  /// Toggle river reaches visibility on/off
  Future<void> toggleRiverReachesVisibility({bool? visible}) async {
    if (_mapboxMap == null || !_isLoaded) return;

    try {
      // If visible not specified, determine current state and toggle
      if (visible == null) {
        final currentVisibility = await _mapboxMap!.style.getStyleLayerProperty(
          AppConfig.vectorLayerId,
          'visibility',
        );
        visible = currentVisibility != 'visible';
      }

      await _mapboxMap!.style.setStyleLayerProperty(
        AppConfig.vectorLayerId,
        'visibility',
        visible ? 'visible' : 'none',
      );

      print('✅ River reaches ${visible ? 'shown' : 'hidden'}');
    } catch (e) {
      print('❌ Error toggling river reaches visibility: $e');
    }
  }

  /// Remove vector tiles completely from map (for cleanup/switching layers)
  Future<void> removeRiverReaches() async {
    if (_mapboxMap == null || !_isLoaded) return;

    try {
      await _removeExistingLayers();
      _isLoaded = false;
      print('✅ Vector tiles removed completely');
    } catch (e) {
      print('❌ Error removing vector tiles: $e');
    }
  }

  /// Check if vector tiles are loaded
  bool get isLoaded => _isLoaded;

  /// Add the vector source for river reaches
  Future<void> _addVectorSource() async {
    await _mapboxMap!.style.addSource(
      VectorSource(
        id: AppConfig.vectorSourceId,
        url: AppConfig.getVectorTileSourceUrl(),
      ),
    );
    print('✅ Vector source added: ${AppConfig.vectorSourceId}');
  }

  /// Add styled layer for river reaches
  Future<void> _addStyledLayer() async {
    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: AppConfig.vectorLayerId,
        sourceId: AppConfig.vectorSourceId,
        sourceLayer: AppConfig.vectorSourceLayer,
        lineColor: 0xFF0000FF, // Bright blue
        lineWidth: 4.0, // Thicker lines for easier tapping
        lineOpacity: 0.9,
        // Remove zoom filter temporarily to see all streams
      ),
    );
    print('✅ Styled layer added: ${AppConfig.vectorLayerId}');
  }

  /// Remove existing vector source and layers to avoid conflicts
  Future<void> _removeExistingLayers() async {
    try {
      // Try to remove layer first
      if (await _layerExists(AppConfig.vectorLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(AppConfig.vectorLayerId);
      }

      // Then remove source
      if (await _sourceExists(AppConfig.vectorSourceId)) {
        await _mapboxMap!.style.removeStyleSource(AppConfig.vectorSourceId);
      }
    } catch (e) {
      // Ignore errors when removing non-existent layers/sources
      print('ℹ️ Cleaned up existing layers/sources');
    }
  }

  /// Check if a layer exists
  Future<bool> _layerExists(String layerId) async {
    try {
      await _mapboxMap!.style.getStyleLayerProperty(layerId, 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a source exists
  Future<bool> _sourceExists(String sourceId) async {
    try {
      await _mapboxMap!.style.getStyleSourceProperty(sourceId, 'type');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update layer visibility based on zoom level
  /// Called when zoom changes to optimize performance
  Future<void> updateVisibilityForZoom(double zoom) async {
    if (!_isLoaded || _mapboxMap == null) return;

    try {
      // Simple visibility toggle based on zoom thresholds
      final shouldShow =
          zoom >= AppConfig.minZoomForVectorTiles &&
          zoom <= AppConfig.maxZoomForVectorTiles;

      await _mapboxMap!.style.setStyleLayerProperty(
        AppConfig.vectorLayerId,
        'visibility',
        shouldShow ? 'visible' : 'none',
      );
    } catch (e) {
      print('❌ Error updating layer visibility: $e');
    }
  }

  /// Get current zoom level from map
  Future<double?> getCurrentZoom() async {
    if (_mapboxMap == null) return null;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      return cameraState.zoom;
    } catch (e) {
      print('❌ Error getting zoom level: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _mapboxMap = null;
    _isLoaded = false;
  }
}
