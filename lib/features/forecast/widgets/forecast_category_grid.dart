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
              _buildGrid(context, availableTypes, reachProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<String> availableTypes,
    ReachDataProvider reachProvider,
  ) {
    final categories = _getForecastCategories();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, // Adjusted for 5 items
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isAvailable = availableTypes.contains(category.type);
        final isLoading = reachProvider.isLoading;

        return _buildCategoryCard(context, category, isAvailable, isLoading);
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ForecastCategory category,
    bool isAvailable,
    bool isLoading,
  ) {
    final opacity = isAvailable ? 1.0 : 0.5;

    return GestureDetector(
      onTap: isAvailable && !isLoading
          ? () => onCategoryTap?.call(category.type)
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAvailable
                  ? category.gradientColors
                  : _getDisabledColors(),
            ),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.2),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            category.icon,
                            color: CupertinoColors.white,
                            size: 24,
                          ),
                        ),
                        if (isLoading)
                          const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                            radius: 8,
                          )
                        else if (isAvailable)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemGreen,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey.withOpacity(
                                0.6,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Title
                    Text(
                      category.displayName,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      category.timeRange,
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      isAvailable ? category.description : 'Not available',
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Tap indicator
              if (isAvailable && !isLoading)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.white.withOpacity(0.6),
                    size: 16,
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
        type: 'analysis_assimilation',
        displayName: 'Current Analysis',
        timeRange: 'Real-time',
        description: 'Current flow conditions and recent observations',
        icon: CupertinoIcons.dot_radiowaves_left_right,
        gradientColors: [
          CupertinoColors.systemBlue,
          CupertinoColors.systemTeal,
        ],
      ),
      ForecastCategory(
        type: 'short_range',
        displayName: 'Short Range',
        timeRange: 'Next 18 hours',
        description: 'Hourly forecast for immediate planning',
        icon: CupertinoIcons.clock,
        gradientColors: [
          CupertinoColors.systemGreen,
          CupertinoColors.systemMint,
        ],
      ),
      ForecastCategory(
        type: 'medium_range',
        displayName: 'Medium Range',
        timeRange: '1-10 days',
        description: 'Daily forecasts for trip planning',
        icon: CupertinoIcons.calendar,
        gradientColors: [
          CupertinoColors.systemYellow,
          CupertinoColors.systemOrange,
        ],
      ),
      ForecastCategory(
        type: 'medium_range_blend',
        displayName: 'Medium Blend',
        timeRange: '10 days',
        description: 'Enhanced accuracy using advanced weather blending',
        icon: CupertinoIcons.shuffle,
        gradientColors: [
          CupertinoColors.systemIndigo,
          CupertinoColors.systemPurple,
        ],
      ),
      ForecastCategory(
        type: 'long_range',
        displayName: 'Long Range',
        timeRange: '10-30 days',
        description: 'Extended outlook and trends',
        icon: CupertinoIcons.chart_bar,
        gradientColors: [CupertinoColors.systemRed, CupertinoColors.systemPink],
      ),
    ];
  }

  List<Color> _getDisabledColors() {
    return [CupertinoColors.systemGrey3, CupertinoColors.systemGrey4];
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
