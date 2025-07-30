// lib/core/models/reach_data.dart
class ReachData {
  // NOAA reach info
  final String reachId; // "23021904"
  final String riverName; // "Deep Creek" (from reaches API 'name' field)
  final double latitude;
  final double longitude;

  // Location context (from geocoding)
  final String? city; // "Spokane"
  final String? state; // "WA"

  // Available forecast types (from reaches API 'streamflow' array)
  final List<String>
  availableForecasts; // ["analysis_assimilation", "short_range", etc.]

  // Return periods (from separate return-period API - always in CMS)
  final Map<int, double>?
  returnPeriods; // {2: 3518.03, 5: 6119.41, 10: 7841.75}
  final String returnPeriodUnit = 'cms'; // Always CMS from API

  // Routing info (from reaches API)
  final List<String>? upstreamReaches; // ["23021906", "23023198"]
  final List<String>? downstreamReaches; // ["23022058"]

  // User customization
  final String?
  customName; // User can rename "Deep Creek" to "My Favorite Creek"

  // Cache metadata
  final DateTime cachedAt;
  final DateTime? lastApiUpdate;

  ReachData({
    required this.reachId,
    required this.riverName,
    required this.latitude,
    required this.longitude,
    this.city,
    this.state,
    required this.availableForecasts,
    this.returnPeriods,
    this.upstreamReaches,
    this.downstreamReaches,
    this.customName,
    required this.cachedAt,
    this.lastApiUpdate,
  });

