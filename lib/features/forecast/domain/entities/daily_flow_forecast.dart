// lib/features/forecast/domain/entities/daily_flow_forecast.dart

import 'package:flutter/cupertino.dart';

/// Represents a single day's flow forecast data processed from ensemble forecasts
///
/// This model aggregates hourly ensemble data (primarily from 'mean', with fallback
/// to first available member) into daily summaries suitable for display in
/// expandable daily forecast widgets.
class DailyFlowForecast {
  /// The date this forecast represents (local date, time component ignored)
  final DateTime date;

  /// Minimum flow value for this day (CFS)
  final double minFlow;

  /// Maximum flow value for this day (CFS)
  final double maxFlow;

  /// Average flow value for this day (CFS)
  final double avgFlow;

  /// Hourly flow data for this day
  /// Key: DateTime (hour-level precision)
  /// Value: Flow in CFS
  final Map<DateTime, double> hourlyData;

  /// Flow category based on return period thresholds
  /// Values: 'Normal', 'Elevated', 'High', 'Flood Risk', 'Unknown'
  final String flowCategory;

  /// Data source identifier for debugging/display purposes
  /// Examples: 'mean', 'member01', 'member02', etc.
  final String dataSource;

  /// Optional: Confidence/uncertainty indicators could be added later
  /// final double? confidenceLevel;
  /// final double? uncertainty;

  const DailyFlowForecast({
    required this.date,
    required this.minFlow,
    required this.maxFlow,
    required this.avgFlow,
    required this.hourlyData,
    required this.flowCategory,
    required this.dataSource,
  });

  /// Creates a copy with updated values
  DailyFlowForecast copyWith({
    DateTime? date,
    double? minFlow,
    double? maxFlow,
    double? avgFlow,
    Map<DateTime, double>? hourlyData,
    String? flowCategory,
    String? dataSource,
  }) {
    return DailyFlowForecast(
      date: date ?? this.date,
      minFlow: minFlow ?? this.minFlow,
      maxFlow: maxFlow ?? this.maxFlow,
      avgFlow: avgFlow ?? this.avgFlow,
      hourlyData: hourlyData ?? this.hourlyData,
      flowCategory: flowCategory ?? this.flowCategory,
      dataSource: dataSource ?? this.dataSource,
    );
  }

