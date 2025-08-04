// lib/features/map/map_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/models/reach_data.dart';
import 'package:rivrflow/core/widgets/back_navigation.dart';
import 'package:rivrflow/features/map/widgets/map_search_widget.dart';
import '../../core/config.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/forecast_service.dart'; // NEW: For getting ReachData
import '../../core/providers/favorites_provider.dart'; // NEW: For favorites integration
import 'services/map_vector_tiles_service.dart';
import 'services/map_reach_selection_service.dart';
import 'models/selected_reach.dart';
import 'widgets/reach_details_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _vectorTilesService = MapVectorTilesService();
  final _reachSelectionService = MapReachSelectionService();
  final _forecastService =
      ForecastService(); // NEW: For getting reach coordinates

  bool _isLoading = true;
  String? _errorMessage;
  MapboxMap? _mapboxMap;

  // NEW: Heart markers management
  final Map<String, String> _heartMarkers = {}; // reachId -> markerId mapping
  bool _areMarkersLoaded = false;

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
        // NEW: Wrap map with Consumer to listen to favorites changes
        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            // Update heart markers when favorites change
            if (_mapboxMap != null && _areMarkersLoaded) {
              _updateHeartMarkers(favoritesProvider);
            }
            return _buildMap();
          },
        ),

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

      // Check if map style is loaded
      print('🎨 Checking map style...');

      // Initialize services
      _vectorTilesService.setMapboxMap(mapboxMap);
      _reachSelectionService.setMapboxMap(mapboxMap);

      print('🚀 Services initialized, loading vector tiles...');

      // Load vector tiles
      await _vectorTilesService.loadRiverReaches();

      print('✅ Map setup complete');

      // NEW: Load heart markers after map is ready
      await _loadInitialHeartMarkers();

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

  // NEW: Load initial heart markers for existing favorites
  Future<void> _loadInitialHeartMarkers() async {
    if (!mounted) return;

    try {
      print('❤️ Loading initial heart markers...');
      final favoritesProvider = context.read<FavoritesProvider>();
      await _updateHeartMarkers(favoritesProvider);
      _areMarkersLoaded = true;
      print('✅ Heart markers loaded');
    } catch (e) {
      print('❌ Error loading heart markers: $e');
      // Don't fail map loading if markers fail
      _areMarkersLoaded = true;
    }
  }

  // NEW: Update heart markers based on favorites
  Future<void> _updateHeartMarkers(FavoritesProvider favoritesProvider) async {
    if (_mapboxMap == null || !mounted) return;

    try {
      final favorites = favoritesProvider.favorites;
      print('❤️ Updating heart markers for ${favorites.length} favorites');

      // Remove markers for reaches that are no longer favorited
      final currentReachIds = favorites.map((f) => f.reachId).toSet();
      final markersToRemove = _heartMarkers.keys
          .where((reachId) => !currentReachIds.contains(reachId))
          .toList();

      for (final reachId in markersToRemove) {
        await _removeHeartMarker(reachId);
      }

      // Add/update markers for current favorites
      for (final favorite in favorites) {
        if (!_heartMarkers.containsKey(favorite.reachId)) {
          await _addHeartMarker(favorite.reachId);
        }
      }

      print('✅ Heart markers updated: ${_heartMarkers.length} markers');
    } catch (e) {
      print('❌ Error updating heart markers: $e');
    }
  }

  // NEW: Add heart marker for a favorite reach
  Future<void> _addHeartMarker(String reachId) async {
    if (_mapboxMap == null) return;

    try {
      // Get reach coordinates from cache/service
      final reachData = await _getReachCoordinates(reachId);
      if (reachData == null) {
        print('⚠️ Could not get coordinates for reach: $reachId');
        return;
      }

      final markerId = 'heart_$reachId';

      // Create heart marker annotation
      final heartAnnotation = PointAnnotation(
        id: markerId,
        geometry: Point(
          coordinates: Position(reachData.longitude, reachData.latitude),
        ),
        textField: '❤️', // Heart emoji as marker
        textSize: 20.0,
        textColor: Colors.red.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 2.0,
      );

      // Add marker to map
      await _mapboxMap!.annotations.createPointAnnotationManager().then((
        manager,
      ) async {
        await manager.create(heartAnnotation as PointAnnotationOptions);
      });

      _heartMarkers[reachId] = markerId;
      print('✅ Added heart marker for reach: $reachId');
    } catch (e) {
      print('❌ Error adding heart marker for $reachId: $e');
    }
  }

  // NEW: Remove heart marker for a reach
  Future<void> _removeHeartMarker(String reachId) async {
    if (_mapboxMap == null || !_heartMarkers.containsKey(reachId)) return;

    try {
      // Remove marker from map (this is a simplified approach)
      // In practice, you might need to track the annotation manager
      // and call manager.delete() with the specific annotation

      _heartMarkers.remove(reachId);
      print('✅ Removed heart marker for reach: $reachId');
    } catch (e) {
      print('❌ Error removing heart marker for $reachId: $e');
    }
  }

  // NEW: Get reach coordinates (from cache or API)
  Future<ReachData?> _getReachCoordinates(String reachId) async {
    try {
      // Try to get from existing cache first
      if (await _forecastService.isReachCached(reachId)) {
        final forecast = await _forecastService.loadCompleteReachData(reachId);
        return forecast.reach;
      }

      // If not cached, we need to load it
      // This will cache it for future use
      final forecast = await _forecastService.loadCompleteReachData(reachId);
      return forecast.reach;
    } catch (e) {
      print('❌ Error getting coordinates for $reachId: $e');
      return null;
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
    // NEW: Check if tap was on a heart marker first
    if (await _handleHeartMarkerTap(context)) {
      return; // Heart marker was tapped
    }

    // Otherwise, handle normal reach selection
    await _reachSelectionService.handleMapTap(context);
  }

  // NEW: Handle heart marker tap interactions
  Future<bool> _handleHeartMarkerTap(MapContentGestureContext context) async {
    if (_mapboxMap == null || _heartMarkers.isEmpty) return false;

    try {
      final tapPoint = context.point;

      // Check if any heart markers are in the tap area
      for (final entry in _heartMarkers.entries) {
        final reachId = entry.key;

        // Get reach coordinates to check distance
        final reachData = await _getReachCoordinates(reachId);
        if (reachData == null) continue;

        // Simple distance check
        final distance = _calculateDistance(
          tapPoint.coordinates.lat.toDouble(),
          tapPoint.coordinates.lng.toDouble(),
          reachData.latitude,
          reachData.longitude,
        );

        // If tap is close to heart marker (within ~50 meters)
        if (distance < 0.0005) {
          // Rough degree approximation
          print('❤️ Heart marker tapped for reach: $reachId');
          await _onHeartMarkerTapped(reachId);
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error handling heart marker tap: $e');
      return false;
    }
  }

  // NEW: Handle heart marker tap - show reach details
  Future<void> _onHeartMarkerTapped(String reachId) async {
    try {
      // Create a SelectedReach from the favorited reach
      final reachData = await _getReachCoordinates(reachId);
      if (reachData == null) {
        print('⚠️ Could not load reach data for favorited reach: $reachId');
        return;
      }

      // Create SelectedReach object (corrected constructor)
      final selectedReach = SelectedReach(
        reachId: reachId,
        streamOrder: 0, // We don't have stream order from favorites
        latitude: reachData.latitude,
        longitude: reachData.longitude,
        riverName: reachData.riverName.isNotEmpty
            ? reachData.riverName
            : 'Reach $reachId',
        city: reachData.city,
        state: reachData.state,
        selectedAt: DateTime.now(), // NEW: Required parameter
      );

      // Show reach details bottom sheet
      _onReachSelected(selectedReach);
    } catch (e) {
      print('❌ Error handling heart marker tap: $e');
    }
  }

  // NEW: Simple distance calculation helper
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final deltaLat = lat1 - lat2;
    final deltaLng = lng1 - lng2;
    return (deltaLat * deltaLat + deltaLng * deltaLng);
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
      _areMarkersLoaded = false;
      _heartMarkers.clear();
    });

    // Reset services and retry
    _vectorTilesService.dispose();

    // Map will be recreated and _onMapCreated will be called again
  }

  @override
  void dispose() {
    _vectorTilesService.dispose();
    _forecastService.dispose();
    super.dispose();
  }
}
