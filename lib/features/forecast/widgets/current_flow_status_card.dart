// lib/features/forecast/widgets/current_flow_status_card.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/reach_data_provider.dart';

class CurrentFlowStatusCard extends StatefulWidget {
  final VoidCallback? onTap;
  final bool expanded;

  const CurrentFlowStatusCard({super.key, this.onTap, this.expanded = false});

  @override
  State<CurrentFlowStatusCard> createState() => _CurrentFlowStatusCardState();
}

class _CurrentFlowStatusCardState extends State<CurrentFlowStatusCard>
    with TickerProviderStateMixin {
  bool _returnPeriodExpanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween(begin: 0.96, end: 0.98).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReachDataProvider>(
      builder: (context, reachProvider, child) {
        if (reachProvider.isLoading) {
          return _buildLoadingCard();
        }

        if (!reachProvider.hasData) {
          return _buildEmptyCard();
        }

        final currentFlow = reachProvider.getCurrentFlow();
        final category = reachProvider.getFlowCategory();
        final reach = reachProvider.currentReach;

        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.onTap != null ? _pulseAnimation.value : 1.0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(category),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(category),
                        const SizedBox(height: 16),
                        _buildFlowValue(currentFlow),
                        const SizedBox(height: 16),
                        if (reach?.returnPeriods != null &&
                            reach!.returnPeriods!.isNotEmpty)
                          _buildFlowIndicator(
                            currentFlow!,
                            reach.returnPeriods!,
                          ),
                        const SizedBox(height: 12),
                        _buildMetadata(reach),
                        if (widget.expanded) ...[
                          const SizedBox(height: 16),
                          _buildExpandedContent(reach),
                        ] else
                          _buildExpandHint(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(String category) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Current Flow',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            category,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowValue(double? flow) {
    if (flow == null) {
      return const Text(
        'No data',
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatFlow(flow),
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4, left: 4),
          child: Text(
            'CFS',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowIndicator(
    double currentFlow,
    Map<int, double> returnPeriods,
  ) {
    // Find appropriate scale based on return periods
    final maxReturnPeriod = returnPeriods.values.reduce(
      (a, b) => a > b ? a : b,
    );
    final scale = maxReturnPeriod * 1.1; // 10% padding

    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                CupertinoColors.systemBlue,
                CupertinoColors.systemGreen,
                CupertinoColors.systemYellow,
                CupertinoColors.systemOrange,
                CupertinoColors.systemRed,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Current flow marker
              Positioned(
                left:
                    (currentFlow /
                            scale *
                            MediaQuery.of(context).size.width *
                            0.8)
                        .clamp(0, MediaQuery.of(context).size.width * 0.8 - 4),
                top: -2,
                child: Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low',
              style: TextStyle(color: CupertinoColors.white, fontSize: 10),
            ),
            Text(
              'Normal',
              style: TextStyle(color: CupertinoColors.white, fontSize: 10),
            ),
            Text(
              'High',
              style: TextStyle(color: CupertinoColors.white, fontSize: 10),
            ),
            Text(
              'Extreme',
              style: TextStyle(color: CupertinoColors.white, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadata(reach) {
    if (reach == null) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          CupertinoIcons.location,
          color: CupertinoColors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          reach.displayName ?? reach.riverName,
          style: TextStyle(
            color: CupertinoColors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        if (reach.formattedLocation.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            '• ${reach.formattedLocation}',
            style: TextStyle(
              color: CupertinoColors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedContent(reach) {
    if (reach?.returnPeriods == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: CupertinoColors.white.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              _returnPeriodExpanded = !_returnPeriodExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Return Period Information',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _returnPeriodExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  color: CupertinoColors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _returnPeriodExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildReturnPeriodTable(reach.returnPeriods!),
          ),
        ),
      ],
    );
  }

  Widget _buildReturnPeriodTable(Map<int, double> returnPeriods) {
    final periods = [
      2,
      5,
      10,
      25,
      50,
      100,
    ].where((year) => returnPeriods.containsKey(year)).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Return Period',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Flow (CFS)',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...periods.map((year) {
            final flow = returnPeriods[year]!;
            // Convert from CMS to CFS (1 CMS = 35.3147 CFS)
            final flowCfs = flow * 35.3147;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$year-year',
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatFlow(flowCfs),
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpandHint() {
    if (widget.onTap == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Icon(
          CupertinoIcons.chevron_down,
          color: CupertinoColors.white.withOpacity(0.6),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CupertinoColors.systemGrey, CupertinoColors.systemGrey2],
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              color: CupertinoColors.white,
              radius: 12,
            ),
            SizedBox(height: 12),
            Text(
              'Loading flow data...',
              style: TextStyle(color: CupertinoColors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CupertinoColors.systemGrey3, CupertinoColors.systemGrey4],
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: CupertinoColors.white,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              'No flow data available',
              style: TextStyle(color: CupertinoColors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String category) {
    switch (category.toLowerCase()) {
      case 'normal':
        return [CupertinoColors.systemBlue, CupertinoColors.systemTeal];
      case 'elevated':
        return [CupertinoColors.systemGreen, CupertinoColors.systemYellow];
      case 'high':
        return [CupertinoColors.systemOrange, CupertinoColors.systemRed];
      case 'flood risk':
        return [CupertinoColors.systemRed, CupertinoColors.systemPurple];
      default:
        return [CupertinoColors.systemGrey, CupertinoColors.systemGrey2];
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'normal':
        return CupertinoColors.systemBlue;
      case 'elevated':
        return CupertinoColors.systemGreen;
      case 'high':
        return CupertinoColors.systemOrange;
      case 'flood risk':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatFlow(double flow) {
    if (flow >= 1000000) {
      return '${(flow / 1000000).toStringAsFixed(1)}M';
    } else if (flow >= 1000) {
      return '${(flow / 1000).toStringAsFixed(1)}K';
    } else if (flow >= 100) {
      return flow.toStringAsFixed(0);
    } else {
      return flow.toStringAsFixed(1);
    }
  }
}
