// lib/core/constants.dart
//
// App-wide constants and helper methods that are not sensitive information
// like API keys and URLs. For sensitive configuration, see config.dart.
//

import 'package:flutter/cupertino.dart';

class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  /// Get stream order color for consistent styling
  static Color getStreamOrderColor(int streamOrder) {
    if (streamOrder >= 8) return CupertinoColors.systemIndigo;
    if (streamOrder >= 5) return CupertinoColors.systemBlue;
    if (streamOrder >= 3) return CupertinoColors.systemTeal;
    return CupertinoColors.systemGreen;
  }

  /// Get stream order icon for consistent iconography
  static IconData getStreamOrderIcon(int streamOrder) {
    if (streamOrder >= 8) return CupertinoIcons.drop_fill;
    if (streamOrder >= 5) return CupertinoIcons.drop;
    return CupertinoIcons.minus_circled;
  }

  /// Get flow category color for consistent styling
  static Color getFlowCategoryColor(String? flowCategory) {
    switch (flowCategory?.toLowerCase()) {
      case 'flood risk':
        return CupertinoColors.systemRed;
      case 'high':
        return CupertinoColors.systemOrange;
      case 'elevated':
        return CupertinoColors.systemYellow;
      case 'normal':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  /// Get flow category icon for consistent iconography
  static IconData getFlowCategoryIcon(String? flowCategory) {
    switch (flowCategory?.toLowerCase()) {
      case 'flood risk':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'high':
        return CupertinoIcons.arrow_up_circle_fill;
      case 'elevated':
        return CupertinoIcons.arrow_up_circle;
      case 'normal':
        return CupertinoIcons.checkmark_circle_fill;
      default:
        return CupertinoIcons.question_circle;
    }
  }
}
