// lib/features/map/services/map_reach_selection_service.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/selected_reach.dart';
import '../models/visible_stream.dart';

/// Service for handling river reach selection from vector tiles
class MapReachSelectionService {
  MapboxMap? _mapboxMap;
  String? _currentHighlightLayerId; // Track current highlight layer

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

  /// Get all visible streams in the current map bounds
  Future<List<VisibleStream>> getVisibleStreams() async {
    if (_mapboxMap == null) return [];

    try {
      print('🔍 Querying visible streams...');

      // Get map size to create screen box covering entire visible area
      final size = await _mapboxMap!.getSize();

      // Create a screen box covering the entire visible area
      final screenBox = ScreenBox(
        min: ScreenCoordinate(x: 0, y: 0),
        max: ScreenCoordinate(x: size.width, y: size.height),
      );

      // Query all streams in visible area
      final streams2LayerIds = [
        'streams2-order-1-2', // Small streams
        'streams2-order-3-4', // Medium streams
        'streams2-order-5-plus', // Large rivers
      ];

      final List<QueriedRenderedFeature?> queryResult = await _mapboxMap!
          .queryRenderedFeatures(
            RenderedQueryGeometry.fromScreenBox(screenBox),
            RenderedQueryOptions(layerIds: streams2LayerIds),
          );

      print('📊 Found ${queryResult.length} stream features in visible area');

      // Convert features to VisibleStream objects
      final visibleStreams = <VisibleStream>[];
      final seenStationIds = <String>{}; // Avoid duplicates

      for (final queriedFeature in queryResult) {
        if (queriedFeature != null) {
          try {
            print(
              '🔍 Processing feature: ${queriedFeature.queriedFeature.feature['properties']}',
            );
            final visibleStream = _createVisibleStreamFromFeature(
              queriedFeature,
            );
            if (visibleStream != null &&
                !seenStationIds.contains(visibleStream.stationId)) {
              visibleStreams.add(visibleStream);
              seenStationIds.add(visibleStream.stationId);
              print('✅ Added stream: ${visibleStream.stationId}');
            } else if (visibleStream == null) {
              print('❌ Failed to create VisibleStream from feature');
            } else {
              print('⚠️ Duplicate stream ID: ${visibleStream.stationId}');
            }
          } catch (e) {
            print('⚠️ Error processing stream feature: $e');
          }
        } else {
          print('⚠️ Null feature in query result');
        }
      }

      // Sort by stream order (larger streams first) then by station ID
      visibleStreams.sort((a, b) {
        final orderCompare = b.streamOrder.compareTo(a.streamOrder);
        if (orderCompare != 0) return orderCompare;
        return a.stationId.compareTo(b.stationId);
      });

      print('✅ Found ${visibleStreams.length} unique streams');
      return visibleStreams;
    } catch (e) {
      print('❌ Error getting visible streams: $e');
      return [];
    }
  }

