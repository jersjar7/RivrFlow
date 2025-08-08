// lib/core/providers/reach_data_provider.dart

import 'package:flutter/foundation.dart';
import 'package:rivrflow/features/forecast/widgets/horizontal_flow_timeline.dart';
import '../models/reach_data.dart';
import '../services/forecast_service.dart';

/// State management for reach and forecast data
/// Now with phased loading and computed value caching for better performance
class ReachDataProvider with ChangeNotifier {
  final ForecastService _forecastService = ForecastService();

  // Current state
  bool _isLoading = false;
  String? _errorMessage;
  ForecastResponse? _currentForecast;

  // Phased loading states
  bool _isLoadingOverview = false;
  bool _isLoadingSupplementary = false;
  String _loadingPhase =
      'none'; // 'none', 'overview', 'supplementary', 'complete'

  // Simple in-memory cache for current session
  final Map<String, ForecastResponse> _sessionCache = {};

  // Computed value caches (avoid repeated calculations)
  final Map<String, double?> _currentFlowCache = {};
  final Map<String, String> _flowCategoryCache = {};
  final Map<String, String> _formattedLocationCache = {};
  final Map<String, List<String>> _availableForecastTypesCache = {};

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingOverview => _isLoadingOverview; // NEW
  bool get isLoadingSupplementary => _isLoadingSupplementary; // NEW
  String get loadingPhase => _loadingPhase; // NEW
  String? get errorMessage => _errorMessage;
  ForecastResponse? get currentForecast => _currentForecast;
  bool get hasData => _currentForecast != null;

  // Get current reach data if available
  ReachData? get currentReach => _currentForecast?.reach;

  // Check if we have basic overview data
  bool get hasOverviewData =>
      _currentForecast != null && _currentForecast!.reach.hasLocationData;

  // Check if we have supplementary data (return periods)
  bool get hasSupplementaryData =>
      _currentForecast?.reach.hasReturnPeriods ?? false;

  // PHASE 1 - Load overview data only (reach info + current flow)
  /// Load minimal data for overview page display
  /// This is the fastest possible load - shows name, location, current flow immediately
  Future<bool> loadOverviewData(String reachId) async {
    print('REACH_PROVIDER: Loading overview data for reach: $reachId');

    _setLoadingOverview(true);
    _setLoadingPhase('overview');
    _clearError();

    try {
      // Check session cache first
      if (_sessionCache.containsKey(reachId)) {
        print('REACH_PROVIDER: Using cached data for overview: $reachId');
        _currentForecast = _sessionCache[reachId];
        _updateComputedCaches(reachId);
        _setLoadingOverview(false);
        _setLoadingPhase('complete'); // If cached, we have complete data
        return true;
      }

      // Load overview data from service (fast)
      final forecast = await _forecastService.loadOverviewData(reachId);

      _currentForecast = forecast;
      _updateComputedCaches(reachId);

      print(
        'REACH_PROVIDER: ✅ Overview data loaded: ${forecast.reach.displayName}',
      );
      _setLoadingOverview(false);
      _setLoadingPhase('overview');
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ❌ Error loading overview data: $e');
      _setError(e.toString());
      _setLoadingOverview(false);
      _setLoadingPhase('none');
      return false;
    }
  }

  // PHASE 2 - Add supplementary data (return periods + forecast summaries)
  /// Enhance existing overview data with return periods and forecast summaries
  /// Call this after overview data is displayed to add functionality progressively
  Future<bool> loadSupplementaryData(String reachId) async {
    if (_currentForecast == null) {
      print(
        'REACH_PROVIDER: No overview data to enhance, loading overview first',
      );
      final success = await loadOverviewData(reachId);
      if (!success) return false;
    }

    print('REACH_PROVIDER: Loading supplementary data for reach: $reachId');

    _setLoadingSupplementary(true);
    _clearError();

    try {
      // Enhance existing data with supplementary information
      final enhancedForecast = await _forecastService.loadSupplementaryData(
        reachId,
        _currentForecast!,
      );

      // Only update if we actually got enhanced data
      final hadReturnPeriods = _currentForecast!.reach.hasReturnPeriods;
      final hasReturnPeriodsNow = enhancedForecast.reach.hasReturnPeriods;

      _currentForecast = enhancedForecast;
      _sessionCache[reachId] = enhancedForecast; // Update cache

      // Update computed caches
      _updateComputedCaches(reachId);

      // Only notify if we actually got new useful data
      if (!hadReturnPeriods && hasReturnPeriodsNow) {
        print('REACH_PROVIDER: ✅ Added return period data for flow categories');
      } else {
        print(
          'REACH_PROVIDER: ✅ Supplementary data loaded (no new return periods)',
        );
      }

      _setLoadingSupplementary(false);
      _setLoadingPhase('complete');
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ⚠️ Error loading supplementary data: $e');
      // Don't set error - supplementary data is not critical
      // Keep existing overview data
      _setLoadingSupplementary(false);
      _setLoadingPhase('overview'); // Still have overview data
      return false; // Indicate supplementary loading failed, but don't break UI
    }
  }

