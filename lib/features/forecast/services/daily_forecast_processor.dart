// lib/features/forecast/services/daily_forecast_processor.dart

import '../../../core/models/reach_data.dart';
import '../../../core/services/flow_unit_preference_service.dart';
import '../domain/entities/daily_flow_forecast.dart';

/// Service for processing ensemble forecast data into daily summaries
///
/// Converts raw hourly ensemble data (from medium/long range forecasts) into
/// structured daily forecasts suitable for display in expandable widgets.
/// Prioritizes 'mean' data with fallback to first available ensemble member.
class DailyForecastProcessor {
  /// Process medium or long range forecast data into daily summaries
  ///
  /// [forecastData] - The ensemble forecast data (mediumRange or longRange from ForecastResponse)
  /// [reach] - The reach data containing return period information for flow categorization
  /// [forecastType] - Type identifier ('medium_range' or 'long_range') for tracking
  ///
  /// Returns a list of DailyFlowForecast objects, one per day covered by the forecast
  /// NOTE: Flow values are already converted to user's preferred unit by NoaaApiService
  static List<DailyFlowForecast> processForecastData({
    required Map<String, ForecastSeries> forecastData,
    required ReachData reach,
    required String forecastType,
  }) {
    if (forecastData.isEmpty) {
      print('DAILY_PROCESSOR: No forecast data available for $forecastType');
      return [];
    }

    // Step 1: Get the preferred data source (mean first, then first member)
    final selectedData = _selectDataSource(forecastData);
    if (selectedData == null) {
      print('DAILY_PROCESSOR: No valid data source found in $forecastType');
      return [];
    }

    final dataSource = selectedData['source'] as String;
    final forecastSeries = selectedData['series'] as ForecastSeries;

    // NEW: Get the current unit from the forecast series (already converted by NoaaApiService)
    final dataUnit =
        forecastSeries.units; // Will be CFS or CMS based on user preference

    print(
      'DAILY_PROCESSOR: Using $dataSource for $forecastType (${forecastSeries.data.length} points, $dataUnit)',
    );

    // Step 2: Group hourly data by calendar date
    final dailyGroups = _groupHourlyDataByDate(forecastSeries);

    // Step 3: Process each day's data into DailyFlowForecast objects
    final dailyForecasts = <DailyFlowForecast>[];

    for (final entry in dailyGroups.entries) {
      final date = entry.key;
      final hourlyData = entry.value;

      if (hourlyData.isEmpty) continue;

      try {
        final dailyForecast = _processDailyData(
          date: date,
          hourlyData: hourlyData,
          dataSource: dataSource,
          reach: reach,
          dataUnit: dataUnit, // Pass the unit information
        );

        if (dailyForecast != null) {
          dailyForecasts.add(dailyForecast);
        }
      } catch (e) {
        print('DAILY_PROCESSOR: Error processing day $date: $e');
        continue;
      }
    }

    // Sort by date for consistent ordering
    dailyForecasts.sort((a, b) => a.date.compareTo(b.date));

    print(
      'DAILY_PROCESSOR: Generated ${dailyForecasts.length} daily forecasts from $dataSource ($dataUnit)',
    );
    return dailyForecasts;
  }

  /// Convenience method for processing medium range data specifically
  static List<DailyFlowForecast> processMediumRange({
    required ForecastResponse forecastResponse,
  }) {
    return processForecastData(
      forecastData: forecastResponse.mediumRange,
      reach: forecastResponse.reach,
      forecastType: 'medium_range',
    );
  }

  /// Convenience method for processing long range data specifically
  static List<DailyFlowForecast> processLongRange({
    required ForecastResponse forecastResponse,
  }) {
    return processForecastData(
      forecastData: forecastResponse.longRange,
      reach: forecastResponse.reach,
      forecastType: 'long_range',
    );
  }

  /// Calculate overall flow bounds across all daily forecasts for widget scaling
  static Map<String, double> getFlowBounds(List<DailyFlowForecast> forecasts) {
    if (forecasts.isEmpty) {
      return {'min': 0.0, 'max': 100.0};
    }

    double minFlow = forecasts.first.minFlow;
    double maxFlow = forecasts.first.maxFlow;

    for (final forecast in forecasts) {
      if (forecast.minFlow < minFlow) minFlow = forecast.minFlow;
      if (forecast.maxFlow > maxFlow) maxFlow = forecast.maxFlow;
    }

    // Add 5% padding for visual clarity
    final range = maxFlow - minFlow;
    final padding = range * 0.05;

    return {
      'min': (minFlow - padding).clamp(0.0, double.infinity),
      'max': maxFlow + padding,
    };
  }

  /// Get a user-friendly day label for display (Today, Tomorrow, Mon, Tue, etc.)
  static String getDayLabel(DateTime date, {bool isToday = false}) {
    if (isToday) return 'Today';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final forecastDate = DateTime(date.year, date.month, date.day);
    final difference = forecastDate.difference(today).inDays;

    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';

    // Use weekday names for dates within a week
    if (difference.abs() <= 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }

    // Use month/day for dates further out
    return '${date.month}/${date.day}';
  }

  // Private helper methods

