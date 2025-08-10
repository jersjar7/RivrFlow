// lib/features/forecast/widgets/horizontal_flow_timeline.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/models/user_settings.dart';
import '../../../core/providers/reach_data_provider.dart';
import '../../../core/services/flow_unit_preference_service.dart';
import 'dart:math' as math;

enum FlowTimelineViewMode { hourCards, flowWave }

class HorizontalFlowTimeline extends StatefulWidget {
  final String reachId;
  final double height;
  final EdgeInsets? padding;
  final FlowTimelineViewMode initialViewMode;
  final VoidCallback? onViewModeChanged;

  const HorizontalFlowTimeline({
    super.key,
    required this.reachId,
    this.height = 140,
    this.padding,
    this.initialViewMode = FlowTimelineViewMode.hourCards,
    this.onViewModeChanged,
  });

  @override
  State<HorizontalFlowTimeline> createState() => _HorizontalFlowTimelineState();
}

class _HorizontalFlowTimelineState extends State<HorizontalFlowTimeline> {
  late FlowTimelineViewMode _viewMode;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  // Get current flow units from preference service
  String _getCurrentFlowUnit() {
    final currentUnit = FlowUnitPreferenceService().currentFlowUnit;
    return currentUnit == FlowUnit.cms ? 'CMS' : 'CFS';
  }

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

        final shortRangeData = _extractShortRangeData(reachProvider);

        if (shortRangeData.isEmpty) {
          return _buildNoDataState();
        }

