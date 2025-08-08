// lib/features/forecast/pages/short_range_detail_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';
import '../widgets/forecast_detail_template.dart';
import '../widgets/flow_values_usage_guide.dart';

class ShortRangeDetailPage extends StatefulWidget {
  final String? reachId;

  const ShortRangeDetailPage({super.key, this.reachId});

  @override
  State<ShortRangeDetailPage> createState() => _ShortRangeDetailPageState();
}

class _ShortRangeDetailPageState extends State<ShortRangeDetailPage> {
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
        'forecastType': 'short_range',
        'title': 'Hourly Flow Chart',
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
          forecastType: 'short_range',
          title: 'Hourly Forecast',
          usageGuideOptions: FlowValuesUsageGuide.shortRangeOptions(),
          onChartTap: _navigateToHydrograph,
          showCurrentFlow: false,
          additionalContent: _buildShortRangeSpecificContent(reachProvider),
        );
      },
    );
  }

  Widget _buildShortRangeSpecificContent(ReachDataProvider reachProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(),
          const SizedBox(height: 16),
          _buildForecastDetails(reachProvider),
          const SizedBox(height: 20),
          _buildDataSourceInfo(reachProvider),
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
            'NOAA National Water Model Short Range Forecast',
            style: TextStyle(fontSize: 14, color: CupertinoColors.label),
          ),
          const SizedBox(height: 4),
          const Text(
            'Updated hourly • 18 hours of forecast data available',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastDetails(ReachDataProvider reachProvider) {
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
              const Text(
                'Hourly Forecast Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            'Purpose',
            'Emergency response and flash flood monitoring',
            CupertinoIcons.exclamationmark_triangle,
          ),
          const SizedBox(height: 8),
          _buildDetailItem(
            'Time Range',
            'Next 18 hours from current time',
            CupertinoIcons.clock,
          ),
          const SizedBox(height: 8),
          _buildDetailItem(
            'Update Frequency',
            'New forecast every hour',
            CupertinoIcons.arrow_clockwise,
          ),
          const SizedBox(height: 8),
          _buildDetailItem(
            'Best Use',
            'Real-time monitoring and immediate decision making',
            CupertinoIcons.checkmark_circle,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.lightbulb,
                  size: 14,
                  color: CupertinoColors.systemGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Most reliable for the next 6 hours, suitable for emergency planning',
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

  Widget _buildDetailItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: CupertinoColors.systemBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
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
        middle: Text('Hourly Forecast'),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 20),
            const SizedBox(height: 16),
            const Text(
              'Loading forecast data...',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Hourly Forecast'),
      ),
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
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () {
                  setState(() {
                    _isInitialized = false;
                  });
                  _loadReachData();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