  /// Get the color associated with this day's flow category
  /// Uses rivrflow's standard Cupertino color scheme
  Color get categoryColor {
    switch (flowCategory.toLowerCase()) {
      case 'normal':
        return CupertinoColors.systemBlue;
      case 'elevated':
        return CupertinoColors.systemGreen;
      case 'high':
        return CupertinoColors.systemOrange;
      case 'flood risk':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  /// Get appropriate icon for this day's flow category
  /// Uses rivrflow's standard Cupertino icons
  IconData get categoryIcon {
    switch (flowCategory.toLowerCase()) {
      case 'normal':
        return CupertinoIcons.checkmark_circle_fill;
      case 'elevated':
        return CupertinoIcons.arrow_up_circle;
      case 'high':
        return CupertinoIcons.arrow_up_circle_fill;
      case 'flood risk':
        return CupertinoIcons.exclamationmark_triangle_fill;
      default:
        return CupertinoIcons.question_circle;
    }
  }

  /// Check if this forecast has hourly data available
  bool get hasHourlyData => hourlyData.isNotEmpty;

  /// Get the number of hours of data available
  int get hourlyDataCount => hourlyData.length;

  /// Get flow at a specific hour (or closest available)
  double? getFlowAt(DateTime targetTime) {
    if (hourlyData.isEmpty) return null;

    // Try exact match first
    final exactMatch = hourlyData[targetTime];
    if (exactMatch != null) return exactMatch;

    // Find closest hour
    DateTime? closestTime;
    Duration? minDifference;

    for (final dataTime in hourlyData.keys) {
      final difference = dataTime.difference(targetTime).abs();
      if (minDifference == null || difference < minDifference) {
        minDifference = difference;
        closestTime = dataTime;
      }
    }

    return closestTime != null ? hourlyData[closestTime] : null;
  }

  /// Get sorted list of hourly data entries for easy iteration
  List<MapEntry<DateTime, double>> get sortedHourlyData {
    final entries = hourlyData.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Check if this is using ensemble mean data (preferred) or fallback member
  bool get isUsingMeanData => dataSource == 'mean';

  /// Get a user-friendly description of the data source
  String get dataSourceDescription {
    if (dataSource == 'mean') {
      return 'Ensemble Average';
    } else if (dataSource.startsWith('member')) {
      final memberNumber = dataSource.substring(6); // Remove 'member' prefix
      return 'Member $memberNumber';
    } else {
      return 'Unknown Source';
    }
  }

  /// Validation method to ensure data integrity
  bool get isValid {
    return minFlow >= 0 &&
        maxFlow >= minFlow &&
        avgFlow >= minFlow &&
        avgFlow <= maxFlow &&
        flowCategory.isNotEmpty &&
        dataSource.isNotEmpty;
  }

  @override
  String toString() {
    return 'DailyFlowForecast{date: ${date.toIso8601String().split('T')[0]}, '
        'flows: $minFlow-$maxFlow (avg: $avgFlow), '
        'category: $flowCategory, '
        'source: $dataSource, '
        'hourlyPoints: ${hourlyData.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyFlowForecast &&
        other.date == date &&
        other.minFlow == minFlow &&
        other.maxFlow == maxFlow &&
        other.avgFlow == avgFlow &&
        other.flowCategory == flowCategory &&
        other.dataSource == dataSource;
  }

  @override
  int get hashCode {
    return Object.hash(
      date,
      minFlow,
      maxFlow,
      avgFlow,
      flowCategory,
      dataSource,
    );
  }
}

/// Collection of daily flow forecasts for a complete forecast period
///
/// Provides convenient methods for working with multiple days of forecast data
class DailyForecastCollection {
  final List<DailyFlowForecast> forecasts;
  final DateTime createdAt;
  final String sourceType; // 'medium_range', 'long_range', etc.

  const DailyForecastCollection({
    required this.forecasts,
    required this.createdAt,
    required this.sourceType,
  });

  /// Get forecast for a specific date
  DailyFlowForecast? getForecastForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return forecasts.where((f) {
      final forecastDate = DateTime(f.date.year, f.date.month, f.date.day);
      return forecastDate == targetDate;
    }).firstOrNull;
  }

  /// Get all forecasts sorted by date
  List<DailyFlowForecast> get sortedForecasts {
    final sorted = List<DailyFlowForecast>.from(forecasts);
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  /// Get overall flow bounds for the entire collection (useful for scaling)
  Map<String, double> get flowBounds {
    if (forecasts.isEmpty) return {'min': 0.0, 'max': 100.0};

    double min = forecasts.first.minFlow;
    double max = forecasts.first.maxFlow;

    for (final forecast in forecasts) {
      if (forecast.minFlow < min) min = forecast.minFlow;
      if (forecast.maxFlow > max) max = forecast.maxFlow;
    }

    return {'min': min, 'max': max};
  }

  /// Check if collection is empty
  bool get isEmpty => forecasts.isEmpty;

  /// Check if collection has data
  bool get isNotEmpty => forecasts.isNotEmpty;

  /// Get the number of days in the forecast
  int get length => forecasts.length;

  /// Get date range covered by this collection
  Map<String, DateTime>? get dateRange {
    if (forecasts.isEmpty) return null;

    final sorted = sortedForecasts;
    return {'start': sorted.first.date, 'end': sorted.last.date};
  }

  @override
  String toString() {
    return 'DailyForecastCollection{type: $sourceType, days: ${forecasts.length}, '
        'created: ${createdAt.toIso8601String()}}';
  }
}
