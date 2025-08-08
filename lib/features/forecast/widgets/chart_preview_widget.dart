// lib/features/forecast/widgets/chart_preview_widget.dart

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';

class ChartPreviewWidget extends StatelessWidget {
  final String forecastType;
  final VoidCallback? onTap;
  final double height;
  final bool showTitle;

  const ChartPreviewWidget({
    super.key,
    required this.forecastType,
    this.onTap,
    this.height = 120,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReachDataProvider>(
      builder: (context, reachProvider, child) {
        if (reachProvider.isLoading) {
          return _buildLoadingChart(context);
        }

        if (!reachProvider.hasData) {
          return _buildEmptyChart(context);
        }

        final chartData = _extractChartData(reachProvider);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.separator, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTitle) _buildHeader(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: chartData.isEmpty
                        ? _buildNoDataMessage(context)
                        : Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomPaint(
                                  painter: _ChartPainter(
                                    data: chartData,
                                    forecastType: forecastType,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                              // Touch indicator icon in top right
                              if (onTap != null)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBackground
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: CupertinoColors.separator
                                            .withOpacity(0.5),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Transform.rotate(
                                      angle: -pi / 2, // 90 degrees clockwise
                                      child: Icon(
                                        CupertinoIcons.hand_point_right_fill,
                                        size: 16,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getForecastDisplayName(forecastType),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          if (onTap != null)
            Icon(
              CupertinoIcons.arrow_up_right_square,
              size: 16,
              color: CupertinoColors.systemBlue.withOpacity(0.8),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingChart(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 8),
            Text(
              'Loading chart...',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_chart_fill,
              color: CupertinoColors.secondaryLabel,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(BuildContext context) {
    return Center(
      child: Text(
        'No ${_getForecastDisplayName(forecastType).toLowerCase()} data',
        style: const TextStyle(
          color: CupertinoColors.secondaryLabel,
          fontSize: 12,
        ),
      ),
    );
  }

  List<ChartDataPoint> _extractChartData(ReachDataProvider reachProvider) {
    final forecast = reachProvider.currentForecast;
    if (forecast == null) return [];

    // Special handling for short_range to get ALL data including past hours
    if (forecastType == 'short_range') {
      final forecastSeries = forecast.getPrimaryForecast(forecastType);
      if (forecastSeries == null || forecastSeries.isEmpty) return [];

      final List<ChartDataPoint> points = [];
      final now = DateTime.now();

      try {
        // Use ALL data points (no filtering by time - includes past hours)
        final data = forecastSeries.data;

        for (final point in data) {
          final flow = point.flow;

          if (flow > -9000) {
            // Filter out missing data sentinel values
            // Calculate hours from now (negative values = past hours)
            final hoursFromNow = point.validTime
                .difference(now)
                .inHours
                .toDouble();
            points.add(ChartDataPoint(x: hoursFromNow, y: flow));
          }
        }

        // Sort by time to ensure proper order
        points.sort((a, b) => a.x.compareTo(b.x));

        print(
          'CHART_PREVIEW: Short-range using ${points.length} total hours including past data',
        );
        return points;
      } catch (e) {
        print('CHART_PREVIEW: Error extracting short-range data: $e');
        return [];
      }
    }

    // Existing logic for other forecast types (medium_range, long_range)
    final forecastSeries = forecast.getPrimaryForecast(forecastType);
    if (forecastSeries == null || forecastSeries.isEmpty) return [];

    final List<ChartDataPoint> points = [];

    try {
      final data = forecastSeries.data;
      final now = DateTime.now();

      for (int i = 0; i < data.length && i < 50; i++) {
        // Limit points for preview
        final point = data[i];
        final flow = point.flow;

        if (flow > -9000) {
          // Filter out missing data sentinel values
          // Use actual time difference for better chart accuracy
          final timeFromNow = forecastType == 'medium_range'
              ? point.validTime.difference(now).inDays.toDouble()
              : point.validTime.difference(now).inHours.toDouble();
          points.add(ChartDataPoint(x: timeFromNow, y: flow));
        }
      }
    } catch (e) {
      print('CHART_PREVIEW: Error extracting data for $forecastType: $e');
    }

    return points;
  }

  String _getForecastDisplayName(String type) {
    switch (type) {
      case 'analysis_assimilation':
        return 'Current Analysis Preview';
      case 'short_range':
        return 'Short Range Preview';
      case 'medium_range':
        return 'Medium Range Preview';
      case 'medium_range_blend':
        return 'Medium Blend Preview';
      case 'long_range':
        return 'Long Range Preview';
      default:
        return 'Forecast Preview';
    }
  }
}

class ChartDataPoint {
  final double x;
  final double y;

  ChartDataPoint({required this.x, required this.y});
}

class _ChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final String forecastType;

  _ChartPainter({required this.data, required this.forecastType});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = _getLineColor(forecastType)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = _getLineColor(forecastType).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Find min and max values for scaling
    final minY = data.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    final maxX = data.map((p) => p.x).reduce((a, b) => a > b ? a : b);

    if (minY == maxY) return; // Avoid division by zero

    // Create path for the line
    final path = Path();
    final fillPath = Path();

    // Scale first point
    final firstPoint = data.first;
    final firstX = (firstPoint.x / maxX) * size.width;
    final firstY =
        size.height - ((firstPoint.y - minY) / (maxY - minY)) * size.height;

    path.moveTo(firstX, firstY);
    fillPath.moveTo(firstX, size.height);
    fillPath.lineTo(firstX, firstY);

    // Draw line through all points
    for (int i = 1; i < data.length; i++) {
      final point = data[i];
      final x = (point.x / maxX) * size.width;
      final y = size.height - ((point.y - minY) / (maxY - minY)) * size.height;

      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Complete fill path
    final lastPoint = data.last;
    final lastX = (lastPoint.x / maxX) * size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    // Draw fill area first
    canvas.drawPath(fillPath, fillPaint);

    // Draw line on top
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = _getLineColor(forecastType)
      ..style = PaintingStyle.fill;

    for (final point in data) {
      if (data.indexOf(point) % 5 == 0) {
        // Show every 5th point to avoid clutter
        final x = (point.x / maxX) * size.width;
        final y =
            size.height - ((point.y - minY) / (maxY - minY)) * size.height;
        canvas.drawCircle(Offset(x, y), 2.5, pointPaint);
      }
    }
  }

  Color _getLineColor(String forecastType) {
    switch (forecastType) {
      case 'analysis_assimilation':
        return CupertinoColors.systemBlue;
      case 'short_range':
        return CupertinoColors.systemGreen;
      case 'medium_range':
        return CupertinoColors.systemOrange;
      case 'medium_range_blend':
        return CupertinoColors.systemPurple;
      case 'long_range':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
