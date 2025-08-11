// lib/features/forecast/widgets/flood_categories_info_sheet.dart

import 'package:flutter/cupertino.dart';
import '../../../core/constants.dart';
import '../../../core/services/flow_unit_preference_service.dart';

/// Educational bottom sheet that explains flood risk categories based on return periods
class FloodCategoriesInfoSheet extends StatelessWidget {
  final Map<int, double>? returnPeriods;

  const FloodCategoriesInfoSheet({super.key, this.returnPeriods});

  // Get current flow units from preference service
  String _getCurrentFlowUnit() {
    final currentUnit = FlowUnitPreferenceService().currentFlowUnit;
    return currentUnit == 'CMS' ? 'CMS' : 'CFS';
  }

  // Convert return period value to user's preferred unit
  double? _convertReturnPeriod(double? cmsValue) {
    if (cmsValue == null) return null;

    final unitService = FlowUnitPreferenceService();
    final currentUnit = unitService.currentFlowUnit;

    // Return periods are stored in CMS, convert to user preference
    return unitService.convertFlow(cmsValue, 'CMS', currentUnit);
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
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Explanation
                    _buildExplanationSection(),

                    const SizedBox(height: 20),

                    // Categories
                    _buildFloodCategoryItem(
                      'Normal',
                      '0 - 2 year return period',
                      'Typical flow conditions with no flood risk',
                      AppConstants.returnPeriodNormalBg,
                      CupertinoColors.systemGrey,
                      CupertinoIcons.checkmark_circle_fill,
                      null,
                    ),

                    _buildFloodCategoryItem(
                      'Action',
                      '2 - 5 year return period',
                      'Time to prepare - minor flooding possible',
                      AppConstants.returnPeriodActionBg,
                      CupertinoColors.systemYellow,
                      CupertinoIcons.exclamationmark_triangle,
                      _convertReturnPeriod(returnPeriods?[2]),
                    ),

                    _buildFloodCategoryItem(
                      'Moderate',
                      '5 - 10 year return period',
                      'Some property damage and evacuations may be needed',
                      AppConstants.returnPeriodModerateBg,
                      CupertinoColors.systemOrange,
                      CupertinoIcons.exclamationmark_triangle_fill,
                      _convertReturnPeriod(returnPeriods?[5]),
                    ),

                    _buildFloodCategoryItem(
                      'Major',
                      '10 - 25 year return period',
                      'Extensive property damage and life-threatening flooding',
                      AppConstants.returnPeriodMajorBg,
                      CupertinoColors.systemRed,
                      CupertinoIcons.exclamationmark_octagon_fill,
                      _convertReturnPeriod(returnPeriods?[10]),
                    ),

                    _buildFloodCategoryItem(
                      'Extreme',
                      '25+ year return period',
                      'Catastrophic flooding with severe danger to life and property',
                      AppConstants.returnPeriodExtremeBg,
                      CupertinoColors.systemPurple,
                      CupertinoIcons.xmark_octagon_fill,
                      _convertReturnPeriod(returnPeriods?[25]),
                    ),

                    const SizedBox(height: 20),

                    // Note
                    _buildDisclaimerNote(),

                    const SizedBox(height: 32), // Bottom padding for scrolling
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Flood Risk Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildExplanationSection() {
    return const Text(
      'These categories help assess flood risk based on streamflow return periods. Return periods indicate how often flows of this magnitude typically occur.',
      style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
    );
  }

  Widget _buildFloodCategoryItem(
    String title,
    String subtitle,
    String description,
    Color backgroundColor,
    Color iconColor,
    IconData icon,
    double? thresholdFlow, // Converted to user's preferred unit
  ) {
    // Get current flow unit for display
    final currentUnit = _getCurrentFlowUnit();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                    if (thresholdFlow != null) ...[
                      const Spacer(),
                      Text(
                        '${_formatFlowValue(thresholdFlow)} $currentUnit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Note: These categories are based on statistical analysis of historical flow data. Actual flood impacts may vary depending on local conditions, infrastructure, and other factors.',
        style: TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel,
          fontStyle: FontStyle.italic,
        ),
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
}
