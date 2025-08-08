// lib/features/forecast/widgets/interactive_chart.dart

import 'package:flutter/cupertino.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math' as math;
import '../../../core/providers/reach_data_provider.dart';
import '../../../core/constants.dart';

// Simple controller for chart interactions
class ChartController {
  VoidCallback? _resetZoom;

  void _setResetCallback(VoidCallback callback) {
    _resetZoom = callback;
  }

  void resetZoom() {
    _resetZoom?.call();
  }
}

class InteractiveChart extends StatefulWidget {
  final String reachId;
  final String forecastType;
  final bool showReturnPeriods;
  final bool showTooltips;
  final ReachDataProvider reachProvider;
  final ChartController? controller;

  const InteractiveChart({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.showReturnPeriods,
    required this.showTooltips,
    required this.reachProvider,
    this.controller,
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
  List<ChartData> _chartData = [];
  List<ChartDataPoint> _forecastData = [];

  // User interaction behaviors
  late TrackballBehavior _trackballBehavior;
  late CrosshairBehavior _crosshairBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _initializeChart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeBehaviors();

    // Set up controller callback if provided
    widget.controller?._setResetCallback(() {
      _zoomPanBehavior.reset();
    });
  }

  @override
  void didUpdateWidget(InteractiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecastType != widget.forecastType ||
        oldWidget.showReturnPeriods != widget.showReturnPeriods) {
      _initializeChart();
    }
    if (oldWidget.showTooltips != widget.showTooltips) {
      _initializeBehaviors();
    }
  }

  void _initializeBehaviors() {
    // Trackball - Shows tooltip for nearest data point
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      lineType: TrackballLineType.vertical,
      lineColor: CupertinoColors.systemGrey,
      lineWidth: 1,
      lineDashArray: [8, 4],
      shouldAlwaysShow: false,
      hideDelay: 3000,
      tooltipDisplayMode: TrackballDisplayMode.nearestPoint,
      tooltipAlignment: ChartAlignment.near,
      tooltipSettings: InteractiveTooltip(
        enable: true,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderColor: CupertinoColors.separator.resolveFrom(context),
        borderWidth: 1,
        format: 'point.y CFS',
        textStyle: TextStyle(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        canShowMarker: true,
      ),
      markerSettings: TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        width: 8,
        height: 8,
        color: CupertinoColors.systemBlue,
        borderColor: CupertinoColors.white,
        borderWidth: 2,
      ),
    );

    // Crosshair - Shows axis values with cross lines
    _crosshairBehavior = CrosshairBehavior(
      enable: true,
      activationMode: ActivationMode.longPress,
      lineType: CrosshairLineType.both,
      lineColor: CupertinoColors.systemGrey2,
      lineWidth: 1,
      lineDashArray: [5, 5],
      shouldAlwaysShow: false,
      hideDelay: 3000,
    );

