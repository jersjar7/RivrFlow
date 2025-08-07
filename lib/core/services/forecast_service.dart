// lib/core/services/forecast_service.dart

import 'package:rivrflow/features/map/widgets/map_search_widget.dart';

import '../models/reach_data.dart';
import 'noaa_api_service.dart';
import 'reach_cache_service.dart';

/// Simple service for loading complete forecast data
/// Combines reach info, return periods, and all forecast types
/// Now with phased loading for better performance
class ForecastService {
  static final ForecastService _instance = ForecastService._internal();
  factory ForecastService() => _instance;
  ForecastService._internal();

  final NoaaApiService _apiService = NoaaApiService();
  final ReachCacheService _cacheService = ReachCacheService();

  // Cache computed values to avoid repeated calculations
  final Map<String, double?> _currentFlowCache = {};
  final Map<String, String> _flowCategoryCache = {};

  // PHASE 1 - Load minimal data for overview page
  /// Load only essential data for overview page: reach info + current flow
  /// This is the fastest possible load - only what's needed immediately
  Future<ForecastResponse> loadOverviewData(String reachId) async {
    try {
      print('FORECAST_SERVICE: Loading overview data for reach: $reachId');

      // Step 1: Check cache for reach data first
      final cachedReach = await _cacheService.get(reachId);

      ReachData reach;
      if (cachedReach != null) {
        print('FORECAST_SERVICE: ✅ Using cached reach data');
        reach = cachedReach;
        print(
          '🐛 DEBUG: Cached reach has city=${reach.city}, state=${reach.state}',
        );

        // ⭐ KEY FIX: Check if cached reach needs geocoding
        if (reach.city == null || reach.state == null) {
          print(
            '🐛 DEBUG: Cached reach needs geocoding - adding location data',
          );
          print(
            'FORECAST_SERVICE: Adding location to cached reach via reverse geocoding',
          );

          try {
            print(
              '🐛 DEBUG: About to call MapSearchService.reverseGeocode for cached reach',
            );
            print(
              '🐛 DEBUG: Geocoding coordinates: lat=${reach.latitude}, lng=${reach.longitude}',
            );

            final locationData = await MapSearchService.reverseGeocode(
              reach.latitude,
              reach.longitude,
            );

            print('🐛 DEBUG: Geocoding returned: $locationData');
            print('🐛 DEBUG: City from geocoding: ${locationData['city']}');
            print('🐛 DEBUG: State from geocoding: ${locationData['state']}');

            // Update cached reach with city/state
            reach = reach.copyWith(
              city: locationData['city'],
              state: locationData['state'],
            );

            print(
              '🐛 DEBUG: Updated cached reach: city=${reach.city}, state=${reach.state}',
            );
            print(
              'FORECAST_SERVICE: ✅ Enhanced cached reach with location: ${reach.city}, ${reach.state}',
            );

            // Re-cache the updated reach data
            await _cacheService.store(reach);
            print(
              'FORECAST_SERVICE: ✅ Re-cached reach data with location info',
            );
          } catch (e) {
            print('🐛 DEBUG: Exception in geocoding cached reach: $e');
            print(
              'FORECAST_SERVICE: ⚠️ Reverse geocoding failed for cached reach: $e',
            );
          }
        } else {
          print(
            '🐛 DEBUG: Cached reach already has location: city=${reach.city}, state=${reach.state}',
          );
        }
      } else {
        print('FORECAST_SERVICE: Cache miss - fetching reach info only');

        // Step 2: Fetch reach info from NOAA API
        final reachInfo = await _apiService.fetchReachInfo(
          reachId,
          isOverview: true,
        );

        // Step 3: Create initial reach data from API response
        reach = ReachData.fromNoaaApi(reachInfo);
        print(
          '🐛 DEBUG: Reach from NOAA API: city=${reach.city}, state=${reach.state}',
        );
        print('🐛 DEBUG: Coordinates: ${reach.latitude}, ${reach.longitude}');

        // Step 4: IMMEDIATELY do reverse geocoding BEFORE any caching
        if (reach.city == null || reach.state == null) {
          print('🐛 DEBUG: New reach needs geocoding - missing city/state');
          print(
            'FORECAST_SERVICE: Performing reverse geocoding for complete location data',
          );

          try {
            print(
              '🐛 DEBUG: About to call MapSearchService.reverseGeocode for new reach',
            );
            print(
              '🐛 DEBUG: Geocoding coordinates: lat=${reach.latitude}, lng=${reach.longitude}',
            );

            final locationData = await MapSearchService.reverseGeocode(
              reach.latitude,
              reach.longitude,
            );

            print('🐛 DEBUG: Geocoding returned: $locationData');
            print('🐛 DEBUG: City from geocoding: ${locationData['city']}');
            print('🐛 DEBUG: State from geocoding: ${locationData['state']}');

            // Update reach with city/state BEFORE caching
            reach = reach.copyWith(
              city: locationData['city'],
              state: locationData['state'],
              isPartiallyLoaded:
                  true, // Still partial since no return periods yet
            );

            print(
              '🐛 DEBUG: Reach AFTER geocoding: city=${reach.city}, state=${reach.state}',
            );
            print(
              'FORECAST_SERVICE: ✅ Enhanced with location: ${reach.city}, ${reach.state}',
            );
          } catch (e) {
            print('🐛 DEBUG: Exception in geocoding new reach: $e');
            print('FORECAST_SERVICE: ⚠️ Reverse geocoding failed: $e');
            reach = reach.copyWith(isPartiallyLoaded: true);
          }
        } else {
          print(
            '🐛 DEBUG: New reach already has location: city=${reach.city}, state=${reach.state}',
          );
        }

        // Step 5: Now cache the reach data with city/state already populated
        await _cacheService.store(reach);
        print('FORECAST_SERVICE: ✅ Cached reach data with location info');
        print(
          '🐛 DEBUG: Final reach before caching: city=${reach.city}, state=${reach.state}',
        );
      }

      // Step 6: Get only short-range forecast for current flow
      final shortRangeData = await _apiService.fetchCurrentFlowOnly(reachId);
      final forecastResponse = ForecastResponse.fromJson(shortRangeData);

      final overviewResponse = ForecastResponse(
        reach:
            reach, // Now guaranteed to have city/state if geocoding succeeded!
        shortRange: forecastResponse.shortRange,
        analysisAssimilation: forecastResponse.analysisAssimilation,
        mediumRange: {}, // Empty map - not loaded yet
        longRange: {}, // Empty map - not loaded yet
        mediumRangeBlend: null, // This is nullable, so null is OK
      );

      print('FORECAST_SERVICE: ✅ Overview data loaded successfully');
      print(
        '🐛 DEBUG: Final response reach: city=${overviewResponse.reach.city}, state=${overviewResponse.reach.state}',
      );

      return overviewResponse;
    } catch (e) {
      print('FORECAST_SERVICE: ❌ Error loading overview data: $e');
      rethrow;
    }
  }

