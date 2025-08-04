// lib/features/map/widgets/reach_details_bottom_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/map/widgets/components/return_periods_info_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/forecast_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/models/reach_data.dart';
import '../../../core/providers/favorites_provider.dart'; // NEW: Import FavoritesProvider
import '../../../core/constants.dart';
import '../models/selected_reach.dart';

/// Bottom sheet that shows reach details using core services
/// Progressively loads data: immediate vector tile info → full NOAA data
/// Now integrated with favorites system
class ReachDetailsBottomSheet extends StatefulWidget {
  final SelectedReach selectedReach;
  final VoidCallback? onViewForecast;
  // NOTE: onAddToFavorites callback removed - now handled internally

  const ReachDetailsBottomSheet({
    super.key,
    required this.selectedReach,
    this.onViewForecast,
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

  // NEW: Favorites loading state
  bool _isTogglingFavorite = false;

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

          // Close button
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
          if (reach.availableForecasts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Forecasts', reach.availableForecasts.join(', ')),
          ],
          if (reach.hasReturnPeriods) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Return Periods',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showReturnPeriodsInfo(reach),
                  child: const Icon(
                    CupertinoIcons.info_circle,
                    color: CupertinoColors.activeBlue,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildReturnPeriodsRow(reach),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnPeriodsRow(ReachData reach) {
    final periods = reach.returnPeriods!;
    final sortedYears = periods.keys.toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: sortedYears.map((year) {
        final value = periods[year]!;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${year}yr: ${value.toStringAsFixed(0)} CMS',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  void _showReturnPeriodsInfo(ReachData reach) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => ReturnPeriodsInfoSheet(
        returnPeriods: reach.returnPeriods!, // Pass the map directly
      ),
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

  // NEW: Updated actions with integrated favorites functionality
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // View Forecast button (primary action)
          Expanded(
            flex: 2,
            child: CupertinoButton.filled(
              onPressed: () {
                // Navigate to reach overview page
                Navigator.pushNamed(
                  context,
                  '/reach-overview',
                  arguments: {'reachId': widget.selectedReach.reachId},
                );
              },
              child: const Text('View Forecast'),
            ),
          ),

          const SizedBox(width: 12),

          // NEW: Integrated heart button with FavoritesProvider
          Expanded(
            child: Consumer<FavoritesProvider>(
              builder: (context, favoritesProvider, child) {
                final isFavorited = favoritesProvider.isFavorite(
                  widget.selectedReach.reachId,
                );
                final isRefreshing = favoritesProvider.isRefreshing(
                  widget.selectedReach.reachId,
                );

                return CupertinoButton(
                  color: isFavorited
                      ? CupertinoColors.systemRed.withOpacity(0.1)
                      : CupertinoColors.systemGrey5,
                  onPressed: _isTogglingFavorite
                      ? null
                      : () => _toggleFavorite(favoritesProvider),
                  child: _isTogglingFavorite || isRefreshing
                      ? const CupertinoActivityIndicator(radius: 8)
                      : Icon(
                          isFavorited
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: isFavorited
                              ? CupertinoColors.systemRed
                              : CupertinoColors.systemGrey,
                        ),
                );
              },
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

  // NEW: Handle favorite toggle with loading state and feedback
  Future<void> _toggleFavorite(FavoritesProvider favoritesProvider) async {
    final reachId = widget.selectedReach.reachId;
    final isFavorited = favoritesProvider.isFavorite(reachId);

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      bool success;
      if (isFavorited) {
        success = await favoritesProvider.removeFavorite(reachId);
        if (success) {
          _showFeedback('Removed from favorites');
        }
      } else {
        success = await favoritesProvider.addFavorite(reachId);
        if (success) {
          _showFeedback('Added to favorites');
        }
      }

      if (!success) {
        _showFeedback('Failed to update favorites', isError: true);
      }
    } catch (e) {
      print('BOTTOM_SHEET: Error toggling favorite: $e');
      _showFeedback('Failed to update favorites', isError: true);
    }

    setState(() {
      _isTogglingFavorite = false;
    });
  }

  // NEW: Show user feedback for favorite actions
  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
              _shareLocation();
            },
            child: const Text('Share Location'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openInMaps();
            },
            child: const Text('Open in Maps'),
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

  Future<void> _copyReachInfo() async {
    try {
      final text = _buildReachInfoText();
      await Clipboard.setData(ClipboardData(text: text));
      _showFeedback('Reach information copied to clipboard');
    } catch (e) {
      print('BOTTOM_SHEET: Error copying reach info: $e');
    }
  }

  Future<void> _shareLocation() async {
    try {
      final text = _buildLocationShareText();
      await Share.share(text, subject: widget.selectedReach.displayName);
    } catch (e) {
      print('BOTTOM_SHEET: Error sharing location: $e');
    }
  }

  Future<void> _openInMaps() async {
    try {
      final coords = widget.selectedReach.coordinatesString.split(', ');
      if (coords.length == 2) {
        final lat = coords[0];
        final lng = coords[1];
        final url = 'https://maps.google.com/?q=$lat,$lng';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      }
    } catch (e) {
      print('BOTTOM_SHEET: Error opening maps: $e');
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
}

/// Helper function to show the bottom sheet (updated signature)
void showReachDetailsBottomSheet(
  BuildContext context,
  SelectedReach selectedReach, {
  VoidCallback? onViewForecast,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => ReachDetailsBottomSheet(
      selectedReach: selectedReach,
      onViewForecast: onViewForecast,
    ),
  );
}