  /// Select the preferred data source from ensemble data
  /// Priority: mean > first available member
  static Map<String, dynamic>? _selectDataSource(
    Map<String, ForecastSeries> forecastData,
  ) {
    // First preference: mean data
    if (forecastData.containsKey('mean')) {
      final meanSeries = forecastData['mean']!;
      if (meanSeries.isNotEmpty) {
        return {'source': 'mean', 'series': meanSeries};
      }
    }

    // Fallback: first available member
    final memberKeys = forecastData.keys
        .where((key) => key.startsWith('member'))
        .toList();

    memberKeys.sort(); // Ensure consistent order: member01, member02, etc.

    for (final memberKey in memberKeys) {
      final memberSeries = forecastData[memberKey]!;
      if (memberSeries.isNotEmpty) {
        return {'source': memberKey, 'series': memberSeries};
      }
    }

    return null; // No valid data found
  }

  /// Group hourly forecast points by calendar date (local time)
  static Map<DateTime, Map<DateTime, double>> _groupHourlyDataByDate(
    ForecastSeries forecastSeries,
  ) {
    final dailyGroups = <DateTime, Map<DateTime, double>>{};

    for (final point in forecastSeries.data) {
      // Convert to local time and get the calendar date
      final localTime = point.validTime.toLocal();
      final dateKey = DateTime(localTime.year, localTime.month, localTime.day);

      // Initialize day group if needed
      dailyGroups[dateKey] ??= <DateTime, double>{};

      // Add hourly data point (flow already converted to preferred unit)
      dailyGroups[dateKey]![localTime] = point.flow;
    }

    return dailyGroups;
  }

  /// UPDATED: Process a single day's hourly data into a DailyFlowForecast
  /// Now unit-aware for flow categorization
  static DailyFlowForecast? _processDailyData({
    required DateTime date,
    required Map<DateTime, double> hourlyData,
    required String dataSource,
    required ReachData reach,
    required String dataUnit, // NEW: Unit information
  }) {
    if (hourlyData.isEmpty) return null;

    // Calculate daily statistics (flow values already in correct unit)
    final flows = hourlyData.values.toList();
    final minFlow = flows.reduce((a, b) => a < b ? a : b);
    final maxFlow = flows.reduce((a, b) => a > b ? a : b);
    final avgFlow = flows.reduce((a, b) => a + b) / flows.length;

    // UPDATED: Use unit-aware flow category calculation
    // Use the maximum flow of the day for category determination (most conservative)
    final flowCategory = reach.hasReturnPeriods
        ? reach.getFlowCategory(maxFlow, dataUnit) // Now unit-aware!
        : 'Unknown';

    return DailyFlowForecast(
      date: date,
      minFlow: minFlow, // Already in correct unit
      maxFlow: maxFlow, // Already in correct unit
      avgFlow: avgFlow, // Already in correct unit
      hourlyData: Map.from(
        hourlyData,
      ), // Create a copy (already in correct unit)
      flowCategory: flowCategory,
      dataSource: dataSource,
    );
  }

  /// Validate processed data for debugging
  static bool validateProcessedData(List<DailyFlowForecast> forecasts) {
    if (forecasts.isEmpty) {
      print('DAILY_PROCESSOR: Warning - No forecasts generated');
      return false;
    }

    int validCount = 0;
    int invalidCount = 0;

    for (final forecast in forecasts) {
      if (forecast.isValid) {
        validCount++;
      } else {
        invalidCount++;
        print(
          'DAILY_PROCESSOR: Invalid forecast for ${forecast.date}: $forecast',
        );
      }
    }

    print(
      'DAILY_PROCESSOR: Validation complete - $validCount valid, $invalidCount invalid',
    );
    return invalidCount == 0;
  }

  /// UPDATED: Debug helper to print processing summary with dynamic units
  static void printProcessingSummary(List<DailyFlowForecast> forecasts) {
    if (forecasts.isEmpty) {
      print('DAILY_PROCESSOR: No forecasts to summarize');
      return;
    }

    // Get current unit for display
    final unitService = FlowUnitPreferenceService();
    final currentUnit = unitService.currentFlowUnit;

    print('DAILY_PROCESSOR: Processing Summary:');
    print(
      '  📅 Date range: ${forecasts.first.date.toIso8601String().split('T')[0]} to ${forecasts.last.date.toIso8601String().split('T')[0]}',
    );
    print('  📊 Total days: ${forecasts.length}');

    final dataSourceCounts = <String, int>{};
    final categoryCounts = <String, int>{};

    for (final forecast in forecasts) {
      dataSourceCounts[forecast.dataSource] =
          (dataSourceCounts[forecast.dataSource] ?? 0) + 1;
      categoryCounts[forecast.flowCategory] =
          (categoryCounts[forecast.flowCategory] ?? 0) + 1;
    }

    print('  📈 Data sources: $dataSourceCounts');
    print('  🎯 Flow categories: $categoryCounts');

    final bounds = getFlowBounds(forecasts);
    print(
      '  🌊 Flow range: ${bounds['min']?.toStringAsFixed(1)} - ${bounds['max']?.toStringAsFixed(1)} $currentUnit',
    );
  }
}