  // Factory constructor from NOAA reaches API
  factory ReachData.fromNoaaApi(Map<String, dynamic> json) {
    try {
      final route = json['route'] as Map<String, dynamic>?;

      return ReachData(
        reachId: (json['reachId'] as String).trim(),
        riverName: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        availableForecasts: (json['streamflow'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        upstreamReaches: route?['upstream'] != null
            ? (route!['upstream'] as List<dynamic>)
                  .map((e) => (e as Map<String, dynamic>)['reachId'] as String)
                  .toList()
            : null,
        downstreamReaches: route?['downstream'] != null
            ? (route!['downstream'] as List<dynamic>)
                  .map((e) => (e as Map<String, dynamic>)['reachId'] as String)
                  .toList()
            : null,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Failed to parse NOAA reaches API response: $e');
    }
  }

  // Factory constructor from return period API (array response)
  factory ReachData.fromReturnPeriodApi(List<dynamic> jsonArray) {
    try {
      if (jsonArray.isEmpty) {
        throw FormatException('Return period API returned empty array');
      }

      final json = jsonArray.first as Map<String, dynamic>;
      final featureId = json['feature_id'].toString();

      final returnPeriods = <int, double>{};

      // Parse all available return periods
      for (final entry in json.entries) {
        if (entry.key.startsWith('return_period_')) {
          final years = int.tryParse(
            entry.key.substring('return_period_'.length),
          );
          final flow = (entry.value as num).toDouble();
          if (years != null) {
            returnPeriods[years] = flow;
          }
        }
      }

      return ReachData(
        reachId: featureId,
        riverName: 'Unknown', // Will be filled from reaches API
        latitude: 0.0, // Will be filled from reaches API
        longitude: 0.0, // Will be filled from reaches API
        availableForecasts: [],
        returnPeriods: returnPeriods,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Failed to parse return period API response: $e');
    }
  }

  // Factory constructor from cached JSON
  factory ReachData.fromJson(Map<String, dynamic> json) {
    return ReachData(
      reachId: json['reachId'] as String,
      riverName: json['riverName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String?,
      state: json['state'] as String?,
      availableForecasts: (json['availableForecasts'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      returnPeriods: json['returnPeriods'] != null
          ? Map<int, double>.from(
              (json['returnPeriods'] as Map<String, dynamic>).map(
                (key, value) =>
                    MapEntry(int.parse(key), (value as num).toDouble()),
              ),
            )
          : null,
      upstreamReaches: json['upstreamReaches'] != null
          ? (json['upstreamReaches'] as List<dynamic>)
                .map((e) => e.toString())
                .toList()
          : null,
      downstreamReaches: json['downstreamReaches'] != null
          ? (json['downstreamReaches'] as List<dynamic>)
                .map((e) => e.toString())
                .toList()
          : null,
      customName: json['customName'] as String?,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      lastApiUpdate: json['lastApiUpdate'] != null
          ? DateTime.parse(json['lastApiUpdate'] as String)
          : null,
    );
  }

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'reachId': reachId,
      'riverName': riverName,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'state': state,
      'availableForecasts': availableForecasts,
      'returnPeriods': returnPeriods?.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'upstreamReaches': upstreamReaches,
      'downstreamReaches': downstreamReaches,
      'customName': customName,
      'cachedAt': cachedAt.toIso8601String(),
      'lastApiUpdate': lastApiUpdate?.toIso8601String(),
    };
  }

  // Merge with data from another source (like return periods)
  ReachData mergeWith(ReachData other) {
    return ReachData(
      reachId: reachId,
      riverName: riverName.isNotEmpty ? riverName : other.riverName,
      latitude: latitude != 0.0 ? latitude : other.latitude,
      longitude: longitude != 0.0 ? longitude : other.longitude,
      city: city ?? other.city,
      state: state ?? other.state,
      availableForecasts: availableForecasts.isNotEmpty
          ? availableForecasts
          : other.availableForecasts,
      returnPeriods: returnPeriods ?? other.returnPeriods,
      upstreamReaches: upstreamReaches ?? other.upstreamReaches,
      downstreamReaches: downstreamReaches ?? other.downstreamReaches,
      customName: customName ?? other.customName,
      cachedAt: DateTime.now(),
      lastApiUpdate: other.lastApiUpdate ?? lastApiUpdate,
    );
  }

  // Update with user customizations
  ReachData copyWith({
    String? customName,
    String? city,
    String? state,
    DateTime? lastApiUpdate,
  }) {
    return ReachData(
      reachId: reachId,
      riverName: riverName,
      latitude: latitude,
      longitude: longitude,
      city: city ?? this.city,
      state: state ?? this.state,
      availableForecasts: availableForecasts,
      returnPeriods: returnPeriods,
      upstreamReaches: upstreamReaches,
      downstreamReaches: downstreamReaches,
      customName: customName ?? this.customName,
      cachedAt: cachedAt,
      lastApiUpdate: lastApiUpdate ?? this.lastApiUpdate,
    );
  }

  // Helper methods
  String get displayName => customName ?? riverName;
  bool get hasCustomName => customName != null && customName!.isNotEmpty;
  String get formattedLocation =>
      city != null && state != null ? '$city, $state' : '';

  bool get hasReturnPeriods =>
      returnPeriods != null && returnPeriods!.isNotEmpty;

  bool isCacheStale({Duration maxAge = const Duration(days: 30)}) {
    return DateTime.now().difference(cachedAt) > maxAge;
  }

  // Get flow category based on return periods (flow in CFS, return periods in CMS)
  String getFlowCategory(double flowCfs) {
    if (!hasReturnPeriods) return 'Unknown';

    // Convert CFS to CMS for comparison (1 CFS = 0.0283168 CMS)
    final flowCms = flowCfs * 0.0283168;

    final periods = returnPeriods!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final period in periods) {
      if (flowCms < period.value) {
        if (period.key == 2) return 'Normal';
        if (period.key <= 5) return 'Elevated';
        return 'High';
      }
    }

    return 'Flood Risk';
  }

  // Get next return period threshold
  MapEntry<int, double>? getNextThreshold(double flowCfs) {
    if (!hasReturnPeriods) return null;

    final flowCms = flowCfs * 0.0283168;
    final periods = returnPeriods!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final period in periods) {
      if (flowCms < period.value) {
        return period;
      }
    }

    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReachData &&
          runtimeType == other.runtimeType &&
          reachId == other.reachId;

  @override
  int get hashCode => reachId.hashCode;

  @override
  String toString() {
    return 'ReachData{reachId: $reachId, displayName: $displayName, location: $formattedLocation, hasReturnPeriods: $hasReturnPeriods}';
  }
}

// lib/core/models/forecast_data.dart
class ForecastPoint {
  final DateTime validTime;
  final double flow;

  ForecastPoint({required this.validTime, required this.flow});

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      validTime: DateTime.parse(json['validTime'] as String),
      flow: (json['flow'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'validTime': validTime.toIso8601String(), 'flow': flow};
  }

  @override
  String toString() => 'ForecastPoint{validTime: $validTime, flow: $flow}';
}

class ForecastSeries {
  final DateTime? referenceTime;
  final String units;
  final List<ForecastPoint> data;

  ForecastSeries({this.referenceTime, required this.units, required this.data});

  factory ForecastSeries.fromJson(Map<String, dynamic> json) {
    return ForecastSeries(
      referenceTime: json['referenceTime'] != null
          ? DateTime.parse(json['referenceTime'] as String)
          : null,
      units: json['units'] as String? ?? '',
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
                .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referenceTime': referenceTime?.toIso8601String(),
      'units': units,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }

  bool get isEmpty => data.isEmpty;
  bool get isNotEmpty => data.isNotEmpty;

  // Get flow at specific time (or closest)
  double? getFlowAt(DateTime time) {
    if (data.isEmpty) return null;

    ForecastPoint? closest;
    Duration? minDiff;

    for (final point in data) {
      final diff = point.validTime.difference(time).abs();
      if (minDiff == null || diff < minDiff) {
        minDiff = diff;
        closest = point;
      }
    }

    return closest?.flow;
  }

  @override
  String toString() =>
      'ForecastSeries{referenceTime: $referenceTime, units: $units, points: ${data.length}}';
}

class ForecastResponse {
  final ReachData reach;
  final ForecastSeries? analysisAssimilation;
  final ForecastSeries? shortRange;
  final Map<String, ForecastSeries> mediumRange; // mean, member1, member2, etc.
  final Map<String, ForecastSeries> longRange; // mean, member1, member2, etc.
  final ForecastSeries? mediumRangeBlend;

  ForecastResponse({
    required this.reach,
    this.analysisAssimilation,
    this.shortRange,
    required this.mediumRange,
    required this.longRange,
    this.mediumRangeBlend,
  });

  factory ForecastResponse.fromJson(Map<String, dynamic> json) {
    return ForecastResponse(
      reach: ReachData.fromNoaaApi(json['reach'] as Map<String, dynamic>),
      analysisAssimilation: _parseForecastSection(json['analysisAssimilation']),
      shortRange: _parseForecastSection(json['shortRange']),
      mediumRange: _parseEnsembleForecast(json['mediumRange']),
      longRange: _parseEnsembleForecast(json['longRange']),
      mediumRangeBlend: _parseForecastSection(json['mediumRangeBlend']),
    );
  }

  static ForecastSeries? _parseForecastSection(dynamic section) {
    if (section == null || section is! Map<String, dynamic>) return null;

    final series = section['series'];
    if (series == null || series is! Map<String, dynamic>) return null;

    return ForecastSeries.fromJson(series);
  }

  static Map<String, ForecastSeries> _parseEnsembleForecast(dynamic section) {
    if (section == null || section is! Map<String, dynamic>) return {};

    final result = <String, ForecastSeries>{};

    for (final entry in section.entries) {
      if (entry.value is Map<String, dynamic>) {
        try {
          result[entry.key] = ForecastSeries.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } catch (e) {
          // Skip invalid forecast members
          continue;
        }
      }
    }

    return result;
  }

  // Get the primary forecast series for a given type
  ForecastSeries? getPrimaryForecast(String forecastType) {
    switch (forecastType.toLowerCase()) {
      case 'analysis_assimilation':
        return analysisAssimilation;
      case 'short_range':
        return shortRange;
      case 'medium_range':
        return mediumRange['mean'];
      case 'long_range':
        return longRange['mean'];
      case 'medium_range_blend':
        return mediumRangeBlend;
      default:
        return null;
    }
  }

  // Get all ensemble members for medium/long range
  List<ForecastSeries> getEnsembleMembers(String forecastType) {
    final ensemble = forecastType.toLowerCase() == 'medium_range'
        ? mediumRange
        : longRange;

    return ensemble.entries
        .where((e) => e.key.startsWith('member'))
        .map((e) => e.value)
        .toList();
  }

  @override
  String toString() {
    return 'ForecastResponse{reach: ${reach.displayName}, forecasts: ${_availableForecasts()}}';
  }

  List<String> _availableForecasts() {
    final available = <String>[];
    if (analysisAssimilation?.isNotEmpty == true)
      available.add('analysis_assimilation');
    if (shortRange?.isNotEmpty == true) available.add('short_range');
    if (mediumRange.isNotEmpty) available.add('medium_range');
    if (longRange.isNotEmpty) available.add('long_range');
    if (mediumRangeBlend?.isNotEmpty == true)
      available.add('medium_range_blend');
    return available;
  }
}
