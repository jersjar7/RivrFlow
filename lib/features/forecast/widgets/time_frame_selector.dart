// lib/features/forecast/widgets/time_frame_selector.dart

import 'package:flutter/cupertino.dart';

class TimeFrameSelector extends StatelessWidget {
  final List<TimeFrameOption> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final EdgeInsets? padding;

  const TimeFrameSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Create a map for the segmented control
    final Map<String, Widget> segmentWidgets = {};

    for (final option in options) {
      segmentWidgets[option.value] = _buildSegmentContent(option);
    }

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Control
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              children: segmentWidgets,
              groupValue: selectedValue,
              onValueChanged: (String? value) {
                if (value != null) {
                  onChanged(value);
                }
              },
              backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
              thumbColor: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.all(4),
            ),
          ),

          // Selected option description
          if (_getSelectedOption() != null) ...[
            const SizedBox(height: 12),
            _buildDescription(_getSelectedOption()!),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentContent(TimeFrameOption option) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            option.displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (option.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              option.subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(TimeFrameOption option) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            option.icon ?? CupertinoIcons.clock,
            size: 16,
            color: CupertinoColors.systemBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.description,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TimeFrameOption? _getSelectedOption() {
    try {
      return options.firstWhere((option) => option.value == selectedValue);
    } catch (e) {
      return null;
    }
  }

  // Static factory methods for common forecast types
  static List<TimeFrameOption> shortRangeOptions() {
    return [
      TimeFrameOption(
        value: '12h',
        displayName: '12H',
        subtitle: 'Hours',
        description: 'Next 12 hours - Immediate planning and safety',
        icon: CupertinoIcons.clock,
        dataPoints: 12,
        intervalMinutes: 60,
      ),
      TimeFrameOption(
        value: '24h',
        displayName: '24H',
        subtitle: 'Hours',
        description: 'Next 24 hours - Daily activities and logistics',
        icon: CupertinoIcons.sun_max,
        dataPoints: 24,
        intervalMinutes: 60,
      ),
      TimeFrameOption(
        value: '72h',
        displayName: '72H',
        subtitle: 'Hours',
        description: 'Next 3 days - Extended trip planning',
        icon: CupertinoIcons.calendar,
        dataPoints: 72,
        intervalMinutes: 60,
      ),
    ];
  }

  static List<TimeFrameOption> mediumRangeOptions() {
    return [
      TimeFrameOption(
        value: '3d',
        displayName: '3D',
        subtitle: 'Days',
        description: '3 days - Weekend trip planning',
        icon: CupertinoIcons.calendar,
        dataPoints: 3,
        intervalMinutes: 1440, // 24 hours
      ),
      TimeFrameOption(
        value: '7d',
        displayName: '7D',
        subtitle: 'Days',
        description: '1 week - Weekly planning and trends',
        icon: CupertinoIcons.calendar_today,
        dataPoints: 7,
        intervalMinutes: 1440,
      ),
      TimeFrameOption(
        value: '10d',
        displayName: '10D',
        subtitle: 'Days',
        description: '10 days - Extended forecast confidence',
        icon: CupertinoIcons.calendar_badge_plus,
        dataPoints: 10,
        intervalMinutes: 1440,
      ),
    ];
  }

  static List<TimeFrameOption> longRangeOptions() {
    return [
      TimeFrameOption(
        value: '2w',
        displayName: '2W',
        subtitle: 'Weeks',
        description: '2 weeks - Seasonal planning outlook',
        icon: CupertinoIcons.calendar,
        dataPoints: 14,
        intervalMinutes: 1440,
      ),
      TimeFrameOption(
        value: '4w',
        displayName: '4W',
        subtitle: 'Weeks',
        description: '1 month - Monthly trend analysis',
        icon: CupertinoIcons.calendar_today,
        dataPoints: 28,
        intervalMinutes: 1440,
      ),
      TimeFrameOption(
        value: '8w',
        displayName: '8W',
        subtitle: 'Weeks',
        description: '2 months - Long-term trend indicators',
        icon: CupertinoIcons.chart_bar,
        dataPoints: 56,
        intervalMinutes: 1440,
      ),
    ];
  }
}

class TimeFrameOption {
  final String value; // '12h', '24h', '72h', '3d', '7d', etc.
  final String displayName; // '12H', '24H', '72H', '3D', '7D', etc.
  final String? subtitle; // 'Hours', 'Days', 'Weeks'
  final String description; // Detailed description for help text
  final IconData? icon; // Optional icon for the option
  final int dataPoints; // Expected number of data points
  final int intervalMinutes; // Minutes between data points

  const TimeFrameOption({
    required this.value,
    required this.displayName,
    this.subtitle,
    required this.description,
    this.icon,
    required this.dataPoints,
    required this.intervalMinutes,
  });

  // Helper methods
  Duration get totalDuration {
    return Duration(minutes: dataPoints * intervalMinutes);
  }

  Duration get intervalDuration {
    return Duration(minutes: intervalMinutes);
  }

  bool get isHourly => intervalMinutes <= 60;
  bool get isDaily =>
      intervalMinutes >= 1440 && intervalMinutes < 10080; // 1 day to 1 week
  bool get isWeekly => intervalMinutes >= 10080; // 1 week or more

  String get intervalDisplayName {
    if (isHourly) return 'Hourly';
    if (isDaily) return 'Daily';
    if (isWeekly) return 'Weekly';
    return 'Custom';
  }

  @override
  String toString() {
    return 'TimeFrameOption(value: $value, displayName: $displayName, dataPoints: $dataPoints)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeFrameOption && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