  // Keep for backwards compatibility and complete loading
  /// Load complete reach and forecast data
  Future<bool> loadReach(String reachId) async {
    print('REACH_PROVIDER: Loading complete reach data: $reachId');

    _setLoading(true);
    _setLoadingPhase('complete');
    _clearError();

    try {
      // Check session cache first
      if (_sessionCache.containsKey(reachId)) {
        print('REACH_PROVIDER: Using session cache for: $reachId');
        _currentForecast = _sessionCache[reachId];
        _updateComputedCaches(reachId);
        _setLoading(false);
        _setLoadingPhase('complete');
        return true;
      }

      // Load from service (uses disk cache automatically)
      final forecast = await _forecastService.loadCompleteReachData(reachId);

      _currentForecast = forecast;
      _sessionCache[reachId] = forecast; // Cache for session
      _updateComputedCaches(reachId);

      print(
        'REACH_PROVIDER: ✅ Complete data loaded: ${forecast.reach.displayName}',
      );
      _setLoading(false);
      _setLoadingPhase('complete');
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ❌ Error loading complete data: $e');
      _setError(e.toString());
      _setLoading(false);
      _setLoadingPhase('none');
      return false;
    }
  }

  /// Load specific forecast type only (faster)
  Future<bool> loadSpecificForecast(String reachId, String forecastType) async {
    print('REACH_PROVIDER: Loading $forecastType for reach: $reachId');

    _setLoading(true);
    _clearError();

    try {
      final forecast = await _forecastService.loadSpecificForecast(
        reachId,
        forecastType,
      );

      _currentForecast = forecast;
      _sessionCache[reachId] = forecast;
      _updateComputedCaches(reachId);

      print('REACH_PROVIDER: ✅ Successfully loaded $forecastType');
      _setLoading(false);
      _setLoadingPhase('specific');
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ❌ Error loading $forecastType: $e');
      _setError(e.toString());
      _setLoading(false);
      _setLoadingPhase('none');
      return false;
    }
  }

  /// Force refresh current reach (bypass all caches)
  Future<bool> refreshCurrentReach() async {
    if (_currentForecast == null) return false;

    final reachId = _currentForecast!.reach.reachId;
    print('REACH_PROVIDER: Force refreshing: $reachId');

    // Clear all caches
    _sessionCache.remove(reachId);
    _clearComputedCaches(reachId);
    _forecastService.clearComputedCaches();

    return await loadReach(reachId);
  }

  // Use cached values instead of computing each time
  /// Get current flow value for display - now with caching
  double? getCurrentFlow({String? preferredType}) {
    if (_currentForecast == null) return null;

    final reachId = _currentForecast!.reach.reachId;
    final cacheKey = '$reachId-${preferredType ?? 'default'}';

    // Return cached value if available
    if (_currentFlowCache.containsKey(cacheKey)) {
      return _currentFlowCache[cacheKey];
    }

    // Compute and cache
    final flow = _forecastService.getCurrentFlow(
      _currentForecast!,
      preferredType: preferredType,
    );
    _currentFlowCache[cacheKey] = flow;
    return flow;
  }

  // Use cached values instead of computing each time
  /// Get flow category - now with caching
  String getFlowCategory({String? preferredType}) {
    if (_currentForecast == null) return 'Unknown';

    final reachId = _currentForecast!.reach.reachId;
    final cacheKey = '$reachId-${preferredType ?? 'default'}';

    // Return cached value if available
    if (_flowCategoryCache.containsKey(cacheKey)) {
      return _flowCategoryCache[cacheKey]!;
    }

    // Compute and cache
    final category = _forecastService.getFlowCategory(
      _currentForecast!,
      preferredType: preferredType,
    );
    _flowCategoryCache[cacheKey] = category;
    return category;
  }

