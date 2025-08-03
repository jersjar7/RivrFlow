// lib/features/map/widgets/reach_details_bottom_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rivrflow/features/map/widgets/components/return_periods_info_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/forecast_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/models/reach_data.dart';
import '../../../core/constants.dart';
import '../models/selected_reach.dart';

/// Bottom sheet that shows reach details using core services
/// Progressively loads data: immediate vector tile info → full NOAA data
class ReachDetailsBottomSheet extends StatefulWidget {
  final SelectedReach selectedReach;
  final VoidCallback? onViewForecast;
  final Function(String)? onAddToFavorites;

  const ReachDetailsBottomSheet({
    super.key,
    required this.selectedReach,
    this.onViewForecast,
    this.onAddToFavorites,
  });

  @override
  State<ReachDetailsBottomSheet> createState() =>
      _ReachDetailsBottomSheetState();
}

class _ReachDetailsBottomSheetState extends State<ReachDetailsBottomSheet> {
  final ForecastService _forecastService = ForecastService();

  // Progressive loading states
  bool _isLoadingFullData = false;
  String? _errorMessage;
  ReachData? _reachData;

  // Current flow display
  double? _currentFlow;
  String? _flowCategory;

  @override
  void initState() {
    super.initState();
    _loadFullReachData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildHeader(), _buildContent(), _buildActions()],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Stream order icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.getStreamOrderColor(
                widget.selectedReach.streamOrder,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              AppConstants.getStreamOrderIcon(widget.selectedReach.streamOrder),
              color: AppConstants.getStreamOrderColor(
                widget.selectedReach.streamOrder,
              ),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedReach.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.selectedReach.streamOrderDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),

          // Status widget (if you want to keep it)
          _buildStatusWidget(),

          const SizedBox(width: 8),

          // 🔧 Add close button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemGrey3,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildBasicInfo(),
          if (_errorMessage != null) _buildErrorCard(),
          if (_reachData != null) _buildDetailedInfo(),
          if (_currentFlow != null) _buildFlowInfo(),
          // Show message when no flow data available (response = -9999)
          if (_reachData != null &&
              _currentFlow == null &&
              _errorMessage == null)
            _buildNoFlowDataCard(),
          // Show message when no return period data available (response = null)
          if (_reachData != null &&
              !_reachData!.hasReturnPeriods &&
              _errorMessage == null)
            _buildNoReturnPeriodCard(),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Reach ID', widget.selectedReach.reachId),
          const SizedBox(height: 8),
          _buildInfoRow('Stream Order', '${widget.selectedReach.streamOrder}'),
          const SizedBox(height: 8),
          _buildInfoRow('Coordinates', widget.selectedReach.coordinatesString),
          if (widget.selectedReach.hasLocation) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Location', widget.selectedReach.formattedLocation),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedInfo() {
    final reach = _reachData!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.info_circle,
                color: CupertinoColors.systemBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'NOAA National Water Model Data',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInfoRow('River Name', reach.riverName),
          if (reach.formattedLocation.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Location', reach.formattedLocation),
          ],

          // Available Forecasts Section
          const SizedBox(height: 8),
          _buildForecastsInfoRow(reach.availableForecasts),