  // PHASE 2 - Add return periods and forecast summaries
  /// Load supplementary data: return periods + other forecast summaries
  /// Call this after overview data is displayed to enhance functionality
  Future<ForecastResponse> loadSupplementaryData(
    String reachId,
    ForecastResponse existingData,
  ) async {
    try {
      print('FORECAST_SERVICE: Loading supplementary data for reach: $reachId');

      ReachData reach = existingData.reach;

      // Only load return periods if we don't have them
      if (!reach.hasReturnPeriods) {
        try {
          final returnPeriods = await _apiService.fetchReturnPeriods(reachId);
          if (returnPeriods.isNotEmpty) {
            final returnPeriodData = ReachData.fromReturnPeriodApi(
              returnPeriods,
            );
            reach = reach.mergeWith(returnPeriodData);

            // Update cache with complete data
            await _cacheService.store(reach);
            print('FORECAST_SERVICE: ✅ Added return period data');
          }
        } catch (e) {
          print('FORECAST_SERVICE: ⚠️ Return periods failed, continuing: $e');
          // Continue without return periods
        }
      }

      // Load medium-range summary for forecast grid (don't need full data)
      ForecastResponse enhancedResponse = existingData;
      try {
        final mediumRangeData = await _apiService.fetchForecast(
          reachId,
          'medium_range',
        );
        final mediumForecast = ForecastResponse.fromJson(mediumRangeData);

        enhancedResponse = ForecastResponse(
          reach: reach,
          analysisAssimilation: existingData.analysisAssimilation,
          shortRange: existingData.shortRange,
          mediumRange: mediumForecast.mediumRange,
          longRange: existingData.longRange,
          mediumRangeBlend: existingData.mediumRangeBlend,
        );
      } catch (e) {
        print(
          'FORECAST_SERVICE: ⚠️ Medium range forecast failed, continuing: $e',
        );
        // Use existing data if medium range fails
        enhancedResponse = ForecastResponse(
          reach: reach,
          analysisAssimilation: existingData.analysisAssimilation,
          shortRange: existingData.shortRange,
          mediumRange: existingData.mediumRange,
          longRange: existingData.longRange,
          mediumRangeBlend: existingData.mediumRangeBlend,
        );
      }

      // Update cached flow category now that we have return periods
      if (reach.hasReturnPeriods) {
        final currentFlow = getCurrentFlow(enhancedResponse);
        if (currentFlow != null) {
          _flowCategoryCache[reachId] = reach.getFlowCategory(currentFlow);
        }
      }

      print('FORECAST_SERVICE: ✅ Supplementary data loaded successfully');
      return enhancedResponse;
    } catch (e) {
      print('FORECAST_SERVICE: ❌ Error loading supplementary data: $e');
      // Return existing data if supplementary loading fails
      return existingData;
    }
  }