    // Enhanced zoom and pan behavior
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      enableMouseWheelZooming: true,
      enableDirectionalZooming: true,
      zoomMode: ZoomMode.xy,
      maximumZoomLevel: 0.01,
      selectionRectBorderWidth: 2,
      selectionRectBorderColor: CupertinoColors.systemBlue,
      selectionRectColor: CupertinoColors.systemBlue.withOpacity(0.2),
    );

    // Enhanced tooltip behavior
    _tooltipBehavior = TooltipBehavior(
      enable: widget.showTooltips,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      borderColor: CupertinoColors.separator.resolveFrom(context),
      borderWidth: 1,
      opacity: 0.9,
      format: 'point.y CFS',
      textStyle: TextStyle(
        color: CupertinoColors.label.resolveFrom(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      animationDuration: 300,
      canShowMarker: true,
    );
  }

  void _initializeChart() {
    _extractChartData();

    // ONLY proceed if we actually have forecast data
    if (_forecastData.isEmpty) {
      setState(() {
        _isInitialized = false; // Mark as not ready
      });
      return;
    }

    _calculateAxisBounds();

    setState(() {
      _isInitialized = true; // Now we're truly ready
    });
  }

  void _extractChartData() {
    if (!widget.reachProvider.hasData) {
      _chartData = [];
      _forecastData = [];
      return;
    }

    // Get forecast data once and store it
    _forecastData = _getForecastData();
    _chartData = _convertToChartData(_forecastData);
  }

  List<ChartDataPoint> _getForecastData() {
    final forecast = widget.reachProvider.currentForecast;
    if (forecast == null) return [];

    // Use real API data instead of mock data
    if (widget.forecastType == 'short_range') {
      final forecastSeries = forecast.getPrimaryForecast('short_range');
      if (forecastSeries == null || forecastSeries.isEmpty) return [];

      // Use ALL data points (including past hours)
      return forecastSeries.data
          .map(
            (point) => ChartDataPoint(
              time: point.validTime.toLocal(),
              flow: point.flow,
            ),
          )
          .toList();
    }

    // For other forecast types, use existing logic but with real data
    final forecastSeries = forecast.getPrimaryForecast(widget.forecastType);
    if (forecastSeries == null || forecastSeries.isEmpty) return [];

    return forecastSeries.data
        .map(
          (point) =>
              ChartDataPoint(time: point.validTime.toLocal(), flow: point.flow),
        )
        .toList();
  }

  List<ChartData> _convertToChartData(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];

    // Find the earliest time as reference point
    final earliestTime = data
        .map((d) => d.time)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return data.map((point) {
      // Convert to hours since the earliest time
      final hoursSinceStart =
          point.time.difference(earliestTime).inMinutes / 60.0;
      return ChartData(hoursSinceStart, point.flow);
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

    _minX = _chartData.map((data) => data.x).reduce(math.min);
    _maxX = _chartData.map((data) => data.x).reduce(math.max);
    _minY = _chartData.map((data) => data.y).reduce(math.min);
    _maxY = _chartData.map((data) => data.y).reduce(math.max);

    // Include return period values in bounds calculation when toggle is ON
    if (widget.showReturnPeriods && widget.reachProvider.hasData) {
      final reach = widget.reachProvider.currentReach;
      if (reach?.returnPeriods != null) {
        final returnPeriods = reach!.returnPeriods!;
        const cmsToCs = 35.3147; // Convert CMS to CFS

        for (final entry in returnPeriods.entries) {
          final flowCfs = entry.value * cmsToCs;
          // Include return period values in Y bounds
          if (flowCfs > _maxY) _maxY = flowCfs;
          if (flowCfs < _minY) _minY = flowCfs;
        }

        print(
          'DEBUG: Bounds adjusted for return periods - Y: $_minY to $_maxY',
        );
      }
    }

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

    print('DEBUG: Final chart bounds Y: $_minY to $_maxY');
  }

  List<PlotBand> _buildPlotBands() {
    if (!widget.showReturnPeriods || !widget.reachProvider.hasData) {
      return [];
    }

    final reach = widget.reachProvider.currentReach;
    if (reach?.returnPeriods == null) return [];

    final returnPeriods = reach!.returnPeriods!;
    const cmsToCs = 35.3147; // Convert CMS to CFS

    // Convert return periods to CFS and sort
    final sortedReturnPeriods = <int, double>{};
    for (final entry in returnPeriods.entries) {
      sortedReturnPeriods[entry.key] = entry.value * cmsToCs;
    }

    final plotBands = <PlotBand>[];

    // Normal zone (chart min to 2yr)
    final twoYearFlow = sortedReturnPeriods[2];
    if (twoYearFlow != null) {
      plotBands.add(
        AppConstants.createFloodZonePlotBand(_minY, twoYearFlow, 'normal'),
      );
    }

    // Action zone (2yr to 5yr)
    final fiveYearFlow = sortedReturnPeriods[5];
    if (twoYearFlow != null && fiveYearFlow != null) {
      plotBands.add(
        AppConstants.createFloodZonePlotBand(
          twoYearFlow,
          fiveYearFlow,
          'action',
        ),
      );
    }

    // Moderate zone (5yr to 10yr)
    final tenYearFlow = sortedReturnPeriods[10];
    if (fiveYearFlow != null && tenYearFlow != null) {
      plotBands.add(
        AppConstants.createFloodZonePlotBand(
          fiveYearFlow,
          tenYearFlow,
          'moderate',
        ),
      );
    }

    // Major zone (10yr to 25yr)
    final twentyFiveYearFlow = sortedReturnPeriods[25];
    if (tenYearFlow != null && twentyFiveYearFlow != null) {
      plotBands.add(
        AppConstants.createFloodZonePlotBand(
          tenYearFlow,
          twentyFiveYearFlow,
          'major',
        ),
      );
    }

    // Extreme zone (25yr to chart max)
    if (twentyFiveYearFlow != null) {
      plotBands.add(
        AppConstants.createFloodZonePlotBand(
          twentyFiveYearFlow,
          _maxY,
          'extreme',
        ),
      );
    }

    print('DEBUG: Added ${plotBands.length} plot bands');
    return plotBands;
  }

  List<PlotBand> _buildReturnPeriodLines() {
    if (!widget.showReturnPeriods || !widget.reachProvider.hasData) {
      return [];
    }

    final reach = widget.reachProvider.currentReach;
    if (reach?.returnPeriods == null) return [];

    final returnPeriods = reach!.returnPeriods!;
    const cmsToCs = 35.3147; // Convert CMS to CFS

    final lines = <PlotBand>[];
    final sortedEntries = returnPeriods.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      final year = entry.key;
      final flowCfs = entry.value * cmsToCs;
      final label = AppConstants.getReturnPeriodLabel(year);

      // Create a line (start == end) with label
      lines.add(
        PlotBand(
          start: flowCfs,
          end: flowCfs,
          borderColor: CupertinoColors.systemRed,
          borderWidth: 2,
          dashArray: [5, 5],
          text: label,
          textStyle: const TextStyle(
            color: CupertinoColors.systemRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          horizontalTextAlignment: TextAnchor.end,
        ),
      );
    }

    return lines;
  }

  double? _getNowLinePosition() {
    if (widget.forecastType != 'short_range' || _forecastData.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final earliestTime = _forecastData
        .map((d) => d.time)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return now.difference(earliestTime).inMinutes / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    // DON'T render chart until we have actual forecast data
    if (!_isInitialized || _chartData.isEmpty || _forecastData.isEmpty) {
      return _buildEmptyChart();
    }

    final nowPosition = _getNowLinePosition();

    return Container(
      padding: const EdgeInsets.all(16),
      child: SfCartesianChart(
        primaryXAxis: NumericAxis(
          minimum: _minX,
          maximum: _maxX,
          interval: (_maxX - _minX) / 6,
          title: AxisTitle(
            text: _getTimeAxisLabel(),
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            return ChartAxisLabel(
              _formatTimeValue(details.value.toDouble()),
              TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            );
          },
          // Enable interactive tooltip for crosshair
          interactiveTooltip: InteractiveTooltip(
            enable: true,
            borderColor: CupertinoColors.systemBlue,
            borderWidth: 1,
            format: '{value}',
            textStyle: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 11,
            ),
          ),
          plotBands: nowPosition != null
              ? [
                  PlotBand(
                    start: nowPosition,
                    end: nowPosition,
                    borderColor: CupertinoColors.systemRed,
                    borderWidth: 2,
                    dashArray: [8, 4],
                    text: 'Now',
                    textStyle: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    verticalTextAlignment: TextAnchor.start,
                  ),
                ]
              : [],
        ),
        primaryYAxis: NumericAxis(
          minimum: _minY,
          maximum: _maxY,
          interval: (_maxY - _minY) / 6,
          title: AxisTitle(
            text: 'Flow (CFS)',
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            return ChartAxisLabel(
              _formatFlowValue(details.value.toDouble()),
              TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            );
          },
          // Enable interactive tooltip for crosshair
          interactiveTooltip: InteractiveTooltip(
            enable: true,
            borderColor: CupertinoColors.systemBlue,
            borderWidth: 1,
            format: '{value} CFS',
            textStyle: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 11,
            ),
          ),
          plotBands: [..._buildPlotBands(), ..._buildReturnPeriodLines()],
        ),
        series: [
          LineSeries<ChartData, double>(
            dataSource: _chartData,
            xValueMapper: (ChartData data, _) => data.x,
            yValueMapper: (ChartData data, _) => data.y,
            color: CupertinoColors.systemBlue,
            width: 3,
            markerSettings: MarkerSettings(
              isVisible: _chartData.length <= 20,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
              color: CupertinoColors.systemBlue,
              borderWidth: 2,
              borderColor: CupertinoColors.systemBackground.resolveFrom(
                context,
              ),
            ),
            // Enable selection for the series
            selectionBehavior: SelectionBehavior(
              enable: true,
              selectedColor: CupertinoColors.systemOrange,
              unselectedColor: CupertinoColors.systemBlue.withOpacity(0.5),
              selectedBorderColor: CupertinoColors.systemRed,
              selectedBorderWidth: 2,
              toggleSelection: true,
            ),
            // Enable trackball for this series
            enableTrackball: true,
          ),
        ],

        // User interaction behaviors
        trackballBehavior: _trackballBehavior,
        crosshairBehavior: _crosshairBehavior,
        zoomPanBehavior: _zoomPanBehavior,
        tooltipBehavior: _tooltipBehavior,

        // Event callbacks for enhanced interactions
        onTrackballPositionChanging: (TrackballArgs args) {
          // Customize trackball display
          final flow = args.chartPointInfo.chartPoint?.y;
          final time = args.chartPointInfo.chartPoint?.x;
          if (flow != null && time != null) {
            args.chartPointInfo.label =
                '${_formatFlowValue(flow.toDouble())} CFS\n${_formatTimeValue(time)}';
          }
        },

        onCrosshairPositionChanging: (CrosshairRenderArgs args) {
          // Customize crosshair tooltip based on axis
          if (args.orientation == AxisOrientation.vertical) {
            args.text = _formatTimeValue(args.value);
          } else {
            args.text = '${_formatFlowValue(args.value)} CFS';
          }
        },

        onTooltipRender: (TooltipArgs args) {
          // Enhanced tooltip formatting
          // You can customize args.text here if needed
          // args.text = 'Custom: ${args.text}';
        },

        onSelectionChanged: (SelectionArgs args) {
          // Handle data point selection
          print('Selection changed');
        },

        onZooming: (ZoomPanArgs args) {
          // Handle zoom events
          print('Chart is being zoomed');
        },

        onActualRangeChanged: (ActualRangeChangedArgs args) {
          // Handle axis range changes during zoom/pan
          print('Axis range changed');
        },
      ),
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

  String _formatTimeValue(double hoursSinceStart) {
    // For short_range, we MUST have forecast data to show correct times
    if (widget.forecastType == 'short_range') {
      if (_forecastData.isEmpty) {
        // Data not ready - don't render anything
        return '';
      }

      final earliestTime = _forecastData
          .map((d) => d.time)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final actualTime = earliestTime.add(
        Duration(minutes: (hoursSinceStart * 60).round()),
      );

      return '${actualTime.hour.toString().padLeft(2, '0')}:${(actualTime.minute ~/ 30 * 30).toString().padLeft(2, '0')}';
    }

    // For other forecast types
    if (widget.forecastType == 'medium_range') {
      final days = (hoursSinceStart / 24).round();
      return '${days}d';
    } else {
      final days = (hoursSinceStart / 24).round();
      final weeks = (days / 7).round();
      if (weeks > 0) return '${weeks}w';
      return '${days}d';
    }
  }

  String _getTimeAxisLabel() {
    switch (widget.forecastType) {
      case 'short_range':
        return 'Time of Day';
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
