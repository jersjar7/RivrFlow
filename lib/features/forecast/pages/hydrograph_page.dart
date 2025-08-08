// lib/features/forecast/pages/hydrograph_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';
import '../widgets/interactive_chart.dart';

class HydrographPage extends StatefulWidget {
  final String? reachId;
  final String? forecastType;
  final String? title;

  const HydrographPage({
    super.key,
    this.reachId,
    this.forecastType,
    this.title,
  });

  @override
  State<HydrographPage> createState() => _HydrographPageState();
}

class _HydrographPageState extends State<HydrographPage> {
  String? _reachId;
  String? _forecastType;
  String? _pageTitle;
  bool _isInitialized = false;
  bool _showReturnPeriods = true;
  final bool _showTooltips = true;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    // Get parameters from widget or navigation arguments
    _reachId = widget.reachId;
    _forecastType = widget.forecastType;
    _pageTitle = widget.title;

    if (_reachId == null || _forecastType == null) {
      // Try to get from navigation arguments
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null) {
          setState(() {
            _reachId = args['reachId'] as String?;
            _forecastType = args['forecastType'] as String?;
            _pageTitle = args['title'] as String?;
          });
        }
        _loadData();
      });
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_reachId == null || _forecastType == null) return;

    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );

    // Load reach data if not already available
    if (!reachProvider.hasData ||
        reachProvider.currentReach?.reachId != _reachId) {
      try {
        await reachProvider.loadReach(_reachId!);
      } catch (e) {
        // Error handling managed by provider
      }
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _handleRefresh() async {
    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );
    await reachProvider.refreshCurrentReach();
  }

  void _toggleReturnPeriods() {
    setState(() {
      _showReturnPeriods = !_showReturnPeriods;
    });
  }

  void _exportChart() {
    // TODO: Implement chart export functionality
    HapticFeedback.mediumImpact();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Export Chart'),
        content: const Text('Chart export functionality coming soon!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showChartInfo() {
    final reachProvider = Provider.of<ReachDataProvider>(
      context,
      listen: false,
    );
    final reach = reachProvider.currentReach;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(reach?.displayName ?? 'Chart Information'),
        message: Text(_buildChartInfoMessage()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('View Data Source'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _exportChart();
            },
            child: const Text('Export Chart'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  String _buildChartInfoMessage() {
    final typeNames = {
      'short_range': 'Short Range (Hourly)',
      'medium_range': 'Medium Range (Daily)',
      'long_range': 'Long Range (Weekly)',
    };

    final typeName = typeNames[_forecastType] ?? _forecastType?.toUpperCase();

    return '$typeName Forecast\nShowing: All Available Data\nData Source: NOAA National Water Model';
  }

  @override
  Widget build(BuildContext context) {
    if (_reachId == null || _forecastType == null) {
      return _buildErrorPage('Missing required parameters');
    }

    if (!_isInitialized) {
      return _buildLoadingPage();
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_pageTitle ?? 'Hydrograph'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showChartInfo,
              child: const Icon(CupertinoIcons.info_circle),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _handleRefresh,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ],
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

            return _buildChartContent(reachProvider);
          },
        ),
      ),
    );
  }

  Widget _buildChartContent(ReachDataProvider reachProvider) {
    return Column(
      children: [
        // Chart Controls
        _buildChartControls(),

        // Main Chart Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: InteractiveChart(
              key: ValueKey('$_reachId-$_forecastType-$_showReturnPeriods'),
              reachId: _reachId!,
              forecastType: _forecastType!,
              showReturnPeriods: _showReturnPeriods,
              showTooltips: _showTooltips,
              reachProvider: reachProvider,
            ),
          ),
        ),

        // Chart Legend/Info
        _buildChartLegend(reachProvider),
      ],
    );
  }

  Widget _buildChartControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Return Periods Toggle
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _showReturnPeriods
                  ? CupertinoColors.systemBlue
                  : CupertinoColors.systemGrey5.resolveFrom(context),
              onPressed: _toggleReturnPeriods,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    size: 16,
                    color: _showReturnPeriods
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Return Periods',
                    style: TextStyle(
                      fontSize: 13,
                      color: _showReturnPeriods
                          ? CupertinoColors.white
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Export Button
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            onPressed: _exportChart,
            child: Icon(
              CupertinoIcons.share,
              size: 16,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(ReachDataProvider reachProvider) {
    final reach = reachProvider.currentReach;
    if (reach == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Legend
          Row(
            children: [
              _buildLegendItem('Flow Data', CupertinoColors.systemBlue),
              const SizedBox(width: 16),
              if (_showReturnPeriods)
                _buildLegendItem('Return Periods', CupertinoColors.systemRed),
              const Spacer(),
              Text(
                'Tap and drag to pan • Pinch to zoom',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Data Info
          Row(
            children: [
              Icon(
                CupertinoIcons.location,
                size: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 4),
              Text(
                reach.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                CupertinoIcons.clock,
                size: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Updated ${_getUpdateTime()}',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  String _getUpdateTime() {
    // This would return the actual update time from the data
    return 'just now';
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 20),
          SizedBox(height: 16),
          Text(
            'Loading chart data...',
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
              'Unable to load chart',
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
            const Text(
              'No chart data available',
              style: TextStyle(
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

  Widget _buildLoadingPage() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_pageTitle ?? 'Hydrograph'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 16),
              Text(
                'Loading hydrograph...',
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
      navigationBar: CupertinoNavigationBar(
        middle: Text(_pageTitle ?? 'Hydrograph'),
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
                  'Unable to load hydrograph',
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