  // Keep for backwards compatibility and detail pages
  /// Load complete reach and forecast data
  /// Returns ForecastResponse with all available forecast types
  /// Uses cache for static reach data, always fetches fresh forecast data
  Future<ForecastResponse> loadCompleteReachData(String reachId) async {
    try {
      print('FORECAST_SERVICE: Loading complete data for reach: $reachId');

      // Step 1: Check cache for reach data first
      final cachedReach = await _cacheService.get(reachId);

      ReachData reach;
      if (cachedReach != null) {
        print('FORECAST_SERVICE: ✅ Using cached reach data');
        reach = cachedReach;
      } else {
        print('FORECAST_SERVICE: Cache miss - fetching fresh reach data');

        // Step 2: Get reach info and return periods in parallel
        final futures = await Future.wait([
          _apiService.fetchReachInfo(reachId),
          _apiService.fetchReturnPeriods(reachId),
        ]);

        final reachInfo = futures[0] as Map<String, dynamic>;
        final returnPeriods = futures[1] as List<dynamic>;

        print('FORECAST_SERVICE: ✅ Loaded reach info and return periods');

        // Step 3: Create complete reach data
        reach = ReachData.fromNoaaApi(reachInfo);

        // 🔧 FIX: Wrap return period processing in try-catch
        try {
          // Merge return periods if available
          if (returnPeriods.isNotEmpty) {
            final returnPeriodData = ReachData.fromReturnPeriodApi(
              returnPeriods,
            );
            reach = reach.mergeWith(returnPeriodData);
            print('FORECAST_SERVICE: ✅ Merged return period data');
          }
        } catch (e) {
          print(
            'FORECAST_SERVICE: ⚠️ Failed to parse return periods for reach $reachId: $e',
          );
          print('FORECAST_SERVICE: ✅ Continuing without return period data');
          // Continue without return periods - the reach will work fine without them
          // No need to throw or break the entire loading process
        }

        // Step 4: Cache the complete reach data
        await _cacheService.store(reach);
        print('FORECAST_SERVICE: ✅ Cached reach data');
      }

      // Step 5: Always get fresh forecast data (this changes frequently)
      final forecastData = await _apiService.fetchAllForecasts(reachId);
      print('FORECAST_SERVICE: ✅ Loaded fresh forecast data');

      // Step 6: Create forecast response with cached/fresh reach data + fresh forecasts
      final forecastResponse = ForecastResponse.fromJson(forecastData);
      final completeResponse = ForecastResponse(
        reach: reach, // Use cached or fresh reach data
        analysisAssimilation: forecastResponse.analysisAssimilation,
        shortRange: forecastResponse.shortRange,
        mediumRange: forecastResponse.mediumRange,
        longRange: forecastResponse.longRange,
        mediumRangeBlend: forecastResponse.mediumRangeBlend,
      );

      // Update caches
      final currentFlow = getCurrentFlow(completeResponse);
      if (currentFlow != null) {
        _currentFlowCache[reachId] = currentFlow;
        if (reach.hasReturnPeriods) {
          _flowCategoryCache[reachId] = reach.getFlowCategory(currentFlow);
        }
      }

      print('FORECAST_SERVICE: ✅ Complete data loaded successfully');
      return completeResponse;
    } catch (e) {
      print('FORECAST_SERVICE: ❌ Error loading complete data: $e');
      rethrow;
    }
  }

