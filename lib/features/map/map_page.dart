// lib/features/map/map_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivrflow/core/widgets/navigation_button.dart';
import 'package:rivrflow/features/map/widgets/map_search_widget.dart';
import '../../core/config.dart';
import '../../core/services/cache_service.dart';
import 'services/map_vector_tiles_service.dart';
import 'services/map_reach_selection_service.dart';
import 'services/map_marker_service.dart'; // Dedicated marker service
import 'models/selected_reach.dart';
import 'widgets/reach_details_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final _vectorTilesService = MapVectorTilesService();
  final _reachSelectionService = MapReachSelectionService();
  final _markerService = MapMarkerService(); // Marker service

  bool _isLoading = true;
  String? _errorMessage;
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    _setupSelectionCallbacks();
    _initializeCacheService();
  }

  void _setupSelectionCallbacks() {
    _reachSelectionService.onReachSelected = _onReachSelected;
    _reachSelectionService.onEmptyTap = _onEmptyTap;
  }

  /// Initialize cache service for recent searches and other caching needs
  Future<void> _initializeCacheService() async {
    try {
      await CacheService().initialize();
      print('🗄️ Cache service initialized for recent searches');
    } catch (e) {
      print('❌ Cache service initialization error: $e');
      // Don't fail the whole page if cache fails - search will still work
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(child: _buildMapContent());
  }

  Widget _buildMapContent() {
    if (_errorMessage != null) {
      return _buildError();
    }

    return Stack(
      children: [
        // Clean map widget without Consumer wrapper
        _buildMap(),

        // Search bar at bottom using SafeArea
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: SafeArea(
            child: CompactMapSearchBar(onTap: () => _showSearchModal()),
          ),
        ),

        // Floating back button positioned in top-left
        Positioned(
          top: 30,
          left: 0,
          child: FloatingBackButton(
            backgroundColor: CupertinoColors.white.withValues(alpha: 0.95),
            iconColor: CupertinoColors.systemBlue,
            margin: EdgeInsets.only(top: 8, left: 16),
          ),
        ),

        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildMap() {
    return MapWidget(
      key: const ValueKey('map'),
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            AppConfig.defaultLongitude,
            AppConfig.defaultLatitude,
          ),
        ),
        zoom: AppConfig.defaultZoom,
      ),
      styleUri: AppConfig.mapboxStyleUrl,
      textureView: true,
      onMapCreated: _onMapCreated,
      onTapListener: _onMapTap,
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: CupertinoColors.systemBackground.withOpacity(0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 16),
            Text(
              'Loading river map...',
              style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Map Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _retryMapLoad,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    try {
      print('🗺️ Map created, initializing...');

      // Wait a moment for map to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      print('🎨 Checking map style...');

      // Initialize core map services
      _vectorTilesService.setMapboxMap(mapboxMap);
      _reachSelectionService.setMapboxMap(mapboxMap);

      print('🚀 Services initialized, loading vector tiles...');

      // Load vector tiles
      await _vectorTilesService.loadRiverReaches();

      // Initialize marker service
      await _markerService.initializeMarkers(mapboxMap);

      print('✅ Map setup complete');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Map creation error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load river data: ${e.toString()}';
      });
    }
  }

  void _showSearchModal() {
    if (_mapboxMap == null) {
      print('❌ Map not ready for search');
      return;
    }

    showMapSearchModal(
      context,
      mapboxMap: _mapboxMap,
      onPlaceSelected: (place) {
        print(
          '🎯 Selected place: ${place.shortName} at ${place.latitude}, ${place.longitude}',
        );
      },
    );
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    // Handle normal reach selection
    await _reachSelectionService.handleMapTap(context);
  }

  void _onReachSelected(SelectedReach selectedReach) {
    showReachDetailsBottomSheet(
      context,
      selectedReach,
      onViewForecast: () => _navigateToForecast(selectedReach),
    );
  }

  void _onEmptyTap(Point point) {
    // Could add feedback here if needed
    // For now, just let any open bottom sheet stay open
  }

  void _navigateToForecast(SelectedReach selectedReach) {
    Navigator.of(context).pop(); // Close bottom sheet

    // Navigate to forecast page with reachId
    Navigator.of(
      context,
    ).pushNamed('/forecast', arguments: selectedReach.reachId);
  }

  void _retryMapLoad() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Reset services and retry
    _vectorTilesService.dispose();
    _markerService.dispose(); // NEW: Dispose marker service

    // Map will be recreated and _onMapCreated will be called again
  }

  // NEW: Expose marker service for wrapper widget
  MapMarkerService get markerService => _markerService;

  @override
  void dispose() {
    _vectorTilesService.dispose();
    _markerService.dispose(); // NEW: Dispose marker service
    super.dispose();
  }
}
