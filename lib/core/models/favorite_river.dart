// lib/core/models/favorite_river.dart

/// Simple model for storing user's favorite rivers
/// Designed for JSON serialization with SharedPreferences
class FavoriteRiver {
  final String reachId; // Links to existing ReachData
  final String? customName; // User override for display name
  final String?
  customImageAsset; // Asset path like 'assets/images/rivers/mountain/river1.webp'
  final int displayOrder; // For user reordering (0 = first)
  final double? lastKnownFlow; // Cached flow value for offline display
  final DateTime? lastUpdated; // When flow was last refreshed

  const FavoriteRiver({
    required this.reachId,
    this.customName,
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
    String? customImageAsset,
    int? displayOrder,
    double? lastKnownFlow,
    DateTime? lastUpdated,
  }) {
    return FavoriteRiver(
      reachId: reachId ?? this.reachId,
      customName: customName ?? this.customName,
      customImageAsset: customImageAsset ?? this.customImageAsset,
      displayOrder: displayOrder ?? this.displayOrder,
      lastKnownFlow: lastKnownFlow ?? this.lastKnownFlow,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get display name (custom name or fallback to reach ID)
  String get displayName => customName ?? 'Reach $reachId';

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
    return 'FavoriteRiver{reachId: $reachId, customName: $customName, displayOrder: $displayOrder}';
  }
}
