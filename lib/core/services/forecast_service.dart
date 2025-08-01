// lib/core/services/forecast_service.dart

import '../models/reach_data.dart';
import 'noaa_api_service.dart';

/// Simple service for loading complete forecast data
/// Combines reach info, return periods, and all forecast types
class ForecastService {
  static final ForecastService _instance = ForecastService._internal();
  factory ForecastService() => _instance;
  ForecastService._internal();

  final NoaaApiService _apiService = NoaaApiService();

  /// Load complete reach and forecast data
  /// Returns ForecastResponse with all available forecast types
  Future<ForecastResponse> loadCompleteReachData(String reachId) async {
    try {
      print('FORECAST_SERVICE: Loading complete data for reach: $reachId');

      // Step 1: Get reach info and return periods in parallel
      final futures = await Future.wait([
        _apiService.fetchReachInfo(reachId),
        _apiService.fetchReturnPeriods(reachId),
      ]);

      final reachInfo = futures[0] as Map<String, dynamic>;
      final returnPeriods = futures[1] as List<dynamic>;

      print('FORECAST_SERVICE: ✅ Loaded reach info and return periods');

      // Step 2: Get all forecasts
      final forecastData = await _apiService.fetchAllForecasts(reachId);

      print('FORECAST_SERVICE: ✅ Loaded forecast data');

      // Step 3: Create complete reach data
      var reach = ReachData.fromNoaaApi(reachInfo);

      // Merge return periods if available
      if (returnPeriods.isNotEmpty) {
        final returnPeriodData = ReachData.fromReturnPeriodApi(returnPeriods);
        reach = reach.mergeWith(returnPeriodData);
        print('FORECAST_SERVICE: ✅ Merged return period data');
      }

      // Step 4: Create forecast response with complete reach data
      final forecastResponse = ForecastResponse.fromJson(forecastData);
      final completeResponse = ForecastResponse(
        reach: reach, // Use our enhanced reach data
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
  Future<ForecastResponse> loadSpecificForecast(
    String reachId,
    String forecastType,
  ) async {
    try {
      print(
        'FORECAST_SERVICE: Loading $forecastType forecast for reach: $reachId',
      );

      // Get reach info and specific forecast in parallel
      final futures = await Future.wait([
        _apiService.fetchReachInfo(reachId),
        _apiService.fetchForecast(reachId, forecastType),
      ]);

      final reachInfo = futures[0];
      final forecastData = futures[1];

      // Create reach data
      final reach = ReachData.fromNoaaApi(reachInfo);

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

      print('FORECAST_SERVICE: ✅ $forecastType forecast loaded successfully');
      return specificResponse;
    } catch (e) {
      print('FORECAST_SERVICE: ❌ Error loading $forecastType forecast: $e');
      rethrow;
    }
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
