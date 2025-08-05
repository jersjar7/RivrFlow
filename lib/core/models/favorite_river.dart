// lib/core/models/favorite_river.dart

/// Simple model for storing user's favorite rivers
/// Designed for JSON serialization with SharedPreferences
class FavoriteRiver {
  final String reachId; // Links to existing ReachData
  final String? customName; // User override for display name
  final String? riverName; // NOAA river name (cached from API)
  final String?
  customImageAsset; // Asset path like 'assets/images/rivers/mountain/river1.webp'
  final int displayOrder; // For user reordering (0 = first)
  final double? lastKnownFlow; // Cached flow value for offline display
  final DateTime? lastUpdated; // When flow was last refreshed

  const FavoriteRiver({
    required this.reachId,
    this.customName,
    this.riverName,
    this.customImageAsset,
    required this.displayOrder,
    this.lastKnownFlow,
    this.lastUpdated,
  });

  /// Create from JSON (for SharedPreferences loading)
  factory FavoriteRiver.fromJson(Map<String, dynamic> json) {
    return FavoriteRiver(
      reachId: json['reachId'] as String,
      customName: json['customName'] as String?,
      riverName: json['riverName'] as String?,
      customImageAsset: json['customImageAsset'] as String?,
      displayOrder: json['displayOrder'] as int,
      lastKnownFlow: json['lastKnownFlow'] as double?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  /// Convert to JSON (for SharedPreferences storage)
  Map<String, dynamic> toJson() {
    return {
      'reachId': reachId,
      'customName': customName,
      'riverName': riverName,
      'customImageAsset': customImageAsset,
      'displayOrder': displayOrder,
      'lastKnownFlow': lastKnownFlow,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  FavoriteRiver copyWith({
    String? reachId,
    String? customName,
    String? riverName,
    String? customImageAsset,
    int? displayOrder,
    double? lastKnownFlow,
    DateTime? lastUpdated,
  }) {
    return FavoriteRiver(
      reachId: reachId ?? this.reachId,
      customName: customName ?? this.customName,
      riverName: riverName ?? this.riverName,
      customImageAsset: customImageAsset ?? this.customImageAsset,
      displayOrder: displayOrder ?? this.displayOrder,
      lastKnownFlow: lastKnownFlow ?? this.lastKnownFlow,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get display name with enhanced priority logic:
  /// 1. Custom name (if user renamed it)
  /// 2. NOAA river name (from API)
  /// 3. Fallback to station ID
  String get displayName {
    // 1. Custom name (highest priority)
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    // 2. NOAA river name
    if (riverName != null && riverName!.isNotEmpty) {
      return riverName!;
    }
    // 3. Fallback to station ID
    return 'Station $reachId';
  }

  /// Check if flow data is stale (older than 2 hours)
  bool get isFlowDataStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!).inHours > 2;
  }

  /// Get formatted flow display
  String get formattedFlow {
    if (lastKnownFlow == null) return 'No data';
    return '${lastKnownFlow!.toStringAsFixed(0)} CFS';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteRiver && other.reachId == reachId;
  }

  @override
  int get hashCode => reachId.hashCode;

  @override
  String toString() {
    return 'FavoriteRiver{reachId: $reachId, customName: $customName, riverName: $riverName, displayOrder: $displayOrder}';
  }
}
