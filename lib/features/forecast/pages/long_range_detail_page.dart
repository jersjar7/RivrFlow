// lib/features/forecast/pages/long_range_detail_page.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';
import '../widgets/forecast_detail_template.dart';
import '../widgets/flow_values_usage_guide.dart';
import '../widgets/long_range_calendar.dart';

class LongRangeDetailPage extends StatefulWidget {
  final String? reachId;

  const LongRangeDetailPage({super.key, this.reachId});

  @override
  State<LongRangeDetailPage> createState() => _LongRangeDetailPageState();
}

class _LongRangeDetailPageState extends State<LongRangeDetailPage> {
  String? _reachId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    // Get reachId from widget or navigation arguments
    _reachId = widget.reachId;

    if (_reachId == null) {
      // Try to get from navigation arguments
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args['reachId'] != null) {
          setState(() {
            _reachId = args['reachId'] as String;
          });
        }
        _loadReachData();
      });
    } else {
      _loadReachData();
    }
  }

  Future<void> _loadReachData() async {
    if (_reachId == null) return;

    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );

    // Load reach data if not already loaded or if different reach
    if (!reachProvider.hasData ||
        reachProvider.currentReach?.reachId != _reachId) {
      try {
        await reachProvider.loadReach(_reachId!);
      } catch (e) {
        // Error handling is managed by the provider
      }
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _navigateToHydrograph() {
    if (_reachId == null) return;

    Navigator.pushNamed(
      context,
      '/hydrograph',
      arguments: {
        'reachId': _reachId,
        'forecastType': 'long_range',
        'title': 'Long Range Hydrograph',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reachId == null) {
      return _buildErrorPage('No reach selected');
    }

    if (!_isInitialized) {
      return _buildLoadingPage();
    }

    return Consumer<ReachDataProvider>(
      builder: (context, reachProvider, child) {
        return ForecastDetailTemplate(
          reachId: _reachId!,
          forecastType: 'long_range',
          title: 'Long Range Forecast',
          usageGuideOptions: FlowValuesUsageGuide.longRangeOptions(),
          onChartTap: _navigateToHydrograph,
          showCurrentFlow: false,

          // NEW: Replace flow timeline cards with calendar widget
          customTimelineWidget: LongRangeCalendar(
            reachId: _reachId!,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ), // Template handles padding
          ),

          additionalContent: _buildLongRangeSpecificContent(reachProvider),
        );
      },
    );
  }

  Widget _buildLongRangeSpecificContent(ReachDataProvider reachProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataSourceInfo(reachProvider),
          const SizedBox(height: 16),
          _buildForecastConfidence(),
          const SizedBox(height: 16),
          _buildSeasonalTrends(reachProvider),
          const SizedBox(height: 16),
          _buildClimateFactors(),
          const SizedBox(height: 16),
          _buildPlanningRecommendations(),
        ],
      ),
    );
  }

  Widget _buildDataSourceInfo(ReachDataProvider reachProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.info_circle,
                size: 16,
                color: CupertinoColors.systemBlue,
              ),
              const SizedBox(width: 8),
              const Text(
                'Data Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'NOAA National Water Model Long Range Forecast',
            style: TextStyle(fontSize: 14, color: CupertinoColors.label),
          ),
          const SizedBox(height: 4),
          Text(
            'Updated daily • Up to 30 days of forecast data available',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastConfidence() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemOrange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.chart_bar_alt_fill,
                size: 16,
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 8),
              const Text(
                'Forecast Confidence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildConfidenceMetric('Week 1', '65%', CupertinoColors.systemGreen),
          const SizedBox(height: 8),
          _buildConfidenceMetric('Week 2', '55%', CupertinoColors.systemYellow),
          const SizedBox(height: 8),
          _buildConfidenceMetric(
            'Weeks 3-4',
            '45%',
            CupertinoColors.systemOrange,
          ),
          const SizedBox(height: 8),
          _buildConfidenceMetric(
            'Beyond Week 4',
            '35%',
            CupertinoColors.systemRed,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 14,
                  color: CupertinoColors.systemYellow,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Long range forecasts show general trends, not specific daily conditions',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceMetric(
    String timeRange,
    String confidence,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          timeRange,
          style: const TextStyle(fontSize: 14, color: CupertinoColors.label),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            confidence,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonalTrends(ReachDataProvider reachProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: CupertinoColors.systemPurple,
              ),
              const SizedBox(width: 8),
              const Text(
                'Seasonal Trends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTrendItem(
            'Overall Pattern',
            'Flows trending toward seasonal average',
            CupertinoIcons.arrow_right_circle,
            CupertinoColors.systemBlue,
          ),
          const SizedBox(height: 8),
          _buildTrendItem(
            'Variability',
            'Moderate fluctuations expected',
            CupertinoIcons.waveform,
            CupertinoColors.systemTeal,
          ),
          const SizedBox(height: 8),
          _buildTrendItem(
            'Peak Period',
            'Review calendar for highest flow days',
            CupertinoIcons.arrow_up_circle,
            CupertinoColors.systemOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildClimateFactors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemIndigo.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.globe,
                size: 16,
                color: CupertinoColors.systemIndigo,
              ),
              const SizedBox(width: 8),
              const Text(
                'Climate Factors',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildClimateItem(
            'La Niña/El Niño',
            'Neutral conditions expected',
            CupertinoIcons.globe,
            CupertinoColors.systemGreen,
          ),
          const SizedBox(height: 8),
          _buildClimateItem(
            'Seasonal Moisture',
            'Normal precipitation patterns',
            CupertinoIcons.cloud_drizzle,
            CupertinoColors.systemBlue,
          ),
          const SizedBox(height: 8),
          _buildClimateItem(
            'Temperature Trends',
            'Above average temperatures likely',
            CupertinoIcons.thermometer,
            CupertinoColors.systemRed,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningRecommendations() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.lightbulb,
                size: 16,
                color: CupertinoColors.systemGreen,
              ),
              const SizedBox(width: 8),
              const Text(
                'Planning Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            'Water Management',
            'Tap calendar days to view detailed hourly flow data',
            CupertinoIcons.drop_triangle,
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            'Recreation Planning',
            'Use flow categories in calendar for optimal timing',
            CupertinoIcons.person_2,
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            'Infrastructure',
            'Plan maintenance during normal flow periods',
            CupertinoIcons.wrench,
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            'Agriculture',
            'Monitor calendar for irrigation timing',
            CupertinoIcons.leaf_arrow_circlepath,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClimateItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(
    String title,
    String description,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CupertinoColors.systemGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPage() {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Long Range Forecast'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 16),
              Text(
                'Loading forecast data...',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Long Range Forecast'),
      ),
      child: SafeArea(
        child: Center(
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
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
