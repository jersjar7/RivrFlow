// lib/features/forecast/widgets/forecast_detail_template.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';
import 'current_flow_status_card.dart';
import 'time_frame_selector.dart';
import 'flow_timeline_cards.dart';
import 'chart_preview_widget.dart';

class ForecastDetailTemplate extends StatefulWidget {
  final String reachId;
  final String forecastType;
  final String title;
  final List<TimeFrameOption> timeFrameOptions;
  final VoidCallback? onChartTap;
  final Widget? additionalContent;
  final bool showCurrentFlow;
  final EdgeInsets? padding;

  const ForecastDetailTemplate({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.title,
    required this.timeFrameOptions,
    this.onChartTap,
    this.additionalContent,
    this.showCurrentFlow = true,
    this.padding,
  });

  @override
  State<ForecastDetailTemplate> createState() => _ForecastDetailTemplateState();
}

class _ForecastDetailTemplateState extends State<ForecastDetailTemplate> {
  late String _selectedTimeFrame;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedTimeFrame = widget.timeFrameOptions.first.value;
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final reachProvider = Provider.of<ReachDataProvider>(
        context,
        listen: false,
      );
      await reachProvider.refreshCurrentReach();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _onTimeFrameChanged(String newTimeFrame) {
    setState(() {
      _selectedTimeFrame = newTimeFrame;
    });
  }

  void _navigateToHydrograph() {
    Navigator.pushNamed(
      context,
      '/hydrograph',
      arguments: {
        'reachId': widget.reachId,
        'forecastType': widget.forecastType,
        'timeFrame': _selectedTimeFrame,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isRefreshing ? null : _handleRefresh,
          child: _isRefreshing
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.refresh),
        ),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      ),
      child: SafeArea(
        child: Consumer<ReachDataProvider>(
          builder: (context, reachProvider, child) {
            if (reachProvider.isLoading && !reachProvider.hasData) {
              return _buildLoadingState();
            }

            if (reachProvider.errorMessage != null) {
              return _buildErrorState(reachProvider.errorMessage!);
            }

            if (!reachProvider.hasData) {
              return _buildEmptyState();
            }

            return _buildContent(reachProvider);
          },
        ),
      ),
    );
  }

  Widget _buildContent(ReachDataProvider reachProvider) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Current Flow Status (Mini Version)
        if (widget.showCurrentFlow)
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: CurrentFlowStatusCard(
                expanded: false,
                onTap: _navigateToHydrograph,
              ),
            ),
          ),

        // Time Frame Selector
        SliverToBoxAdapter(
          child: Padding(
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSectionHeader('Time Range'),
                const SizedBox(height: 12),
                TimeFrameSelector(
                  options: widget.timeFrameOptions,
                  selectedValue: _selectedTimeFrame,
                  onChanged: _onTimeFrameChanged,
                ),
              ],
            ),
          ),
        ),

        // Flow Timeline Cards
        SliverToBoxAdapter(
          child: Padding(
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildSectionHeader('Flow Timeline'),
                const SizedBox(height: 12),
                FlowTimelineCards(
                  forecastType: widget.forecastType,
                  timeFrame: _selectedTimeFrame,
                  reachId: widget.reachId,
                ),
              ],
            ),
          ),
        ),

        // Chart Preview Section
        SliverToBoxAdapter(
          child: Padding(
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildSectionHeader('Flow Chart'),
                const SizedBox(height: 12),
                ChartPreviewWidget(
                  forecastType: widget.forecastType,
                  onTap: widget.onChartTap ?? _navigateToHydrograph,
                  height: 200,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),

        // Forecast Summary Metrics
        SliverToBoxAdapter(
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: _buildForecastSummary(reachProvider),
          ),
        ),

        // Additional Content (if provided)
        if (widget.additionalContent != null)
          SliverToBoxAdapter(child: widget.additionalContent!),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.label,
      ),
    );
  }

  Widget _buildForecastSummary(ReachDataProvider reachProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast Summary',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryMetrics(reachProvider),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics(ReachDataProvider reachProvider) {
    // This would be populated with actual forecast metrics
    // For now, showing placeholder structure
    return Column(
      children: [
        _buildMetricRow('Peak Flow', 'TBD CFS', CupertinoIcons.arrow_up),
        const SizedBox(height: 8),
        _buildMetricRow('Trend', 'Stable', CupertinoIcons.arrow_right),
        const SizedBox(height: 8),
        _buildMetricRow('Confidence', 'High', CupertinoIcons.checkmark_circle),
        const SizedBox(height: 8),
        _buildMetricRow('Last Updated', 'Just now', CupertinoIcons.clock),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CupertinoColors.systemBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.label,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 20),
          const SizedBox(height: 16),
          Text(
            'Loading ${widget.title.toLowerCase()}...',
            style: const TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load forecast',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _handleRefresh,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.chart_bar,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.title.toLowerCase()} data available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for updated forecasts',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: _handleRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
