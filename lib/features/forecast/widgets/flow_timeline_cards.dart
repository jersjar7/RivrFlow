// lib/features/forecast/widgets/flow_timeline_cards.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';

class FlowTimelineCards extends StatelessWidget {
  final String forecastType;
  final String timeFrame;
  final String reachId;
  final double height;
  final EdgeInsets? padding;

  const FlowTimelineCards({
    super.key,
    required this.forecastType,
    required this.timeFrame,
    required this.reachId,
    this.height = 140,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReachDataProvider>(
      builder: (context, reachProvider, child) {
        if (reachProvider.isLoading) {
          return _buildLoadingState();
        }

        if (!reachProvider.hasData) {
          return _buildEmptyState();
        }

        final forecastData = _extractForecastData(reachProvider);

        if (forecastData.isEmpty) {
          return _buildNoDataState();
        }

        return _buildTimelineCards(context, forecastData, reachProvider);
      },
    );
  }

  Widget _buildTimelineCards(
    BuildContext context,
    List<FlowDataPoint> data,
    ReachDataProvider reachProvider,
  ) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final dataPoint = data[index];
          final isFirst = index == 0;
          final isLast = index == data.length - 1;

          return Padding(
            padding: EdgeInsets.only(
              right: isLast ? 0 : 12,
              left: isFirst ? 0 : 0,
            ),
            child: _buildDataCard(context, dataPoint, reachProvider),
          );
        },
      ),
    );
  }

  Widget _buildDataCard(
    BuildContext context,
    FlowDataPoint dataPoint,
    ReachDataProvider reachProvider,
  ) {
    final flowCategory = _getFlowCategory(dataPoint.flow, reachProvider);
    final categoryColor = _getCategoryColor(flowCategory);
    final isCurrentTime = _isCurrentOrNearCurrent(dataPoint.validTime);

    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTime
              ? CupertinoColors.systemBlue
              : CupertinoColors.separator.resolveFrom(context),
          width: isCurrentTime ? 2 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(dataPoint.validTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCurrentTime
                        ? CupertinoColors.systemBlue
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (isCurrentTime)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Flow value
            Text(
              _formatFlow(dataPoint.flow),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.label,
              ),
            ),

            const Text(
              'CFS',
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel,
              ),
            ),

            const SizedBox(height: 8),

            // Flow category indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                flowCategory,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ),

            // Trend indicator (if not first card)
            const Spacer(),
            if (dataPoint.trend != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTrendIcon(dataPoint.trend!),
                    size: 12,
                    color: _getTrendColor(dataPoint.trend!),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatTrend(dataPoint.trend!),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getTrendColor(dataPoint.trend!),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6, // Show 6 loading cards
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index == 5 ? 0 : 12),
            child: _buildLoadingCard(),
          );
        },
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CupertinoActivityIndicator(radius: 12)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chart_bar,
              size: 32,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 8),
            Text(
              'No forecast data',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 32,
              color: CupertinoColors.systemOrange,
            ),
            const SizedBox(height: 8),
            Text(
              'No $timeFrame data available',
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Data extraction logic (placeholder for now)
  List<FlowDataPoint> _extractForecastData(ReachDataProvider reachProvider) {
    // This would extract actual forecast data based on forecastType and timeFrame
    // For now, returning mock data structure

    // In the real implementation, this would:
    // 1. Get the appropriate forecast data from reachProvider
    // 2. Filter by timeFrame
    // 3. Convert to FlowDataPoint objects
    // 4. Calculate trends between points

    return _generateMockData();
  }

  // Mock data for development (remove when real data is integrated)
  List<FlowDataPoint> _generateMockData() {
    final now = DateTime.now();
    final List<FlowDataPoint> mockData = [];

    for (int i = 0; i < 12; i++) {
      final time = now.add(Duration(hours: i));
      final baseFlow = 155.0;
      final variation = (i * 15.0) - 90.0; // Create some variation
      final flow = (baseFlow + variation).clamp(50.0, 400.0);

      FlowTrend? trend;
      if (i > 0) {
        final previousFlow = mockData.last.flow;
        final change = flow - previousFlow;
        if (change > 5)
          trend = FlowTrend.rising;
        else if (change < -5)
          trend = FlowTrend.falling;
        else
          trend = FlowTrend.stable;
      }

      mockData.add(FlowDataPoint(validTime: time, flow: flow, trend: trend));
    }

    return mockData;
  }

  String _getFlowCategory(double flow, ReachDataProvider reachProvider) {
    if (!reachProvider.hasData) return 'Unknown';

    final reach = reachProvider.currentReach!;
    if (!reach.hasReturnPeriods) return 'Unknown';

    // Convert CFS to CMS for comparison with return periods
    final flowCms = flow * 0.0283168;
    final periods = reach.returnPeriods!.entries.toList()
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
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

  bool _isCurrentOrNearCurrent(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now).abs();
    return difference.inMinutes <= 30; // Within 30 minutes of current time
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeDay = DateTime(time.year, time.month, time.day);

    if (timeDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (timeDay == today.add(const Duration(days: 1))) {
      return 'Tom\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day}\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatFlow(double flow) {
    if (flow >= 1000000) {
      return '${(flow / 1000000).toStringAsFixed(1)}M';
    } else if (flow >= 1000) {
      return '${(flow / 1000).toStringAsFixed(1)}K';
    } else if (flow >= 100) {
      return flow.toStringAsFixed(0);
    } else {
      return flow.toStringAsFixed(1);
    }
  }

  IconData _getTrendIcon(FlowTrend trend) {
    switch (trend) {
      case FlowTrend.rising:
        return CupertinoIcons.arrow_up;
      case FlowTrend.falling:
        return CupertinoIcons.arrow_down;
      case FlowTrend.stable:
        return CupertinoIcons.arrow_right;
    }
  }

  Color _getTrendColor(FlowTrend trend) {
    switch (trend) {
      case FlowTrend.rising:
        return CupertinoColors.systemRed;
      case FlowTrend.falling:
        return CupertinoColors.systemBlue;
      case FlowTrend.stable:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatTrend(FlowTrend trend) {
    switch (trend) {
      case FlowTrend.rising:
        return 'Rising';
      case FlowTrend.falling:
        return 'Falling';
      case FlowTrend.stable:
        return 'Stable';
    }
  }
}

// Data models for flow timeline
class FlowDataPoint {
  final DateTime validTime;
  final double flow; // in CFS
  final FlowTrend? trend;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const FlowDataPoint({
    required this.validTime,
    required this.flow,
    this.trend,
    this.confidence,
    this.metadata,
  });

  @override
  String toString() {
    return 'FlowDataPoint(time: $validTime, flow: ${flow.toStringAsFixed(1)} CFS, trend: $trend)';
  }
}

enum FlowTrend { rising, falling, stable }
