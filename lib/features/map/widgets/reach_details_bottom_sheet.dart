// lib/features/map/widgets/reach_details_bottom_sheet.dart

import 'package:flutter/cupertino.dart';
import '../models/selected_reach.dart';

/// Simple bottom sheet showing reach details with navigation to forecast
class ReachDetailsBottomSheet extends StatefulWidget {
  final SelectedReach selectedReach;
  final VoidCallback? onViewForecast;
  final VoidCallback? onClose;

  const ReachDetailsBottomSheet({
    super.key,
    required this.selectedReach,
    this.onViewForecast,
    this.onClose,
  });

  @override
  State<ReachDetailsBottomSheet> createState() =>
      _ReachDetailsBottomSheetState();
}

class _ReachDetailsBottomSheetState extends State<ReachDetailsBottomSheet> {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(),

            // Content
            _buildContent(),

            // Action button
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.map_pin,
            color: CupertinoColors.systemBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
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
                Text(
                  widget.selectedReach.streamOrderDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: widget.onClose,
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
          _buildInfoRow(
            'Reach ID',
            widget.selectedReach.reachId,
            CupertinoIcons.number,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Stream Order',
            widget.selectedReach.streamOrder.toString(),
            CupertinoIcons.tree,
          ),
          if (widget.selectedReach.hasLocation) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              'Location',
              widget.selectedReach.formattedLocation,
              CupertinoIcons.location,
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            'Coordinates',
            widget.selectedReach.coordinatesString,
            CupertinoIcons.location_circle,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CupertinoColors.systemGrey),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: widget.onViewForecast,
          child: const Text('View Forecast'),
        ),
      ),
    );
  }
}

/// Helper function to show the bottom sheet
void showReachDetailsBottomSheet(
  BuildContext context,
  SelectedReach selectedReach, {
  VoidCallback? onViewForecast,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => ReachDetailsBottomSheet(
      selectedReach: selectedReach,
      onViewForecast: onViewForecast,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