  /// Fly to a selected stream and highlight it
  Future<void> flyToStream(VisibleStream stream) async {
    if (_mapboxMap == null) return;

    try {
      print('🛫 Flying to stream ${stream.stationId}...');

      // Clear any existing highlight first
      await clearHighlight();

      // Create camera options for the stream location
      final cameraOptions = CameraOptions(
        center: Point(coordinates: Position(stream.longitude, stream.latitude)),
        zoom: 14.0, // Good zoom level for individual streams
      );

      // Fly to the stream location
      await _mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );

      // Highlight the stream after flying
      await highlightStream(stream);

      print('✅ Flew to and highlighted stream ${stream.stationId}');
    } catch (e) {
      print('❌ Error flying to stream: $e');
    }
  }

  /// Highlight a specific stream on the map
  Future<void> highlightStream(VisibleStream stream) async {
    if (_mapboxMap == null) return;

    try {
      // Clear any existing highlight
      await clearHighlight();

      // Create a temporary source with just this stream's data
      final highlightSourceId = 'stream-highlight-source';
      final highlightLayerId = 'stream-highlight-layer';

      // Create GeoJSON string for the stream point
      final streamPointGeoJson =
          '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [${stream.longitude}, ${stream.latitude}]
      },
      "properties": {
        "station_id": "${stream.stationId}"
      }
    }
  ]
}
''';

      // Add the highlight source
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: highlightSourceId, data: streamPointGeoJson),
      );

      // Add a circle layer to highlight the stream location
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: highlightLayerId,
          sourceId: highlightSourceId,
          circleColor: 0xFFFF0000, // Bright red
          circleRadius: 12.0, // Large enough to be visible
          circleOpacity: 0.7,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circleStrokeWidth: 2.0,
        ),
      );

      _currentHighlightLayerId = highlightLayerId;
      print('✅ Highlighted stream ${stream.stationId}');

      // Auto-clear highlight after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        clearHighlight();
      });
    } catch (e) {
      print('❌ Error highlighting stream: $e');
    }
  }

  /// Clear the current stream highlight
  Future<void> clearHighlight() async {
    if (_mapboxMap == null || _currentHighlightLayerId == null) return;

    try {
      // Remove highlight layer
      await _mapboxMap!.style.removeStyleLayer(_currentHighlightLayerId!);

      // Remove highlight source
      await _mapboxMap!.style.removeStyleSource('stream-highlight-source');

      _currentHighlightLayerId = null;
      print('✅ Cleared stream highlight');
    } catch (e) {
      // Ignore errors when removing non-existent layers/sources
      _currentHighlightLayerId = null;
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

      // ✅ Query the CORRECT streams2 layer names (excluding commented debug layer)
      final streams2LayerIds = [
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

  /// Create VisibleStream from vector tile feature
  VisibleStream? _createVisibleStreamFromFeature(
    QueriedRenderedFeature queriedRenderedFeature,
  ) {
    try {
      final feature = queriedRenderedFeature.queriedFeature.feature;
      final properties = feature['properties'] != null
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};

      print('🔍 Feature properties keys: ${properties.keys.toList()}');
      print('🔍 station_id: ${properties['station_id']}');
      print('🔍 streamOrde: ${properties['streamOrde']}');

      // Validate required properties
      if (!properties.containsKey('station_id') ||
          !properties.containsKey('streamOrde')) {
        print(
          '❌ Missing required properties - station_id: ${properties.containsKey('station_id')}, streamOrde: ${properties.containsKey('streamOrde')}',
        );
        return null;
      }

      // Get the geometry to extract coordinates
      final geometry = feature['geometry'];
      if (geometry == null) {
        print('❌ No geometry found in feature');
        return null;
      }

      // Cast geometry to Map to safely access its properties
      final geometryMap = geometry as Map<String, dynamic>;

      print('🔍 Geometry type: ${geometryMap['type']}');

      if (geometryMap['type'] != 'LineString') {
        print('❌ Geometry is not LineString: ${geometryMap['type']}');
        return null;
      }

      final coordinates = geometryMap['coordinates'] as List;
      if (coordinates.isEmpty) {
        print('❌ Empty coordinates in LineString');
        return null;
      }

      // Use the middle point of the LineString for the stream location
      final middleIndex = coordinates.length ~/ 2;
      final middleCoord = coordinates[middleIndex] as List;

      print(
        '✅ Created VisibleStream: ${properties['station_id']} at [${middleCoord[0]}, ${middleCoord[1]}]',
      );

      return VisibleStream(
        stationId: properties['station_id'].toString(),
        streamOrder: properties['streamOrde'] as int,
        longitude: middleCoord[0].toDouble(),
        latitude: middleCoord[1].toDouble(),
      );
    } catch (e) {
      print('❌ Error creating VisibleStream: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    clearHighlight(); // Clean up any highlights
    _mapboxMap = null;
    onReachSelected = null;
    onEmptyTap = null;
    print('🗑️ Reach selection service disposed');
  }
}
