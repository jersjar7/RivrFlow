// lib/features/map/services/map_reach_selection_service.dart

import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/selected_reach.dart';
import '../models/visible_stream.dart';

/// Service for handling river reach selection from vector tiles
class MapReachSelectionService {
  MapboxMap? _mapboxMap;
  String? _currentHighlightLayerId; // Track current highlight layer

  // Store discovered streams from successful tap interactions
  final Map<String, VisibleStream> _discoveredStreams = {};

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

        // Store this stream for our "discovered streams" approach
        _addDiscoveredStream(selectedReach, tapPoint);

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

  /// Alternative approach: Get visible streams from discovered streams + camera bounds
  Future<List<VisibleStream>> getVisibleStreams() async {
    if (_mapboxMap == null) return [];

    try {
      print('🔍 Getting visible streams using alternative approach...');

      // Get current camera state to determine what's potentially visible
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      final zoom = cameraState.zoom;

      print(
        '📍 Camera center: ${center.coordinates.lng}, ${center.coordinates.lat}',
      );
      print('🔍 Zoom level: $zoom');

      // Calculate approximate visible bounds based on zoom level
      final visibleStreams = <VisibleStream>[];

      if (_discoveredStreams.isEmpty) {
        print(
          'ℹ️ No streams discovered yet. Try tapping on some streams first!',
        );
        return _createSampleStreamsForDemo(center, zoom);
      }

      // Filter discovered streams by proximity to current view
      final visibleRadius = _getVisibleRadiusForZoom(zoom);

      for (final stream in _discoveredStreams.values) {
        final distance = _calculateDistance(
          center.coordinates.lat.toDouble(),
          center.coordinates.lng.toDouble(),
          stream.latitude,
          stream.longitude,
        );

        if (distance <= visibleRadius) {
          visibleStreams.add(stream);
          print(
            '✅ Stream ${stream.stationId} is visible (${distance.toStringAsFixed(2)}km away)',
          );
        }
      }

      // Sort by distance from center
      visibleStreams.sort((a, b) {
        final distA = _calculateDistance(
          center.coordinates.lat.toDouble(),
          center.coordinates.lng.toDouble(),
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          center.coordinates.lat.toDouble(),
          center.coordinates.lng.toDouble(),
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });

      print('✅ Found ${visibleStreams.length} visible streams');
      return visibleStreams;
    } catch (e) {
      print('❌ Error getting visible streams: $e');
      return [];
    }
  }

  /// Create demo streams based on current camera position (fallback)
  List<VisibleStream> _createSampleStreamsForDemo(Point center, double zoom) {
    print('🎯 Creating sample streams for demo...');

    // Generate some realistic-looking stream data around the current view
    final sampleStreams = <VisibleStream>[];
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < 8; i++) {
      final offsetLng = (i - 4) * 0.01 * (15 - zoom); // Spread based on zoom
      final offsetLat = (i % 3 - 1) * 0.01 * (15 - zoom);

      sampleStreams.add(
        VisibleStream(
          stationId:
              '${(random + i) % 100000000}', // Generate realistic station IDs
          streamOrder: (i % 4) + 2, // Stream orders 2-5
          latitude: center.coordinates.lat + offsetLat,
          longitude: center.coordinates.lng + offsetLng,
          riverName: _getSampleRiverName(i),
        ),
      );
    }

    print('✅ Created ${sampleStreams.length} sample streams');
    return sampleStreams;
  }

  /// Get sample river names for demo
  String _getSampleRiverName(int index) {
    final names = [
      'Colorado River',
      'Snake River',
      'Salmon River',
      'Green River',
      'Yampa River',
      'Dolores River',
      'Arkansas River',
      'Rio Grande',
    ];
    return names[index % names.length];
  }

  /// Add a discovered stream from successful tap
  void _addDiscoveredStream(SelectedReach selectedReach, Point tapPoint) {
    final stream = VisibleStream(
      stationId: selectedReach.reachId,
      streamOrder: selectedReach.streamOrder,
      latitude: tapPoint.coordinates.lat.toDouble(),
      longitude: tapPoint.coordinates.lng.toDouble(),
      riverName: selectedReach.riverName,
    );

    _discoveredStreams[selectedReach.reachId] = stream;
    print('📝 Discovered stream: ${selectedReach.reachId}');
  }

  /// Calculate visible radius in kilometers based on zoom level
  double _getVisibleRadiusForZoom(double zoom) {
    // Approximate visible radius based on zoom level
    if (zoom >= 15) return 5; // Very zoomed in
    if (zoom >= 12) return 20; // City level
    if (zoom >= 10) return 50; // County level
    if (zoom >= 8) return 100; // State level
    return 200; // Country level
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
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

  /// Query vector tile features at specific point (WORKING - keep as-is)
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

      // Query the streams layers (excluding debug layer since it's commented out)
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

  /// Dispose resources
  void dispose() {
    clearHighlight(); // Clean up any highlights
    _discoveredStreams.clear();
    _mapboxMap = null;
    onReachSelected = null;
    onEmptyTap = null;
    print('🗑️ Reach selection service disposed');
  }
}
