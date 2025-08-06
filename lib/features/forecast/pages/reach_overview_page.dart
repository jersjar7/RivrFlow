// lib/features/forecast/pages/reach_overview_page.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/models/reach_data.dart';
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

  // Phased loading approach for better performance
  Future<void> _loadReachData() async {
    if (widget.reachId == null) return;

    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );

    // Only load if we don't already have this reach loaded
    if (reachProvider.currentReach?.reachId != widget.reachId) {
      // PHASE 1: Load overview data first (fast - shows name, location, current flow)
      final overviewSuccess = await reachProvider.loadOverviewData(
        widget.reachId!,
      );

      if (overviewSuccess) {
        // PHASE 2: Load supplementary data in background (adds return periods, flow categories)
        // This runs after overview is displayed, so user sees immediate feedback
        reachProvider.loadSupplementaryData(widget.reachId!);
      }
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
          // Handle different loading phases
          if (!_isInitialized && reachProvider.isLoadingOverview) {
            return _buildInitialLoadingState();
          }

          if (reachProvider.errorMessage != null) {
            return _buildErrorState(reachProvider.errorMessage!);
          }

          if (!reachProvider.hasOverviewData) {
            return _buildEmptyState();
          }

          // Progressive content display based on loading phase
          return _buildProgressiveContent(reachProvider);
        },
      ),
    );
  }

  // Progressive content that shows data as it becomes available
  Widget _buildProgressiveContent(ReachDataProvider reachProvider) {
    final reach = reachProvider.currentReach!;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Station Header - Shows immediately after Phase 1
          SliverToBoxAdapter(child: _buildStationHeader(reach, reachProvider)),

          // Hero Flow Status Card - Shows immediately after Phase 1
          SliverToBoxAdapter(child: _buildFlowStatusSection(reachProvider)),

          // Forecast Categories Grid - Enhanced after Phase 2 (return periods loaded)
          SliverToBoxAdapter(
            child: _buildForecastCategoriesSection(reachProvider),
          ),

          // Chart Previews Section - Shows when forecast data is available
          SliverToBoxAdapter(child: _buildChartPreviewsSection(reachProvider)),

          // Station Metadata - Enhanced progressively
          SliverToBoxAdapter(
            child: _buildStationMetadata(reach, reachProvider),
          ),

          // Add some bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // IMPROVED: Uses cached formatter and shows loading states
  Widget _buildStationHeader(ReachData reach, ReachDataProvider reachProvider) {
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
          // Main title - Shows immediately
          Text(
            reach.displayName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label,
            ),
          ),

          const SizedBox(height: 8),

          // NEW: Use cached formatted location (fixes subtitle issue)
          Text(
            reachProvider.getFormattedLocation(),
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

  // NEW: Progressive flow status section with loading states
  Widget _buildFlowStatusSection(ReachDataProvider reachProvider) {
    return Column(
      children: [
        CurrentFlowStatusCard(
          expanded: true,
          onTap: () => _navigateToHydrograph('short_range'),
        ),

        // Show loading indicator for supplementary data
        if (reachProvider.isLoadingSupplementary)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 12),
                Text(
                  'Loading return period data...',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // NEW: Progressive forecast categories with enhanced functionality after Phase 2
  Widget _buildForecastCategoriesSection(ReachDataProvider reachProvider) {
    if (reachProvider.loadingPhase == 'overview' &&
        !reachProvider.hasSupplementaryData) {
      // Show loading shimmer for forecast categories during Phase 2
      return _buildForecastCategoriesShimmer();
    }

    return ForecastCategoryGrid(onCategoryTap: _navigateToForecastDetail);
  }

  // NEW: Loading shimmer for forecast categories
  Widget _buildForecastCategoriesShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forecast Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: List.generate(4, (index) => _buildCategoryShimmer()),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CupertinoActivityIndicator(radius: 12)),
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
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label.resolveFrom(context),
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ChartPreviewWidget(
              forecastType: forecastType,
              onTap: () => _navigateToHydrograph(forecastType),
              height: 120,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStationMetadata(
    ReachData reach,
    ReachDataProvider reachProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
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

          // NEW: Progressive display - only show when return periods are loaded
          if (reachProvider.hasSupplementaryData && reach.hasReturnPeriods)
            _buildMetadataRow(
              'Return Periods',
              '${reach.returnPeriods!.length} periods available',
            )
          else if (reachProvider.isLoadingSupplementary)
            _buildMetadataRow('Return Periods', 'Loading...'),

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
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Better initial loading state
  Widget _buildInitialLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 20),
          const SizedBox(height: 16),
          Text(
            'Loading river overview...',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This should only take a moment',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.chart_bar,
              size: 48,
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Forecast Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This reach currently has no forecast data available.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
