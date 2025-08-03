// lib/features/map/services/map_reach_selection_service.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/selected_reach.dart';

/// Service for handling river reach selection from vector tiles
class MapReachSelectionService {
  MapboxMap? _mapboxMap;

  // Callbacks for selection events
  Function(SelectedReach)? onReachSelected;
  Function(Point)? onEmptyTap;

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    _mapboxMap = map;
    print('✅ Reach selection service ready for streams2');
  }

  /// Handle map tap for reach selection
  Future<void> handleMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;

    try {
      final tapPoint = context.point;
      final touchPosition = context.touchPosition;

      print(
        '🎯 Map tapped at: ${tapPoint.coordinates.lng}, ${tapPoint.coordinates.lat}',
      );

      // Query vector tiles at tap location
      final selectedReach = await _queryReachAtPoint(tapPoint, touchPosition);

      if (selectedReach != null) {
        print('✅ Reach selected: ${selectedReach.reachId}');
        onReachSelected?.call(selectedReach);
      } else {
        print('ℹ️ No reaches found at tap location');
        onEmptyTap?.call(tapPoint);
      }
    } catch (e) {
      print('❌ Error handling map tap: $e');
      onEmptyTap?.call(context.point);
    }
  }

  /// Query vector tile features at specific point (optimized for streams2)
  Future<SelectedReach?> _queryReachAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (_mapboxMap == null) return null;

    try {
      // Create a query area around the tap point (larger for line features)
      final queryBox = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(
            x: touchPosition.x - 12, // Larger area for line features
            y: touchPosition.y - 12,
          ),
          max: ScreenCoordinate(
            x: touchPosition.x + 12,
            y: touchPosition.y + 12,
          ),
        ),
      );

      // ✅ Query the CORRECT streams2 layer names (exactly from working code)
      final streams2LayerIds = [
        'streams2-debug-correct', // Our main debug layer
        'streams2-order-1-2', // Small streams
        'streams2-order-3-4', // Medium streams
        'streams2-order-5-plus', // Large rivers
      ];

      final List<QueriedRenderedFeature?> queryResult = await _mapboxMap!
          .queryRenderedFeatures(
            queryBox,
            RenderedQueryOptions(layerIds: streams2LayerIds),
          );

      print('📊 Found ${queryResult.length} streams2 features in query');

      // Process each found feature
      for (final queriedRenderedFeature in queryResult) {
        if (queriedRenderedFeature != null) {
          try {
            final selectedReach = _createSelectedReachFromFeature(
              queriedRenderedFeature,
              tapPoint,
            );
            if (selectedReach != null) {
              return selectedReach; // Return the first valid reach found
            }
          } catch (e) {
            print('⚠️ Error processing streams2 feature: $e');
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error querying features: $e');
      return null;
    }
  }

  /// Create SelectedReach from vector tile feature
  SelectedReach? _createSelectedReachFromFeature(
    QueriedRenderedFeature queriedRenderedFeature,
    Point tapPoint,
  ) {
    try {
      final feature = queriedRenderedFeature.queriedFeature.feature;

      // ✅ Use correct field names from Mapbox Studio (exactly like working code)
      final properties = feature['properties'] != null
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};

      print('🔍 Feature properties: ${properties.keys.toList()}');
      print('🔍 station_id: ${properties['station_id']}');
      print('🔍 streamOrde: ${properties['streamOrde']}');

      // Validate required properties exist (using exact field names from working code)
      if (!properties.containsKey('station_id') ||
          !properties.containsKey('streamOrde')) {
        print('❌ Missing required properties (station_id or streamOrde)');
        return null;
      }

      // Create SelectedReach from vector tile properties
      return SelectedReach.fromVectorTile(
        properties: properties,
        latitude: tapPoint.coordinates.lat.toDouble(),
        longitude: tapPoint.coordinates.lng.toDouble(),
      );
    } catch (e) {
      print('❌ Error creating SelectedReach: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _mapboxMap = null;
    onReachSelected = null;
    onEmptyTap = null;
    print('🗑️ Reach selection service disposed');
  }
}