  // Cached formatted location (fixes subtitle issue)
  /// Get formatted location for display - cached to avoid repeated computation
  String getFormattedLocation() {
    if (_currentForecast == null) return '';

    final reachId = _currentForecast!.reach.reachId;

    // Return cached value if available
    if (_formattedLocationCache.containsKey(reachId)) {
      return _formattedLocationCache[reachId]!;
    }

    // Compute and cache - use the improved subtitle formatter
    final location = _currentForecast!.reach.formattedLocationSubtitle;
    _formattedLocationCache[reachId] = location;
    return location;
  }

  // Use cached values
  /// Get available forecast types - now with caching
  List<String> getAvailableForecastTypes() {
    if (_currentForecast == null) return [];

    final reachId = _currentForecast!.reach.reachId;

    // Return cached value if available
    if (_availableForecastTypesCache.containsKey(reachId)) {
      return _availableForecastTypesCache[reachId]!;
    }

    // Compute and cache
    final types = _forecastService.getAvailableForecastTypes(_currentForecast!);
    _availableForecastTypesCache[reachId] = types;
    return types;
  }

  /// Check if current reach has ensemble data
  bool hasEnsembleData() {
    if (_currentForecast == null) return false;
    return _forecastService.hasEnsembleData(_currentForecast!);
  }

  /// Clear current data
  void clear() {
    _currentForecast = null;
    _sessionCache.clear();
    _clearAllComputedCaches();
    _clearError();
    _setLoadingPhase('none');
    notifyListeners();
    print('REACH_PROVIDER: Cleared all data');
  }

  /// Clear error message
  void clearError() {
    _clearError();
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    final diskStats = await _forecastService.getCacheStats();
    return {
      'sessionCached': _sessionCache.length,
      'sessionReaches': _sessionCache.keys.toList(),
      'diskCache': diskStats,
      'computedCaches': {
        'currentFlow': _currentFlowCache.length,
        'flowCategory': _flowCategoryCache.length,
        'formattedLocation': _formattedLocationCache.length,
        'availableForecastTypes': _availableForecastTypesCache.length,
      },
    };
  }

  /// Get hourly data for short-range forecast with calculated trends
  List<HourlyFlowDataPoint> getShortRangeHourlyData() {
    if (_currentForecast == null) return [];
    return _forecastService.getShortRangeHourlyData(_currentForecast!);
  }

  /// Get ALL hourly data for charts (including past hours)
  List<HourlyFlowDataPoint> getAllShortRangeHourlyData() {
    if (_currentForecast == null) return [];
    return _forecastService.getAllShortRangeHourlyData(_currentForecast!);
  }

  // Update all computed caches when data changes
  void _updateComputedCaches(String reachId) {
    if (_currentForecast == null) return;

    // Pre-compute commonly used values
    getCurrentFlow(); // This will cache the result
    getFlowCategory(); // This will cache the result
    getFormattedLocation(); // This will cache the result
    getAvailableForecastTypes(); // This will cache the result

    print('REACH_PROVIDER: Updated computed caches for: $reachId');
  }

  // Clear computed caches for specific reach
  void _clearComputedCaches(String reachId) {
    _currentFlowCache.removeWhere((key, value) => key.startsWith(reachId));
    _flowCategoryCache.removeWhere((key, value) => key.startsWith(reachId));
    _formattedLocationCache.remove(reachId);
    _availableForecastTypesCache.remove(reachId);
  }

  // Clear all computed caches
  void _clearAllComputedCaches() {
    _currentFlowCache.clear();
    _flowCategoryCache.clear();
    _formattedLocationCache.clear();
    _availableForecastTypesCache.clear();
  }

  // Helper methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Selective loading state setters
  void _setLoadingOverview(bool loading) {
    if (_isLoadingOverview != loading) {
      _isLoadingOverview = loading;
      notifyListeners();
    }
  }

  void _setLoadingSupplementary(bool loading) {
    if (_isLoadingSupplementary != loading) {
      _isLoadingSupplementary = loading;
      notifyListeners();
    }
  }

  void _setLoadingPhase(String phase) {
    if (_loadingPhase != phase) {
      _loadingPhase = phase;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
