// lib/core/services/flow_unit_preference_service.dart

/// Simple service for managing flow unit preferences and conversions
/// Handles the global flow unit setting and provides conversion utilities
class FlowUnitPreferenceService {
  static final FlowUnitPreferenceService _instance =
      FlowUnitPreferenceService._internal();
  factory FlowUnitPreferenceService() => _instance;
  FlowUnitPreferenceService._internal();

  // Current flow unit preference
  String _currentFlowUnit = 'CFS'; // Default to CFS

  // Conversion constants
  static const double _cmsToCs = 35.3147; // 1 CMS = 35.3147 CFS
  static const double _csToCs = 1.0 / _cmsToCs; // 1 CFS = 0.0283168 CMS

  /// Get the current flow unit preference
  String get currentFlowUnit => _currentFlowUnit;

  /// Set the current flow unit preference
  void setFlowUnit(String unit) {
    if (unit == 'CFS' || unit == 'CMS') {
      _currentFlowUnit = unit;
      print('FLOW_UNIT_SERVICE: Flow unit changed to: $unit');
    } else {
      print('FLOW_UNIT_SERVICE: Invalid unit: $unit. Using CFS as default.');
      _currentFlowUnit = 'CFS';
    }
  }

  /// Convert flow value between units
  double convertFlow(double value, String fromUnit, String toUnit) {
    // No conversion needed if units are the same
    if (fromUnit == toUnit) return value;

    // Convert CMS to CFS
    if (fromUnit == 'CMS' && toUnit == 'CFS') {
      return value * _cmsToCs;
    }

    // Convert CFS to CMS
    if (fromUnit == 'CFS' && toUnit == 'CMS') {
      return value * _csToCs;
    }

    // Fallback - return original value if unknown units
    print('FLOW_UNIT_SERVICE: Unknown unit conversion: $fromUnit to $toUnit');
    return value;
  }

  /// Convert flow value to the current preferred unit
  double convertToPreferredUnit(double value, String fromUnit) {
    return convertFlow(value, fromUnit, _currentFlowUnit);
  }

  /// Convert flow value from the current preferred unit to target unit
  double convertFromPreferredUnit(double value, String toUnit) {
    return convertFlow(value, _currentFlowUnit, toUnit);
  }

  /// Get display unit for UI elements
  String getDisplayUnit() => _currentFlowUnit;

  /// Check if current unit is CFS
  bool get isCFS => _currentFlowUnit == 'CFS';

  /// Check if current unit is CMS
  bool get isCMS => _currentFlowUnit == 'CMS';

  /// Reset to default (CFS)
  void resetToDefault() {
    setFlowUnit('CFS');
  }
}