        return Column(
          children: [
            _buildViewModeToggle(),
            const SizedBox(height: 12),
            _buildTimelineContent(context, shortRangeData, reachProvider),
          ],
        );
      },
    );
  }

  Widget _buildViewModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CupertinoSlidingSegmentedControl<FlowTimelineViewMode>(
          children: const {
            FlowTimelineViewMode.hourCards: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.square_grid_2x2, size: 14),
                  SizedBox(width: 4),
                  Text('Cards', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            FlowTimelineViewMode.flowWave: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.waveform, size: 14),
                  SizedBox(width: 4),
                  Text('Wave', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          },
          groupValue: _viewMode,
          onValueChanged: (FlowTimelineViewMode? value) {
            if (value != null) {
              setState(() {
                _viewMode = value;
              });
              widget.onViewModeChanged?.call();
            }
          },
          backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
          thumbColor: CupertinoColors.systemBackground.resolveFrom(context),
        ),
      ],
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    List<HourlyFlowDataPoint> data,
    ReachDataProvider reachProvider,
  ) {
    switch (_viewMode) {
      case FlowTimelineViewMode.hourCards:
        return _buildHourCards(context, data, reachProvider);
      case FlowTimelineViewMode.flowWave:
        return _buildFlowWave(context, data, reachProvider);
    }
  }

  Widget _buildHourCards(
    BuildContext context,
    List<HourlyFlowDataPoint> data,
    ReachDataProvider reachProvider,
  ) {
    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 0),
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
            child: _buildHourCard(context, dataPoint, reachProvider),
          );
        },
      ),
    );
  }

  Widget _buildHourCard(
    BuildContext context,
    HourlyFlowDataPoint dataPoint,
    ReachDataProvider reachProvider,
  ) {
    final flowCategory = _getFlowCategory(dataPoint.flow, reachProvider);
    final categoryColor = _getCategoryColor(flowCategory);
    final isCurrentHour = _isCurrentOrNearCurrentHour(dataPoint.validTime);
    final trendPercentage = _calculateTrendPercentage(dataPoint);
    final currentUnit = _getCurrentFlowUnit(); // Get current unit

    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentHour
              ? CupertinoColors.systemBlue
              : CupertinoColors.separator.resolveFrom(context),
          width: isCurrentHour ? 2 : 0.5,
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
            // Time header with current indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCurrentHour ? 'Now' : _formatLocalTime(dataPoint.validTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCurrentHour
                        ? CupertinoColors.systemBlue
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (isCurrentHour)
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

            // UPDATED: Now dynamic units
            Text(
              currentUnit,
              style: const TextStyle(
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

            // Trend indicator with percentage
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
                    trendPercentage != null
                        ? '${trendPercentage.toStringAsFixed(0)}%'
                        : _formatTrend(dataPoint.trend!),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Widget _buildFlowWave(
    BuildContext context,
    List<HourlyFlowDataPoint> data,
    ReachDataProvider reachProvider,
  ) {
    return Container(
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: CustomPaint(
        painter: FlowWavePainter(
          data: data,
          reachProvider: reachProvider,
          context: context,
        ),
        child: Container(),
      ),
    );
  }

  // Data extraction method - THIS METHOD NEEDS TO BE ADDED TO CORE DATA SERVICES
  List<HourlyFlowDataPoint> _extractShortRangeData(
    ReachDataProvider reachProvider,
  ) {
    return reachProvider.getShortRangeHourlyData();
  }

  String _getFlowCategory(double flow, ReachDataProvider reachProvider) {
    if (!reachProvider.hasData) return 'Unknown';

    final reach = reachProvider.currentReach!;
    if (!reach.hasReturnPeriods) return 'Unknown';

    // Data is already in user's preferred unit, so use it directly
    final periods = reach.returnPeriods!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final period in periods) {
      if (flow < period.value) {
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

  bool _isCurrentOrNearCurrentHour(DateTime dataTime) {
    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final dataHour = DateTime(
      dataTime.year,
      dataTime.month,
      dataTime.day,
      dataTime.hour,
    );

    return dataHour == currentHour; // Only match exact hour bucket
  }

  String _formatLocalTime(DateTime forecastTime) {
    // Convert to local device time if needed
    final localTime = forecastTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final forecastDay = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
    );

    if (forecastDay == today) {
      return '${localTime.hour.toString().padLeft(2, '0')}:00';
    } else if (forecastDay == today.add(const Duration(days: 1))) {
      return 'Tom\n${localTime.hour.toString().padLeft(2, '0')}:00';
    } else {
      return '${localTime.month}/${localTime.day}\n${localTime.hour.toString().padLeft(2, '0')}:00';
    }
  }

  double? _calculateTrendPercentage(HourlyFlowDataPoint dataPoint) {
    return dataPoint.trendPercentage;
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
        return CupertinoColors.systemGreen;
      case FlowTrend.falling:
        return CupertinoColors.systemRed;
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

  // Loading and error states
  Widget _buildLoadingState() {
    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
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
      width: 100,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CupertinoActivityIndicator(radius: 12)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.height,
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
              'No hourly data',
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
      height: widget.height,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 32,
              color: CupertinoColors.systemOrange,
            ),
            SizedBox(height: 8),
            Text(
              'No short range data available',
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
}

// Custom painter for flow wave visualization
class FlowWavePainter extends CustomPainter {
  final List<HourlyFlowDataPoint> data;
  final ReachDataProvider reachProvider;
  final BuildContext context;

  FlowWavePainter({
    required this.data,
    required this.reachProvider,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = CupertinoColors.systemBlue.resolveFrom(context)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = CupertinoColors.systemBlue.resolveFrom(context).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Calculate scaling
    final minFlow = data.map((d) => d.flow).reduce(math.min);
    final maxFlow = data.map((d) => d.flow).reduce(math.max);
    final flowRange = maxFlow - minFlow;

    // Create path for wave
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedFlow = (data[i].flow - minFlow) / flowRange;
      final y =
          size.height -
          (normalizedFlow * size.height * 0.8) -
          (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = CupertinoColors.systemBlue.resolveFrom(context)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedFlow = (data[i].flow - minFlow) / flowRange;
      final y =
          size.height -
          (normalizedFlow * size.height * 0.8) -
          (size.height * 0.1);

      canvas.drawCircle(Offset(x, y), 4, pointPaint);

      // Draw current hour indicator
      if (i < data.length) {
        final now = DateTime.now();
        final currentHour = DateTime(now.year, now.month, now.day, now.hour);
        final dataHour = DateTime(
          data[i].validTime.year,
          data[i].validTime.month,
          data[i].validTime.day,
          data[i].validTime.hour,
        );

        if (dataHour == currentHour) {
          final currentPaint = Paint()
            ..color = CupertinoColors.systemRed.resolveFrom(context)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 6, currentPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Enhanced data model for hourly flow data
class HourlyFlowDataPoint {
  final DateTime validTime;
  final double flow; // in user's preferred unit (CFS or CMS)
  final FlowTrend? trend;
  final double? trendPercentage; // Percentage change from previous hour
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const HourlyFlowDataPoint({
    required this.validTime,
    required this.flow,
    this.trend,
    this.trendPercentage,
    this.confidence,
    this.metadata,
  });

  @override
  String toString() {
    return 'HourlyFlowDataPoint(time: $validTime, flow: ${flow.toStringAsFixed(1)}, trend: $trend, change: ${trendPercentage?.toStringAsFixed(1)}%)';
  }
}

enum FlowTrend { rising, falling, stable }
