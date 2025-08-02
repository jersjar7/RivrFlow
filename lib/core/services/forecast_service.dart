// lib/core/services/forecast_service.dart

import '../models/reach_data.dart';
import 'noaa_api_service.dart';
import 'reach_cache_service.dart';

/// Simple service for loading complete forecast data
/// Combines reach info, return periods, and all forecast types
/// Now with caching for static reach data
class ForecastService {
  static final ForecastService _instance = ForecastService._internal();
  factory ForecastService() => _instance;
  ForecastService._internal();

  final NoaaApiService _apiService = NoaaApiService();
  final ReachCacheService _cacheService = ReachCacheService();

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

        // Merge return periods if available
        if (returnPeriods.isNotEmpty) {
          final returnPeriodData = ReachData.fromReturnPeriodApi(returnPeriods);
          reach = reach.mergeWith(returnPeriodData);
          print('FORECAST_SERVICE: ✅ Merged return period data');
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

  /// Get current flow value for display
  double? getCurrentFlow(ForecastResponse forecast, {String? preferredType}) {
    // Priority order for current flow display
    final types = preferredType != null
        ? [preferredType, 'short_range', 'medium_range', 'long_range']
        : ['short_range', 'medium_range', 'long_range'];

    for (final type in types) {
      final flow = forecast.getLatestFlow(type);
      if (flow != null) {
        print('FORECAST_SERVICE: Using $type for current flow: $flow');
        return flow;
      }
    }

    print('FORECAST_SERVICE: No current flow data available');
    return null;
  }

  /// Get flow category with return period context
  String getFlowCategory(ForecastResponse forecast, {String? preferredType}) {
    final flow = getCurrentFlow(forecast, preferredType: preferredType);
    if (flow == null) return 'Unknown';

    return forecast.reach.getFlowCategory(flow);
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

  /// Clean up resources
  void dispose() {
    _apiService.dispose();
  }
}
