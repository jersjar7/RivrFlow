// lib/features/forecast/widgets/forecast_category_grid.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';

class ForecastCategoryGrid extends StatelessWidget {
  final Function(String forecastType)? onCategoryTap;

  const ForecastCategoryGrid({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReachDataProvider>(
      builder: (context, reachProvider, child) {
        final availableTypes = reachProvider.getAvailableForecastTypes();

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
              const SizedBox(height: 12),
              _buildVerticalCards(context, availableTypes, reachProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalCards(
    BuildContext context,
    List<String> availableTypes,
    ReachDataProvider reachProvider,
  ) {
    final categories = _getForecastCategories();

    return Column(
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final isAvailable = availableTypes.contains(category.type);
        final isLoading = reachProvider.isLoading;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategoryCard(
            context,
            category,
            isAvailable,
            isLoading,
            index, // Pass the index for opacity calculation
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ForecastCategory category,
    bool isAvailable,
    bool isLoading,
    int index, // Add index parameter
  ) {
    final opacity = isAvailable ? 1.0 : 0.5;

    // Calculate gradient opacity based on index (1.0, 0.8, 0.6)
    final gradientOpacity = isAvailable ? (1.0 - (index * 0.2)) : 0.5;

    // Use the same gradient for all cards, but with varying opacity
    final baseGradientColors = [
      CupertinoColors.systemIndigo,
      CupertinoColors.systemBlue,
    ];

    final gradientColors = isAvailable
        ? baseGradientColors
              .map((color) => color.withOpacity(gradientOpacity))
              .toList()
        : _getDisabledColors();

    return GestureDetector(
      onTap: isAvailable && !isLoading
          ? () => onCategoryTap?.call(category.type)
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CustomPaint(
                    painter: _PatternPainter(
                      color: CupertinoColors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category.icon,
                        color: CupertinoColors.white,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          Text(
                            category.displayName,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            category.timeRange,
                            style: TextStyle(
                              color: CupertinoColors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Description
                          Text(
                            isAvailable
                                ? category.description
                                : 'Not available at this moment',
                            style: TextStyle(
                              color: CupertinoColors.white.withOpacity(0.7),
                              fontSize: 12,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Status indicator and arrow
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLoading)
                          const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                            radius: 10,
                          )
                        else if (isAvailable)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemGreen,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6.withOpacity(
                                0.9,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Arrow indicator
                        if (isAvailable && !isLoading)
                          Icon(
                            CupertinoIcons.chevron_right,
                            color: CupertinoColors.white.withOpacity(0.6),
                            size: 18,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ForecastCategory> _getForecastCategories() {
    return [
      ForecastCategory(
        type: 'short_range',
        displayName: 'Hourly',
        timeRange: 'Next 18 hours',
        description: 'Hourly forecast for immediate planning',
        icon: CupertinoIcons.clock,
        gradientColors: [
          CupertinoColors.systemBlue,
          CupertinoColors.systemTeal,
        ],
      ),
      ForecastCategory(
        type: 'medium_range',
        displayName: '10-Day',
        timeRange: '1-10 days',
        description: 'Daily forecasts for trip planning',
        icon: CupertinoIcons.calendar,
        gradientColors: [
          CupertinoColors.systemBlue,
          CupertinoColors.systemTeal,
        ],
      ),
      ForecastCategory(
        type: 'long_range',
        displayName: 'Extended',
        timeRange: '10-30 days',
        description: 'Extended outlook and trends',
        icon: CupertinoIcons.chart_bar,
        gradientColors: [
          CupertinoColors.systemBlue,
          CupertinoColors.systemTeal,
        ],
      ),
    ];
  }

  List<Color> _getDisabledColors() {
    return [CupertinoColors.systemGrey, CupertinoColors.systemGrey2];
  }
}

class ForecastCategory {
  final String type;
  final String displayName;
  final String timeRange;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  const ForecastCategory({
    required this.type,
    required this.displayName,
    required this.timeRange,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;

    // Draw diagonal lines pattern
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
