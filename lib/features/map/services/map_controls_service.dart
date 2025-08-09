// lib/features/map/services/map_controls_service.dart

import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../widgets/base_layer_modal.dart';

class MapControlsService {
  MapboxMap? _mapboxMap;
  MapBaseLayer _currentLayer = MapBaseLayer.streets;
  geo.Position? _lastKnownLocation;

  // Default camera settings (you can adjust these based on your app's needs)
  static const double _defaultZoom = 14.0;
  static const int _animationDurationMs = 1000;

  MapBaseLayer get currentLayer => _currentLayer;
  geo.Position? get lastKnownLocation => _lastKnownLocation;

  void setMapboxMap(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  /// Initialize location services and get current position
  Future<geo.Position?> initializeLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      // Check permissions
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          print('❌ Location permissions are denied');
          return null;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        return null;
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastKnownLocation = position;
      print('📍 Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Recenter map to device location
  Future<void> recenterToDeviceLocation() async {
    if (_mapboxMap == null) {
      print('❌ Map not initialized');
      return;
    }

    try {
      // Try to get fresh location, but fall back to last known
      geo.Position? position = await initializeLocation();
      position ??= _lastKnownLocation;

      if (position == null) {
        print('❌ No location available for recentering');
        return;
      }

      // Create camera options for the new position
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: _defaultZoom,
      );

      // Animate to the new position
      await _mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: _animationDurationMs, startDelay: 0),
      );

      print('✅ Map recentered to device location');
    } catch (e) {
      print('❌ Error recentering map: $e');
    }
  }

  /// Change map base layer
  Future<void> changeBaseLayer(MapBaseLayer newLayer) async {
    if (_mapboxMap == null) {
      print('❌ Map not initialized');
      return;
    }

    try {
      await _mapboxMap!.loadStyleURI(newLayer.styleUrl);
      _currentLayer = newLayer;
      print('✅ Map layer changed to: ${newLayer.displayName}');
    } catch (e) {
      print('❌ Error changing map layer: $e');
    }
  }

  /// Get current map center for debugging/logging
  Future<Point?> getCurrentMapCenter() async {
    if (_mapboxMap == null) return null;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      return cameraState.center;
    } catch (e) {
      print('❌ Error getting map center: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _mapboxMap = null;
    _lastKnownLocation = null;
  }
}