  /// Load only specific forecast type (faster for simple displays)
  /// Also uses cache for reach data
  Future<ForecastResponse> loadSpecificForecast(
    String reachId,
    String forecastType,
  ) async {
    try {
      print(
        'FORECAST_SERVICE: Loading $forecastType forecast for reach: $reachId',
      );

      // Check cache for reach data first
      final cachedReach = await _cacheService.get(reachId);

      ReachData reach;
      if (cachedReach != null) {
        print(
          'FORECAST_SERVICE: ✅ Using cached reach data for specific forecast',
        );
        reach = cachedReach;

        // Only fetch the specific forecast
        final forecastData = await _apiService.fetchForecast(
          reachId,
          forecastType,
        );
        final forecastResponse = ForecastResponse.fromJson(forecastData);

        final specificResponse = ForecastResponse(
          reach: reach, // Use cached reach data
          analysisAssimilation: forecastResponse.analysisAssimilation,
          shortRange: forecastResponse.shortRange,
          mediumRange: forecastResponse.mediumRange,
          longRange: forecastResponse.longRange,
          mediumRangeBlend: forecastResponse.mediumRangeBlend,
        );

        print(
          'FORECAST_SERVICE: ✅ $forecastType forecast loaded with cached reach data',
        );
        return specificResponse;
      } else {
        // Cache miss - get both reach info and forecast
        final futures = await Future.wait([
          _apiService.fetchReachInfo(reachId),
          _apiService.fetchForecast(reachId, forecastType),
        ]);

        final reachInfo = futures[0];
        final forecastData = futures[1];

        // Create reach data and cache it
        reach = ReachData.fromNoaaApi(reachInfo);
        await _cacheService.store(reach);

        // Parse forecast response
        final forecastResponse = ForecastResponse.fromJson(forecastData);
        final specificResponse = ForecastResponse(
          reach: reach,
          analysisAssimilation: forecastResponse.analysisAssimilation,
          shortRange: forecastResponse.shortRange,
          mediumRange: forecastResponse.mediumRange,
          longRange: forecastResponse.longRange,
          mediumRangeBlend: forecastResponse.mediumRangeBlend,
        );

        print(
          'FORECAST_SERVICE: ✅ $forecastType forecast loaded and reach data cached',
        );
        return specificResponse;
      }
    } catch (e) {
      print('FORECAST_SERVICE: ❌ Error loading $forecastType forecast: $e');
      rethrow;
    }
  }

