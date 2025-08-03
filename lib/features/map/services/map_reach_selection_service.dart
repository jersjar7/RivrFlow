// lib/features/map/services/map_reach_selection_service.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/config.dart';
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
  }

  /// Handle map tap for reach selection
  Future<void> handleMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;

    try {
      final tapPoint = context.point;
      final touchPosition = context.touchPosition;

      // Query vector tiles at tap location
      final selectedReach = await _queryReachAtPoint(tapPoint, touchPosition);

      if (selectedReach != null) {
        onReachSelected?.call(selectedReach);
      } else {
        onEmptyTap?.call(tapPoint);
      }
    } catch (e) {
      print('❌ Error handling map tap: $e');
      onEmptyTap?.call(context.point);
    }
  }

  /// Query vector tile features at specific point
  Future<SelectedReach?> _queryReachAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (_mapboxMap == null) return null;

    try {
      // Create query area around tap point
      final queryBox = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(
            x: touchPosition.x - AppConfig.tapAreaRadius,
            y: touchPosition.y - AppConfig.tapAreaRadius,
          ),
          max: ScreenCoordinate(
            x: touchPosition.x + AppConfig.tapAreaRadius,
            y: touchPosition.y + AppConfig.tapAreaRadius,
          ),
        ),
      );

      // Query the vector layer
      final queryResult = await _mapboxMap!.queryRenderedFeatures(
        queryBox,
        RenderedQueryOptions(layerIds: [AppConfig.vectorLayerId]),
      );

      if (queryResult.isNotEmpty) {
        final feature = queryResult.first;
        if (feature != null) {
          return _createSelectedReachFromFeature(feature, tapPoint);
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
    QueriedRenderedFeature feature,
    Point tapPoint,
  ) {
    try {
      // Access feature properties - adjust based on actual Mapbox API
      final properties =
          feature.queriedFeature.feature['properties'] as Map<String, dynamic>?;

      if (properties == null) return null;

      // Validate required properties exist
      if (!properties.containsKey('station_id') ||
          !properties.containsKey('streamOrde')) {
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
}
