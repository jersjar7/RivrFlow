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

      // Add the CORRECT styled layers (multiple layers like working code)
      await _addStyledLayers();

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
      final layerIds = [
        'streams2-debug-correct',
        'streams2-order-1-2',
        'streams2-order-3-4',
        'streams2-order-5-plus',
      ];

      for (final layerId in layerIds) {
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            layerId,
            'visibility',
            visible == true ? 'visible' : 'none',
          );
        } catch (e) {
          // Layer might not exist, that's fine
        }
      }

      print('✅ River reaches ${visible == true ? 'shown' : 'hidden'}');
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

  /// Add styled layers for river reaches (MULTIPLE LAYERS like working code)
  Future<void> _addStyledLayers() async {
    try {
      // Add the main debug layer
      // await _mapboxMap!.style.addLayer(
      //   LineLayer(
      //     id: 'streams2-debug-correct',
      //     sourceId: AppConfig.vectorSourceId,
      //     sourceLayer: AppConfig.vectorSourceLayer, // 'streams2-7jgd8p'
      //     lineColor: 0xFFFF0000, // Bright red for debug
      //     lineWidth: 5.0, // Very thick so it's visible
      //     lineOpacity: 1.0, // Full opacity
      //   ),
      // );
      // print('✅ Added debug layer: streams2-debug-correct');

      // Add stream order layers with proper styling and filters
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-1-2',
          sourceId: AppConfig.vectorSourceId,
          sourceLayer: AppConfig.vectorSourceLayer, // 'streams2-7jgd8p'
          lineColor: 0xFF87CEEB, // Light blue
          lineWidth: 1.0,
          lineOpacity: 0.8,
          filter: [
            "<=",
            ["get", "streamOrde"], // Note: it's "streamOrde" not "streamOrder"
            2,
          ],
        ),
      );
      print('✅ Added layer: streams2-order-1-2');

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-3-4',
          sourceId: AppConfig.vectorSourceId,
          sourceLayer: AppConfig.vectorSourceLayer, // 'streams2-7jgd8p'
          lineColor: 0xFF4682B4, // Steel blue
          lineWidth: 2.0,
          lineOpacity: 0.8,
          filter: [
            "all",
            [
              ">=",
              ["get", "streamOrde"],
              3,
            ],
            [
              "<=",
              ["get", "streamOrde"],
              4,
            ],
          ],
        ),
      );
      print('✅ Added layer: streams2-order-3-4');

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-5-plus',
          sourceId: AppConfig.vectorSourceId,
          sourceLayer: AppConfig.vectorSourceLayer, // 'streams2-7jgd8p'
          lineColor: 0xFF191970, // Midnight blue
          lineWidth: 3.5,
          lineOpacity: 0.9,
          filter: [
            ">=",
            ["get", "streamOrde"],
            5,
          ],
        ),
      );
      print('✅ Added layer: streams2-order-5-plus');
    } catch (e) {
      print('❌ Failed to add styled layers: $e');
      rethrow;
    }
  }

  /// Remove existing vector source and layers to avoid conflicts
  Future<void> _removeExistingLayers() async {
    try {
      // Remove all possible layer IDs
      final layersToRemove = [
        'streams2-debug-correct',
        'streams2-order-1-2',
        'streams2-order-3-4',
        'streams2-order-5-plus',
        AppConfig.vectorLayerId, // Also remove the old generic layer
      ];

      // Try to remove layers first
      for (final layerId in layersToRemove) {
        try {
          await _mapboxMap!.style.removeStyleLayer(layerId);
        } catch (e) {
          // Layer might not exist, that's fine
        }
      }

      // Then remove source
      try {
        await _mapboxMap!.style.removeStyleSource(AppConfig.vectorSourceId);
      } catch (e) {
        // Source might not exist, that's fine
      }

      print('ℹ️ Cleaned up existing layers/sources');
    } catch (e) {
      // Ignore errors when removing non-existent layers/sources
      print('ℹ️ Cleaned up existing layers/sources');
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

      final layerIds = [
        'streams2-debug-correct',
        'streams2-order-1-2',
        'streams2-order-3-4',
        'streams2-order-5-plus',
      ];

      for (final layerId in layerIds) {
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            layerId,
            'visibility',
            shouldShow ? 'visible' : 'none',
          );
        } catch (e) {
          // Layer might not exist, that's fine
        }
      }
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
