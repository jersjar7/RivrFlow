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
  /// Fetch streamflow forecast data from NOAA API
  /// Returns data in format expected by ForecastResponse.fromJson()
  Future<Map<String, dynamic>> fetchForecast(String reachId) async {
    try {
      print('NOAA_API: Fetching forecast for: $reachId');

      final url = AppConfig.getForecastUrl(reachId);
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
        print('NOAA_API: Successfully fetched forecast');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Forecast not available for reach: $reachId');
      } else {
        throw Exception(
          'Forecast API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('NOAA_API: Error fetching forecast: $e');
      final userMessage = ErrorService.handleError(e, context: 'fetchForecast');
      throw ApiException(userMessage);
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
