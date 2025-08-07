// lib/features/forecast/widgets/interactive_chart.dart

import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../core/providers/reach_data_provider.dart';

class InteractiveChart extends StatefulWidget {
  final String reachId;
  final String forecastType;
  final bool showReturnPeriods;
  final bool isWaveView;
  final bool showTooltips;
  final ReachDataProvider reachProvider;

  const InteractiveChart({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.showReturnPeriods,
    required this.isWaveView,
    required this.showTooltips,
    required this.reachProvider,
  });

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  double _minX = 0;
  double _maxX = 0;
  double _minY = 0;
  double _maxY = 0;
  bool _isInitialized = false;
  List<FlSpot> _chartData = [];
  List<HorizontalLine> _returnPeriodLines = [];

  @override
  void initState() {
    super.initState();
    _initializeChart();
  }

  @override
  void didUpdateWidget(InteractiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecastType != widget.forecastType ||
        oldWidget.showReturnPeriods != widget.showReturnPeriods ||
        oldWidget.isWaveView != widget.isWaveView) {
      _initializeChart();
    }
  }

  void _initializeChart() {
    _extractChartData();
    _calculateAxisBounds();
    _buildReturnPeriodLines();
    setState(() {
      _isInitialized = true;
    });
  }

  void _extractChartData() {
    if (!widget.reachProvider.hasData) {
      _chartData = [];
      return;
    }

    // Extract forecast data based on type - showing all available data
    final forecastData = _getForecastData();
    _chartData = _convertToFlSpots(forecastData);
  }

  List<ChartDataPoint> _getForecastData() {
    // This would extract actual forecast data from the provider
    // For now, generating mock data that represents the structure
    return _generateMockForecastData();
  }

  List<ChartDataPoint> _generateMockForecastData() {
    final now = DateTime.now();
    final List<ChartDataPoint> data = [];

    // Generate data amounts based on forecast type - showing full available data
    int dataPoints;
    Duration interval;

    switch (widget.forecastType) {
      case 'short_range':
        dataPoints = 18; // Full 18 hours available
        interval = const Duration(hours: 1);
        break;
      case 'medium_range':
        dataPoints = 10; // Full 10 days available
        interval = const Duration(days: 1);
        break;
      case 'long_range':
        dataPoints = 8; // Full 8 weeks available
        interval = const Duration(days: 7);
        break;
      default:
        dataPoints = 24; // Default fallback
        interval = const Duration(hours: 1);
        break;
    }

    for (int i = 0; i < dataPoints; i++) {
      final time = now.add(
        Duration(milliseconds: (interval.inMilliseconds * i).round()),
      );

      // Create realistic flow variation
      final baseFlow = 155.0;
      final variation = math.sin(i * 0.3) * 50 + math.cos(i * 0.1) * 20;
      final noise = (math.Random().nextDouble() - 0.5) * 10;
      final flow = (baseFlow + variation + noise).clamp(50.0, 400.0);

      data.add(
        ChartDataPoint(
          time: time,
          flow: flow,
          confidence: 0.9 - (i * 0.01), // Decreasing confidence over time
        ),
      );
    }

    return data;
  }

  List<FlSpot> _convertToFlSpots(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];

    final firstTime = data.first.time;
    return data.map((point) {
      final xValue = point.time.difference(firstTime).inHours.toDouble();
      return FlSpot(xValue, point.flow);
    }).toList();
  }

  void _calculateAxisBounds() {
    if (_chartData.isEmpty) {
      _minX = 0;
      _maxX = 24;
      _minY = 0;
      _maxY = 500;
      return;
    }

    _minX = _chartData.map((spot) => spot.x).reduce(math.min);
    _maxX = _chartData.map((spot) => spot.x).reduce(math.max);
    _minY = _chartData.map((spot) => spot.y).reduce(math.min);
    _maxY = _chartData.map((spot) => spot.y).reduce(math.max);

    // Add padding
    final xRange = _maxX - _minX;
    final yRange = _maxY - _minY;

    _minX -= xRange * 0.05;
    _maxX += xRange * 0.05;
    _minY -= yRange * 0.1;
    _maxY += yRange * 0.1;

    // Ensure minimum bounds
    if (_minY < 0) _minY = 0;
    if (_maxY < 100) _maxY = 100;
  }

  void _buildReturnPeriodLines() {
    _returnPeriodLines = [];

    if (!widget.showReturnPeriods || !widget.reachProvider.hasData) {
      return;
    }

    final reach = widget.reachProvider.currentReach;
    if (reach?.returnPeriods == null) return;

    final returnPeriods = reach!.returnPeriods!;
    final colors = [
      CupertinoColors.systemYellow,
      CupertinoColors.systemOrange,
      CupertinoColors.systemRed,
      CupertinoColors.systemPurple,
    ];

    int colorIndex = 0;
    for (final entry in returnPeriods.entries) {
      final year = entry.key;
      final flowCms = entry.value;
      final flowCfs = flowCms * 35.3147; // Convert CMS to CFS

      // Only show lines that are within the chart bounds
      if (flowCfs >= _minY && flowCfs <= _maxY) {
        _returnPeriodLines.add(
          HorizontalLine(
            y: flowCfs,
            color: colors[colorIndex % colors.length].withOpacity(0.7),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: TextStyle(
                color: colors[colorIndex % colors.length],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (line) => '${year}yr',
            ),
          ),
        );
        colorIndex++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _chartData.isEmpty) {
      return _buildEmptyChart();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: _buildGridData(),
          titlesData: _buildTitlesData(),
          borderData: _buildBorderData(),
          lineBarsData: _buildLineData(),
          extraLinesData: ExtraLinesData(horizontalLines: _returnPeriodLines),
          lineTouchData: _buildTouchData(),
          minX: _minX,
          maxX: _maxX,
          minY: _minY,
          maxY: _maxY,
          clipData: const FlClipData.all(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: (_maxY - _minY) / 6,
      verticalInterval: (_maxX - _minX) / 8,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: CupertinoColors.separator.resolveFrom(context),
          strokeWidth: 0.5,
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: CupertinoColors.separator.resolveFrom(context),
          strokeWidth: 0.5,
        );
      },
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          interval: (_maxY - _minY) / 6,
          getTitlesWidget: (value, meta) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _formatFlowValue(value),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
        axisNameWidget: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Flow (CFS)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: (_maxX - _minX) / 6,
          getTitlesWidget: (value, meta) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatTimeValue(value),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
        axisNameWidget: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _getTimeAxisLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border(
        left: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 1,
        ),
        bottom: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 1,
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineData() {
    if (_chartData.isEmpty) return [];

    return [
      LineChartBarData(
        spots: _chartData,
        isCurved: !widget.isWaveView,
        color: CupertinoColors.systemBlue,
        barWidth: widget.isWaveView ? 1 : 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: !widget.isWaveView || _chartData.length <= 20,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: CupertinoColors.systemBlue,
              strokeWidth: 2,
              strokeColor: CupertinoColors.systemBackground.resolveFrom(
                context,
              ),
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.systemBlue.withOpacity(0.3),
              CupertinoColors.systemBlue.withOpacity(0.1),
              CupertinoColors.systemBlue.withOpacity(0.0),
            ],
          ),
        ),
      ),
    ];
  }

  LineTouchData _buildTouchData() {
    if (!widget.showTooltips) {
      return LineTouchData(enabled: false);
    }

    return LineTouchData(
      enabled: true,
      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
        // Handle touch events for custom interactions
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) =>
            CupertinoColors.systemBackground.resolveFrom(context),
        tooltipBorder: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
        tooltipBorderRadius: BorderRadius.circular(8),
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          return touchedBarSpots.map((barSpot) {
            return LineTooltipItem(
              '${_formatFlowValue(barSpot.y)}\n${_formatTooltipTime(barSpot.x)}',
              TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator:
          (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: CupertinoColors.systemBlue,
                  strokeWidth: 2,
                  dashArray: [3, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: CupertinoColors.systemBlue,
                      strokeWidth: 3,
                      strokeColor: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
                    );
                  },
                ),
              );
            }).toList();
          },
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chart_bar,
            size: 48,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No chart data available',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updated forecasts',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFlowValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value >= 100) {
      return value.toStringAsFixed(0);
    } else {
      return value.toStringAsFixed(1);
    }
  }

  String _formatTimeValue(double hours) {
    if (widget.forecastType == 'long_range') {
      final days = (hours / 24).round();
      final weeks = (days / 7).round();
      if (weeks > 0) return '${weeks}w';
      return '${days}d';
    } else if (widget.forecastType == 'medium_range') {
      final days = (hours / 24).round();
      return '${days}d';
    } else {
      return '${hours.toInt()}h';
    }
  }

  String _formatTooltipTime(double hours) {
    final now = DateTime.now();
    final targetTime = now.add(Duration(hours: hours.toInt()));

    if (widget.forecastType == 'short_range') {
      return '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${targetTime.month}/${targetTime.day}';
    }
  }

  String _getTimeAxisLabel() {
    switch (widget.forecastType) {
      case 'short_range':
        return 'Hours from now';
      case 'medium_range':
        return 'Days from now';
      case 'long_range':
        return 'Weeks from now';
      default:
        return 'Time';
    }
  }
}

// Data models for chart
class ChartDataPoint {
  final DateTime time;
  final double flow;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const ChartDataPoint({
    required this.time,
    required this.flow,
    this.confidence,
    this.metadata,
  });
}