  /// Force refresh reach data (clear cache and fetch fresh)
  Future<ForecastResponse> refreshReachData(String reachId) async {
    print('FORECAST_SERVICE: Force refreshing reach data for: $reachId');
    await _cacheService.forceRefresh(reachId);

    // Clear computed caches too
    _currentFlowCache.remove(reachId);
    _flowCategoryCache.remove(reachId);

    return await loadCompleteReachData(reachId);
  }

  /// Check if reach data is cached
  Future<bool> isReachCached(String reachId) async {
    return await _cacheService.isCached(reachId);
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }

  // Use cache first, then compute if needed
  /// Get current flow value for display - now with caching
  double? getCurrentFlow(ForecastResponse forecast, {String? preferredType}) {
    final reachId = forecast.reach.reachId;

    // Check cache first
    if (_currentFlowCache.containsKey(reachId)) {
      return _currentFlowCache[reachId];
    }

    // Priority order for current flow display
    final types = preferredType != null
        ? [preferredType, 'short_range', 'medium_range', 'long_range']
        : ['short_range', 'medium_range', 'long_range'];

    for (final type in types) {
      final flow = forecast.getLatestFlow(type);
      // 🔧 Filter out missing data values
      if (flow != null && flow > -9000) {
        // Check for missing data sentinel values
        print('FORECAST_SERVICE: Using $type for current flow: $flow');

        // Cache the result
        _currentFlowCache[reachId] = flow;
        return flow;
      }
    }

    print('FORECAST_SERVICE: No current flow data available');
    _currentFlowCache[reachId] = null; // Cache null result too
    return null;
  }

  // Use cache first, then compute if needed
  /// Get flow category with return period context - now with caching
  String getFlowCategory(ForecastResponse forecast, {String? preferredType}) {
    final reachId = forecast.reach.reachId;

    // Check cache first
    if (_flowCategoryCache.containsKey(reachId)) {
      return _flowCategoryCache[reachId]!;
    }

    final flow = getCurrentFlow(forecast, preferredType: preferredType);
    if (flow == null) return 'Unknown';

    final category = forecast.reach.getFlowCategory(flow);

    // Cache the result
    _flowCategoryCache[reachId] = category;
    return category;
  }

  /// Get available forecast types
  List<String> getAvailableForecastTypes(ForecastResponse forecast) {
    final available = <String>[];

    if (forecast.shortRange?.isNotEmpty == true) {
      available.add('short_range');
    }
    if (forecast.mediumRange.isNotEmpty) {
      available.add('medium_range');
    }
    if (forecast.longRange.isNotEmpty) {
      available.add('long_range');
    }
    if (forecast.analysisAssimilation?.isNotEmpty == true) {
      available.add('analysis_assimilation');
    }
    if (forecast.mediumRangeBlend?.isNotEmpty == true) {
      available.add('medium_range_blend');
    }

    return available;
  }

  /// Check if reach has ensemble data for hydrographs
  bool hasEnsembleData(ForecastResponse forecast) {
    return forecast.mediumRange.length > 1 || forecast.longRange.length > 1;
  }

  /// Get ensemble summary for a forecast type
  Map<String, dynamic> getEnsembleSummary(
    ForecastResponse forecast,
    String forecastType,
  ) {
    final ensemble = forecast.getAllEnsembleData(forecastType);
    if (ensemble.isEmpty) {
      return {'available': false};
    }

    final memberKeys = ensemble.keys
        .where((k) => k.startsWith('member'))
        .toList();
    final hasMean = ensemble.containsKey('mean');

    return {
      'available': true,
      'hasMean': hasMean,
      'memberCount': memberKeys.length,
      'members': memberKeys,
      'dataSource': forecast.getDataSource(forecastType),
    };
  }

  // NEW: Clear all caches (useful for testing)
  void clearComputedCaches() {
    _currentFlowCache.clear();
    _flowCategoryCache.clear();
    print('FORECAST_SERVICE: Cleared computed value caches');
  }
}
