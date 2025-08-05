// lib/core/providers/reach_data_provider.dart

import 'package:flutter/foundation.dart';
import '../models/reach_data.dart';
import '../services/forecast_service.dart';

/// Simple state management for reach and forecast data
/// Wraps ForecastService with reactive UI updates
class ReachDataProvider with ChangeNotifier {
  final ForecastService _forecastService = ForecastService();

  // Current state
  bool _isLoading = false;
  String? _errorMessage;
  ForecastResponse? _currentForecast;

  // Simple in-memory cache for current session
  final Map<String, ForecastResponse> _sessionCache = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ForecastResponse? get currentForecast => _currentForecast;
  bool get hasData => _currentForecast != null;

  // Get current reach data if available
  ReachData? get currentReach => _currentForecast?.reach;

  /// Load complete reach and forecast data
  Future<bool> loadReach(String reachId) async {
    print('REACH_PROVIDER: Loading reach: $reachId');

    _setLoading(true);
    _clearError();

    try {
      // Check session cache first
      if (_sessionCache.containsKey(reachId)) {
        print('REACH_PROVIDER: Using session cache for: $reachId');
        _currentForecast = _sessionCache[reachId];
        _setLoading(false);
        return true;
      }

      // Load from service (uses disk cache automatically)
      final forecast = await _forecastService.loadCompleteReachData(reachId);

      _currentForecast = forecast;
      _sessionCache[reachId] = forecast; // Cache for session

      print(
        'REACH_PROVIDER: ✅ Successfully loaded: ${forecast.reach.displayName}',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ❌ Error loading reach: $e');
      _setError(e.toString());
      _setLoading(false);
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

      print('REACH_PROVIDER: ✅ Successfully loaded $forecastType');
      _setLoading(false);
      return true;
    } catch (e) {
      print('REACH_PROVIDER: ❌ Error loading $forecastType: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Force refresh current reach (bypass all caches)
  Future<bool> refreshCurrentReach() async {
    if (_currentForecast == null) return false;

    final reachId = _currentForecast!.reach.reachId;
    print('REACH_PROVIDER: Force refreshing: $reachId');

    // Clear caches
    _sessionCache.remove(reachId);

    return await loadReach(reachId);
  }

  /// Get current flow value for display
  double? getCurrentFlow({String? preferredType}) {
    if (_currentForecast == null) return null;
    return _forecastService.getCurrentFlow(
      _currentForecast!,
      preferredType: preferredType,
    );
  }

  /// Get flow category
  String getFlowCategory({String? preferredType}) {
    if (_currentForecast == null) return 'Unknown';
    return _forecastService.getFlowCategory(
      _currentForecast!,
      preferredType: preferredType,
    );
  }

  /// Get available forecast types
  List<String> getAvailableForecastTypes() {
    if (_currentForecast == null) return [];
    return _forecastService.getAvailableForecastTypes(_currentForecast!);
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
    _clearError();
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
    };
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
