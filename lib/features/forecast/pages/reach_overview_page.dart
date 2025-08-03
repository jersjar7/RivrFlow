// lib/features/forecast/pages/reach_overview_page.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';
import '../widgets/current_flow_status_card.dart';
import '../widgets/forecast_category_grid.dart';
import '../widgets/chart_preview_widget.dart';

class ReachOverviewPage extends StatefulWidget {
  final String? reachId;

  const ReachOverviewPage({super.key, this.reachId});

  @override
  State<ReachOverviewPage> createState() => _ReachOverviewPageState();
}

class _ReachOverviewPageState extends State<ReachOverviewPage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReachData();
    });
  }

  Future<void> _loadReachData() async {
    if (widget.reachId == null) return;

    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );

    // Only load if we don't already have this reach loaded
    if (reachProvider.currentReach?.reachId != widget.reachId) {
      await reachProvider.loadReach(widget.reachId!);
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _handleRefresh() async {
    if (widget.reachId == null) return;

    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );
    await reachProvider.refreshCurrentReach();
  }

  void _navigateToForecastDetail(String forecastType) {
    if (widget.reachId == null) return;

    Navigator.pushNamed(
      context,
      '/short-range-detail', // We'll update this to handle different types
      arguments: {'reachId': widget.reachId, 'forecastType': forecastType},
    );
  }

  void _navigateToHydrograph(String forecastType) {
    if (widget.reachId == null) return;

    Navigator.pushNamed(
      context,
      '/hydrograph',
      arguments: {'reachId': widget.reachId, 'forecastType': forecastType},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reachId == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('River Forecast'),
        ),
        child: _buildErrorState('No reach selected'),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('River Forecast'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _handleRefresh,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: Consumer<ReachDataProvider>(
        builder: (context, reachProvider, child) {
          if (!_isInitialized && reachProvider.isLoading) {
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
    );
  }

  Widget _buildContent(ReachDataProvider reachProvider) {
    final reach = reachProvider.currentReach!;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Station Header
          SliverToBoxAdapter(child: _buildStationHeader(reach)),

          // Hero Flow Status Card
          SliverToBoxAdapter(
            child: CurrentFlowStatusCard(
              expanded: true,
              onTap: () => _navigateToHydrograph('short_range'),
            ),
          ),

          // Forecast Categories Grid
          SliverToBoxAdapter(
            child: ForecastCategoryGrid(
              onCategoryTap: _navigateToForecastDetail,
            ),
          ),

          // Chart Previews Section
          SliverToBoxAdapter(child: _buildChartPreviewsSection(reachProvider)),

          // Station Metadata
          SliverToBoxAdapter(
            child: _buildStationMetadata(reach, reachProvider),
          ),

          // Add some bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildStationHeader(reach) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CupertinoColors.systemBlue.withOpacity(0.1),
            CupertinoColors.systemBackground,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main title
          Text(
            reach.displayName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle with location
          if (reach.formattedLocation.isNotEmpty)
            Text(
              reach.formattedLocation,
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),

          const SizedBox(height: 16),

          // Coordinates and basic info
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: CupertinoIcons.location,
                  label: 'Coordinates',
                  value:
                      '${reach.latitude.toStringAsFixed(4)}, ${reach.longitude.toStringAsFixed(4)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  icon: CupertinoIcons.number,
                  label: 'Reach ID',
                  value: reach.reachId,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: CupertinoColors.secondaryLabel),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPreviewsSection(ReachDataProvider reachProvider) {
    final availableTypes = reachProvider.getAvailableForecastTypes();

    if (availableTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Quick Chart Previews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
        ),

        // Show chart previews for available forecast types
        ...availableTypes.take(3).map((forecastType) {
          return ChartPreviewWidget(
            forecastType: forecastType,
            onTap: () => _navigateToHydrograph(forecastType),
            height: 100,
          );
        }),
      ],
    );
  }

  Widget _buildStationMetadata(reach, ReachDataProvider reachProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Station Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),

          const SizedBox(height: 12),

          _buildMetadataRow('Data Source', 'NOAA National Water Model'),

          _buildMetadataRow(
            'Available Forecasts',
            reachProvider.getAvailableForecastTypes().length.toString(),
          ),

          if (reachProvider.hasEnsembleData())
            _buildMetadataRow('Ensemble Data', 'Available'),

          if (reach.returnPeriods != null && reach.returnPeriods!.isNotEmpty)
            _buildMetadataRow(
              'Return Periods',
              '${reach.returnPeriods!.length} periods available',
            ),

          _buildMetadataRow('Update Frequency', 'Every 6 hours'),

          if (reach.upstreamReaches?.isNotEmpty == true)
            _buildMetadataRow(
              'Upstream Reaches',
              reach.upstreamReaches!.length.toString(),
            ),

          if (reach.downstreamReaches?.isNotEmpty == true)
            _buildMetadataRow(
              'Downstream Reaches',
              reach.downstreamReaches!.length.toString(),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 20),
          SizedBox(height: 16),
          Text(
            'Loading river data...',
            style: TextStyle(
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load River Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _loadReachData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chart_bar,
              size: 48,
              color: CupertinoColors.secondaryLabel,
            ),
            SizedBox(height: 16),
            Text(
              'No Forecast Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This reach currently has no forecast data available.',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