          // Return periods section
          if (reach.hasReturnPeriods) ...[
            const SizedBox(height: 8),
            _buildReturnPeriodsInfoRow(reach.returnPeriods!),
          ],
        ],
      ),
    );
  }

  Widget _buildForecastsInfoRow(List<String> availableForecasts) {
    final orderedForecasts = AppConstants.getOrderedForecasts(
      availableForecasts,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            'Available Forecasts',
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            children: [
              for (int i = 0; i < orderedForecasts.length; i++) ...[
                Builder(
                  builder: (context) {
                    final forecastType = orderedForecasts[i];
                    final forecastInfo = AppConstants.getForecastInfo(
                      forecastType,
                    );
                    if (forecastInfo == null) return const SizedBox.shrink();

                    return GestureDetector(
                      onTap: () => _showForecastInfo(forecastInfo),
                      child: Text(
                        forecastInfo.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.link,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    );
                  },
                ),
                if (i < orderedForecasts.length - 1)
                  const Text(
                    ', ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showForecastInfo(ForecastInfo forecastInfo) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(forecastInfo.name),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _buildDialogInfoRow('Duration', forecastInfo.duration),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Frequency', forecastInfo.frequency),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Purpose', forecastInfo.purpose),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Type', forecastInfo.type),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Use Case', forecastInfo.useCase),
            if (forecastInfo.sourceUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSourcesSection(forecastInfo.sourceUrls),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesSection(List<String> sourceUrls) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Keep "Sources:" left-aligned
      children: [
        const Text(
          'Sources:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 4),
        // Center only the links section
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: sourceUrls
                .map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _launchUrl(url),
                      minimumSize: Size(0, 0),
                      child: Text(
                        _getDisplayUrl(url),
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.link,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      print('Attempting to launch URL: $urlString'); // Debug log
      final Uri url = Uri.parse(urlString);

      if (await canLaunchUrl(url)) {
        print('canLaunchUrl returned true, launching...'); // Debug log
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          // Add these parameters for better iOS compatibility
          webViewConfiguration: const WebViewConfiguration(),
        );
        print('URL launched successfully'); // Debug log
      } else {
        print('canLaunchUrl returned false for: $urlString'); // Debug log
        // Try launching anyway as a fallback
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching URL: $e'); // Debug log
      // Show user-friendly error
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Unable to Open Link'),
            content: const Text('Could not open the link in your browser.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: CupertinoColors.label),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _getDisplayUrl(String url) {
    // Extract readable domain name from URL
    try {
      final uri = Uri.parse(url);
      String domain = uri.host;

      // Remove 'www.' prefix if present
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }

      return domain;
    } catch (e) {
      return url;
    }
  }

  Widget _buildReturnPeriodsInfoRow(Map<int, double> returnPeriods) {
    // Sort and format the return period years
    final sortedYears = returnPeriods.keys.toList()..sort();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: const Text(
            'Return Periods',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            children: [
              // Display the years as comma-separated text (not clickable)
              for (int i = 0; i < sortedYears.length; i++) ...[
                Text(
                  '${sortedYears[i]}yr',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (i < sortedYears.length - 1)
                  const Text(
                    ', ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
              ],
              // Add a space before the info icon
              const SizedBox(width: 4),
              // Only the info icon is clickable
              GestureDetector(
                onTap: () => _showReturnPeriodsInfo(returnPeriods),
                child: const Icon(
                  CupertinoIcons.info_circle,
                  size: 16,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReturnPeriodsInfo(Map<int, double> returnPeriods) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) =>
          ReturnPeriodsInfoSheet(returnPeriods: returnPeriods),
    );
  }

  Widget _buildFlowInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.getFlowCategoryColor(
          _flowCategory,
        ).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppConstants.getFlowCategoryIcon(_flowCategory),
                color: AppConstants.getFlowCategoryColor(_flowCategory),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Flow',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.getFlowCategoryColor(_flowCategory),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                '${_currentFlow!.toStringAsFixed(0)} CFS',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.getFlowCategoryColor(_flowCategory),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _flowCategory ?? 'Unknown',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // View Forecast button (primary action)
          Expanded(
            flex: 2,
            child: CupertinoButton.filled(
              onPressed: widget.onViewForecast,
              child: const Text('View Forecast'),
            ),
          ),

          const SizedBox(width: 12),

          // Add to Favorites button
          Expanded(
            child: CupertinoButton(
              color: CupertinoColors.systemGrey5,
              onPressed: () =>
                  widget.onAddToFavorites?.call(widget.selectedReach.reachId),
              child: const Icon(
                CupertinoIcons.heart,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // More options
          CupertinoButton(
            color: CupertinoColors.systemGrey5,
            onPressed: _showMoreOptions,
            child: const Icon(
              CupertinoIcons.ellipsis,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget() {
    if (_isLoadingFullData) {
      return const CupertinoActivityIndicator(radius: 8);
    }

    // When done loading, just show nothing
    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildNoFlowDataCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Current flow data is not available for this stream.',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReturnPeriodCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle,
            color: CupertinoColors.systemOrange,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Return period values are not available for this stream.',
              style: TextStyle(
                color: CupertinoColors.systemOrange,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Core service integration methods
  Future<void> _loadFullReachData() async {
    setState(() {
      _isLoadingFullData = true;
      _errorMessage = null;
    });

    try {
      print(
        'BOTTOM_SHEET: Loading full data for reach: ${widget.selectedReach.reachId}',
      );

      // Use ForecastService to load complete data
      final forecast = await _forecastService.loadCompleteReachData(
        widget.selectedReach.reachId,
      );

      // Extract current flow using service helper
      final currentFlow = _forecastService.getCurrentFlow(forecast);
      final flowCategory = _forecastService.getFlowCategory(forecast);

      setState(() {
        _reachData = forecast.reach;
        _currentFlow = currentFlow;
        _flowCategory = flowCategory;
        _isLoadingFullData = false;
      });

      print('BOTTOM_SHEET: ✅ Successfully loaded full reach data');
    } catch (error) {
      print('BOTTOM_SHEET: ❌ Error loading full data: $error');

      // Use ErrorService for user-friendly error messages
      final userMessage = ErrorService.handleError(
        error,
        context: 'loadReachDetails',
      );

      setState(() {
        _errorMessage = userMessage;
        _isLoadingFullData = false;
      });
    }
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${widget.selectedReach.displayName} Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _copyReachInfo();
            },
            child: const Text('Copy Reach Info'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareReachLocation();
            },
            child: const Text('Share Location'),
          ),
          if (_reachData != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _refreshData();
              },
              child: const Text('Refresh Data'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _copyReachInfo() {
    final reachInfo = _buildReachInfoText();

    Clipboard.setData(ClipboardData(text: reachInfo)).then((_) {
      // Show confirmation to user
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Copied'),
            content: const Text('Reach information copied to clipboard'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    });

    print('BOTTOM_SHEET: Copied reach info to clipboard');
  }

  void _shareReachLocation() async {
    final locationText = _buildLocationShareText();

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: locationText,
          subject: 'River Location: ${widget.selectedReach.displayName}',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        print('BOTTOM_SHEET: Successfully shared location');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('BOTTOM_SHEET: User dismissed share dialog');
      }
    } catch (e) {
      print('BOTTOM_SHEET: Error sharing location: $e');
    }
  }

  // Helper method to build comprehensive reach information text
  String _buildReachInfoText() {
    final buffer = StringBuffer();

    // Basic info
    buffer.writeln('🏞️ ${widget.selectedReach.displayName}');
    buffer.writeln('📍 Reach ID: ${widget.selectedReach.reachId}');
    buffer.writeln('🌊 Stream Order: ${widget.selectedReach.streamOrder}');
    buffer.writeln('📍 Coordinates: ${widget.selectedReach.coordinatesString}');

    if (widget.selectedReach.hasLocation) {
      buffer.writeln('📍 Location: ${widget.selectedReach.formattedLocation}');
    }

    // NOAA data (if available)
    if (_reachData != null) {
      buffer.writeln('\n📊 NOAA Data:');
      buffer.writeln('🏞️ River: ${_reachData!.riverName}');

      if (_reachData!.formattedLocation.isNotEmpty) {
        buffer.writeln('📍 ${_reachData!.formattedLocation}');
      }

      // Current flow (if available)
      if (_currentFlow != null) {
        buffer.writeln(
          '💧 Current Flow: ${_currentFlow!.toStringAsFixed(0)} CFS',
        );
        if (_flowCategory != null) {
          buffer.writeln('⚠️ Risk Level: $_flowCategory');
        }
      }

      // Available forecasts
      if (_reachData!.availableForecasts.isNotEmpty) {
        buffer.writeln(
          '📈 Available Forecasts: ${_reachData!.availableForecasts.join(', ')}',
        );
      }

      // Return periods (if available)
      if (_reachData!.hasReturnPeriods) {
        final years = (_reachData!.returnPeriods!.keys.toList()..sort())
            .map((year) => '${year}yr')
            .join(', ');
        buffer.writeln('📊 Return Periods: $years');
      }
    }

    buffer.writeln('\n📱 Shared from RivrFlow');

    return buffer.toString();
  }

  // Helper method to build location-focused share text
  String _buildLocationShareText() {
    final buffer = StringBuffer();

    buffer.writeln('📍 ${widget.selectedReach.displayName}');

    if (_reachData?.riverName != null &&
        _reachData!.riverName != widget.selectedReach.displayName) {
      buffer.writeln('🏞️ ${_reachData!.riverName}');
    }

    buffer.writeln(
      '\n📍 Coordinates: ${widget.selectedReach.coordinatesString}',
    );

    if (widget.selectedReach.hasLocation) {
      buffer.writeln('📍 ${widget.selectedReach.formattedLocation}');
    }

    // Add current flow if available (important for safety)
    if (_currentFlow != null && _flowCategory != null) {
      buffer.writeln(
        '\n💧 Current Flow: ${_currentFlow!.toStringAsFixed(0)} CFS ($_flowCategory)',
      );
    }

    // Add Google Maps link
    final coords = widget.selectedReach.coordinatesString.split(', ');
    if (coords.length == 2) {
      final lat = coords[0];
      final lng = coords[1];
      buffer.writeln('\n🗺️ View on Google Maps:');
      buffer.writeln('https://maps.google.com/?q=$lat,$lng');
    }

    buffer.writeln('\n📱 Shared from RivrFlow');

    return buffer.toString();
  }

  Future<void> _refreshData() async {
    // Force refresh using ForecastService
    try {
      final freshForecast = await _forecastService.refreshReachData(
        widget.selectedReach.reachId,
      );

      setState(() {
        _reachData = freshForecast.reach;
        _currentFlow = _forecastService.getCurrentFlow(freshForecast);
        _flowCategory = _forecastService.getFlowCategory(freshForecast);
      });
    } catch (error) {
      final userMessage = ErrorService.handleError(
        error,
        context: 'refreshData',
      );
      setState(() {
        _errorMessage = userMessage;
      });
    }
  }
}

/// Helper function to show the bottom sheet
void showReachDetailsBottomSheet(
  BuildContext context,
  SelectedReach selectedReach, {
  VoidCallback? onViewForecast,
  Function(String)? onAddToFavorites,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => ReachDetailsBottomSheet(
      selectedReach: selectedReach,
      onViewForecast: onViewForecast,
      onAddToFavorites: onAddToFavorites,
    ),
  );
}
