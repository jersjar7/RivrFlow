// lib/features/map/services/map_reach_selection_service.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/selected_reach.dart';
import '../models/visible_stream.dart';

/// Service for handling river reach selection from vector tiles
/// Optimized for research teams to find streams by station ID
class MapReachSelectionService {
  MapboxMap? _mapboxMap;
  String? _currentHighlightLayerId;

  // Callbacks for selection events
  Function(SelectedReach)? onReachSelected;
  Function(Point)? onEmptyTap;

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    _mapboxMap = map;
    print('✅ Research reach selection service ready');
  }

  /// Handle map tap for reach selection (keep existing functionality)
  Future<void> handleMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;

    try {
      final tapPoint = context.point;
      final touchPosition = context.touchPosition;

      print(
        '🎯 Map tapped at: ${tapPoint.coordinates.lng}, ${tapPoint.coordinates.lat}',
      );

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

  /// Get all visible streams in current map view for research purposes
  Future<List<VisibleStream>> getVisibleStreams() async {
    if (_mapboxMap == null) return [];

    print('🔬 Research tool: Querying visible streams...');

    // Wait for map to be fully ready
    await Future.delayed(const Duration(milliseconds: 1000));

    final streams2LayerIds = [
      'streams2-order-1-2', // Small streams
      'streams2-order-3-4', // Medium streams
      'streams2-order-5-plus', // Large rivers
    ];

    // Try multiple strategies to get streams
    List<VisibleStream> streams = [];

    // Strategy 1: Try chunked querying
    streams = await _tryChunkedQuery(streams2LayerIds);
    if (streams.isNotEmpty) {
      print('🎯 Chunked query successful: ${streams.length} streams found');
      return _sortStreams(streams);
    }

    // Strategy 2: Try smaller area query
    streams = await _trySmallerAreaQuery(streams2LayerIds);
    if (streams.isNotEmpty) {
      print(
        '🎯 Smaller area query successful: ${streams.length} streams found',
      );
      return _sortStreams(streams);
    }

    // Strategy 3: Try center point query
    streams = await _tryCenterPointQuery(streams2LayerIds);
    if (streams.isNotEmpty) {
      print(
        '🎯 Center point query successful: ${streams.length} streams found',
      );
      return _sortStreams(streams);
    }

    print('❌ All query strategies failed - no streams found');
    return [];
  }

  /// Strategy 1: Query in chunks
  Future<List<VisibleStream>> _tryChunkedQuery(List<String> layerIds) async {
    try {
      print('🔍 Trying chunked query strategy...');

      final allStreams = <VisibleStream>[];
      final seenStationIds = <String>{};

      // Create smaller chunks to avoid API limits
      final chunks = [
        ScreenBox(
          min: ScreenCoordinate(x: 0, y: 0),
          max: ScreenCoordinate(x: 150, y: 300),
        ),
        ScreenBox(
          min: ScreenCoordinate(x: 150, y: 0),
          max: ScreenCoordinate(x: 300, y: 300),
        ),
        ScreenBox(
          min: ScreenCoordinate(x: 0, y: 300),
          max: ScreenCoordinate(x: 150, y: 600),
        ),
        ScreenBox(
          min: ScreenCoordinate(x: 150, y: 300),
          max: ScreenCoordinate(x: 300, y: 600),
        ),
      ];

      for (int i = 0; i < chunks.length; i++) {
        try {
          final queryResult = await _mapboxMap!.queryRenderedFeatures(
            RenderedQueryGeometry.fromScreenBox(chunks[i]),
            RenderedQueryOptions(layerIds: layerIds),
          );

          print('✅ Chunk ${i + 1}: ${queryResult.length} features');

          for (final feature in queryResult) {
            if (feature != null) {
              final stream = _createVisibleStreamFromFeature(feature);
              if (stream != null &&
                  !seenStationIds.contains(stream.stationId)) {
                allStreams.add(stream);
                seenStationIds.add(stream.stationId);
              }
            }
          }
        } catch (e) {
          print('⚠️ Chunk ${i + 1} failed: $e');
          continue;
        }
      }

      return allStreams;
    } catch (e) {
      print('❌ Chunked query failed: $e');
      return [];
    }
  }

  /// Strategy 2: Query smaller central area
  Future<List<VisibleStream>> _trySmallerAreaQuery(
    List<String> layerIds,
  ) async {
    try {
      print('🔍 Trying smaller area query strategy...');

      // Query just the center 50% of screen
      final smallBox = ScreenBox(
        min: ScreenCoordinate(x: 50, y: 100),
        max: ScreenCoordinate(x: 250, y: 400),
      );

      final queryResult = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(smallBox),
        RenderedQueryOptions(layerIds: layerIds),
      );

      print('✅ Small area query: ${queryResult.length} features');

      final streams = <VisibleStream>[];
      final seenStationIds = <String>{};

      for (final feature in queryResult) {
        if (feature != null) {
          final stream = _createVisibleStreamFromFeature(feature);
          if (stream != null && !seenStationIds.contains(stream.stationId)) {
            streams.add(stream);
            seenStationIds.add(stream.stationId);
          }
        }
      }

      return streams;
    } catch (e) {
      print('❌ Smaller area query failed: $e');
      return [];
    }
  }

  /// Strategy 3: Query around center point
  Future<List<VisibleStream>> _tryCenterPointQuery(
    List<String> layerIds,
  ) async {
    try {
      print('🔍 Trying center point query strategy...');

      // Query small area around screen center
      final centerBox = ScreenBox(
        min: ScreenCoordinate(x: 140, y: 290),
        max: ScreenCoordinate(x: 160, y: 310),
      );

      final queryResult = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(centerBox),
        RenderedQueryOptions(layerIds: layerIds),
      );

      print('✅ Center point query: ${queryResult.length} features');

      final streams = <VisibleStream>[];
      final seenStationIds = <String>{};

      for (final feature in queryResult) {
        if (feature != null) {
          final stream = _createVisibleStreamFromFeature(feature);
          if (stream != null && !seenStationIds.contains(stream.stationId)) {
            streams.add(stream);
            seenStationIds.add(stream.stationId);
          }
        }
      }

      return streams;
    } catch (e) {
      print('❌ Center point query failed: $e');
      return [];
    }
  }

  /// Create VisibleStream from feature
  VisibleStream? _createVisibleStreamFromFeature(
    QueriedRenderedFeature feature,
  ) {
    try {
      final featureData = feature.queriedFeature.feature;

      // Safe type conversion for properties
      final rawProperties = featureData['properties'];
      if (rawProperties == null) return null;

      final properties = Map<String, dynamic>.from(rawProperties as Map);

      if (!properties.containsKey('station_id') ||
          !properties.containsKey('streamOrde')) {
        return null;
      }

      // Safe type conversion for geometry
      final rawGeometry = featureData['geometry'];
      if (rawGeometry == null) return null;

      final geometry = Map<String, dynamic>.from(rawGeometry as Map);
      if (geometry['type'] != 'LineString') {
        return null;
      }

      final coordinates = geometry['coordinates'] as List;
      if (coordinates.isEmpty) return null;

      // Use middle point of LineString
      final middleIndex = coordinates.length ~/ 2;
      final middleCoord = coordinates[middleIndex] as List;

      print(
        '✅ Created stream: ${properties['station_id']} (Order ${properties['streamOrde']})',
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

  /// Sort streams by stream order (larger first) then by station ID
  List<VisibleStream> _sortStreams(List<VisibleStream> streams) {
    streams.sort((a, b) {
      final orderCompare = b.streamOrder.compareTo(a.streamOrder);
      if (orderCompare != 0) return orderCompare;
      return a.stationId.compareTo(b.stationId);
    });
    return streams;
  }

  /// Fly to a selected stream and highlight it
  Future<void> flyToStream(VisibleStream stream) async {
    if (_mapboxMap == null) return;

    try {
      print('🛫 Flying to stream ${stream.stationId}...');

      await clearHighlight();

      // Fly to stream location
      final cameraOptions = CameraOptions(
        center: Point(coordinates: Position(stream.longitude, stream.latitude)),
        zoom: 14.0,
      );

      await _mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );

      // Highlight the stream
      await highlightStream(stream);

      print('✅ Flew to and highlighted stream ${stream.stationId}');
    } catch (e) {
      print('❌ Error flying to stream: $e');
    }
  }

  /// Highlight a stream on the map
  Future<void> highlightStream(VisibleStream stream) async {
    if (_mapboxMap == null) return;

    try {
      await clearHighlight();

      final highlightSourceId = 'stream-highlight-source';
      final highlightLayerId = 'stream-highlight-layer';

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

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: highlightSourceId, data: streamPointGeoJson),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: highlightLayerId,
          sourceId: highlightSourceId,
          circleColor: 0xFFFF0000, // Bright red
          circleRadius: 12.0,
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

  /// Clear stream highlight
  Future<void> clearHighlight() async {
    if (_mapboxMap == null || _currentHighlightLayerId == null) return;

    try {
      await _mapboxMap!.style.removeStyleLayer(_currentHighlightLayerId!);
      await _mapboxMap!.style.removeStyleSource('stream-highlight-source');
      _currentHighlightLayerId = null;
      print('✅ Cleared stream highlight');
    } catch (e) {
      _currentHighlightLayerId = null;
    }
  }

  /// Query vector tile features at specific point (working functionality)
  Future<SelectedReach?> _queryReachAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (_mapboxMap == null) return null;

    try {
      final queryBox = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(
            x: touchPosition.x - 12,
            y: touchPosition.y - 12,
          ),
          max: ScreenCoordinate(
            x: touchPosition.x + 12,
            y: touchPosition.y + 12,
          ),
        ),
      );

      final streams2LayerIds = [
        'streams2-order-1-2',
        'streams2-order-3-4',
        'streams2-order-5-plus',
      ];

      final List<QueriedRenderedFeature?> queryResult = await _mapboxMap!
          .queryRenderedFeatures(
            queryBox,
            RenderedQueryOptions(layerIds: streams2LayerIds),
          );

      print('📊 Found ${queryResult.length} streams2 features in tap query');

      for (final queriedRenderedFeature in queryResult) {
        if (queriedRenderedFeature != null) {
          try {
            final selectedReach = _createSelectedReachFromFeature(
              queriedRenderedFeature,
              tapPoint,
            );
            if (selectedReach != null) {
              return selectedReach;
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

      // Safe type conversion for properties
      final rawProperties = feature['properties'];
      if (rawProperties == null) return null;

      final properties = Map<String, dynamic>.from(rawProperties as Map);

      print('🔍 Feature properties: ${properties.keys.toList()}');
      print('🔍 station_id: ${properties['station_id']}');
      print('🔍 streamOrde: ${properties['streamOrde']}');

      if (!properties.containsKey('station_id') ||
          !properties.containsKey('streamOrde')) {
        print('❌ Missing required properties (station_id or streamOrde)');
        return null;
      }

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
    clearHighlight();
    _mapboxMap = null;
    onReachSelected = null;
    onEmptyTap = null;
    print('🗑️ Research reach selection service disposed');
  }
}
