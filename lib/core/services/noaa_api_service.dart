// lib/core/services/noaa_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'error_service.dart';

/// Service for fetching data from NOAA APIs
/// Integrates with existing AppConfig and ErrorService
class NoaaApiService {
  static final NoaaApiService _instance = NoaaApiService._internal();
  factory NoaaApiService() => _instance;
  NoaaApiService._internal();

  final http.Client _client = http.Client();

  // STEP 2.1: Reach Info Fetching
  /// Fetch reach information from NOAA Reaches API
  /// Returns data in format expected by ReachData.fromNoaaApi()
  Future<Map<String, dynamic>> fetchReachInfo(String reachId) async {
    try {
      print('NOAA_API: Fetching reach info for: $reachId');

      final url = AppConfig.getReachUrl(reachId);
      print('NOAA_API: URL: $url');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'RivrFlow/1.0',
            },
          )
          .timeout(AppConfig.httpTimeout);

      print('NOAA_API: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('NOAA_API: Successfully fetched reach info');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Reach not found: $reachId');
      } else {
        throw Exception(
          'NOAA API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('NOAA_API: Error fetching reach info: $e');
      final userMessage = ErrorService.handleError(
        e,
        context: 'fetchReachInfo',
      );
      throw ApiException(userMessage);
    }
  }

  // STEP 2.2: Return Period Fetching
  /// Fetch return period data from NWM API
  /// Returns array data in format expected by ReachData.fromReturnPeriodApi()
  Future<List<dynamic>> fetchReturnPeriods(String reachId) async {
    try {
      print('NOAA_API: Fetching return periods for: $reachId');

      final url = AppConfig.getReturnPeriodUrl(reachId);
      print('NOAA_API: Return period URL: $url');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'RivrFlow/1.0',
            },
          )
          .timeout(AppConfig.httpTimeout);

      print('NOAA_API: Return period response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Ensure we return a List as expected by ReachData.fromReturnPeriodApi()
        if (data is List) {
          print(
            'NOAA_API: Successfully fetched return periods (${data.length} items)',
          );
          return data;
        } else {
          print(
            'NOAA_API: Return period API returned non-array data, wrapping in array',
          );
          return [data];
        }
      } else if (response.statusCode == 404) {
        print('NOAA_API: No return periods found for reach: $reachId');
        return []; // Return empty list instead of throwing
      } else {
        print('NOAA_API: Return period API error: ${response.statusCode}');
        return []; // Return empty list for non-critical data
      }
    } catch (e) {
      print('NOAA_API: Error fetching return periods: $e');
      // Don't throw for return periods - they're supplementary data
      // Just return empty list so reach loading doesn't fail
      return [];
    }
  }

  // STEP 2.3: Forecast Fetching
  /// Fetch streamflow forecast data from NOAA API for a specific series
  /// Returns data in format expected by ForecastResponse.fromJson()
  Future<Map<String, dynamic>> fetchForecast(
    String reachId,
    String series,
  ) async {
    try {
      print('NOAA_API: Fetching $series forecast for: $reachId');

      final url = AppConfig.getForecastUrl(reachId, series);
      print('NOAA_API: Forecast URL: $url');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'RivrFlow/1.0',
            },
          )
          .timeout(AppConfig.httpTimeout);

      print('NOAA_API: Forecast response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('NOAA_API: Successfully fetched $series forecast');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('$series forecast not available for reach: $reachId');
      } else {
        throw Exception(
          'Forecast API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('NOAA_API: Error fetching $series forecast: $e');
      final userMessage = ErrorService.handleError(e, context: 'fetchForecast');
      throw ApiException(userMessage);
    }
  }

  // STEP 2.4: Complete Forecast Fetching
  /// Fetch all available forecast types for a reach
  /// Orchestrates multiple API calls to get complete forecast data
  /// Returns combined data with all available forecasts
  Future<Map<String, dynamic>> fetchAllForecasts(String reachId) async {
    print('NOAA_API: Fetching all forecasts for reach: $reachId');

    // Initialize combined response structure
    Map<String, dynamic>? combinedResponse;
    final forecastTypes = ['short_range', 'medium_range', 'long_range'];
    final results = <String, Map<String, dynamic>?>{};

    // Fetch each forecast type
    for (final forecastType in forecastTypes) {
      try {
        print('NOAA_API: Attempting to fetch $forecastType...');
        final response = await fetchForecast(reachId, forecastType);
        results[forecastType] = response;

        // Use first successful response as base for reach info
        combinedResponse ??= response;

        print('NOAA_API: ✅ Successfully fetched $forecastType');
      } catch (e) {
        print('NOAA_API: ⚠️ Failed to fetch $forecastType: $e');
        results[forecastType] = null;
        // Continue with other forecast types
      }
    }

    // Check if we got at least one forecast
    if (combinedResponse == null) {
      throw ApiException(
        'No forecast data available for reach $reachId. All forecast types failed.',
      );
    }

    // Merge all successful forecasts into combined response
    final mergedResponse = Map<String, dynamic>.from(combinedResponse);

    // Clear forecast sections and rebuild with all available data
    mergedResponse['analysisAssimilation'] = {};
    mergedResponse['shortRange'] = {};
    mergedResponse['mediumRange'] = {};
    mergedResponse['longRange'] = {};
    mergedResponse['mediumRangeBlend'] = {};

    // Merge forecast data from each successful response
    for (final entry in results.entries) {
      final forecastType = entry.key;
      final response = entry.value;

      if (response != null) {
        // Merge the forecast sections from this response
        _mergeForecastSections(mergedResponse, response, forecastType);
      }
    }

    final successCount = results.values.where((r) => r != null).length;
    print(
      'NOAA_API: ✅ Successfully combined $successCount/$forecastTypes.length forecast types for reach $reachId',
    );

    return mergedResponse;
  }

  /// Helper method to merge forecast sections from individual responses
  void _mergeForecastSections(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
    String forecastType,
  ) {
    // Map forecast types to their response sections
    switch (forecastType) {
      case 'short_range':
        if (source['shortRange'] != null) {
          target['shortRange'] = source['shortRange'];
        }
        if (source['analysisAssimilation'] != null) {
          target['analysisAssimilation'] = source['analysisAssimilation'];
        }
        break;
      case 'medium_range':
        if (source['mediumRange'] != null) {
          target['mediumRange'] = source['mediumRange'];
        }
        if (source['mediumRangeBlend'] != null) {
          target['mediumRangeBlend'] = source['mediumRangeBlend'];
        }
        break;
      case 'long_range':
        if (source['longRange'] != null) {
          target['longRange'] = source['longRange'];
        }
        break;
    }
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
