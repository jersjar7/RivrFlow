import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/services/forecast_service.dart';
import 'package:rivrflow/core/services/noaa_api_service.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('RivrFlow'),
            backgroundColor: CupertinoColors.systemBackground,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => authProvider.signOut(),
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: CupertinoTheme.of(context).primaryColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      CupertinoIcons.drop_fill,
                      color: CupertinoColors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Welcome text
                  const Text(
                    'Welcome to RivrFlow',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Hello ${authProvider.userDisplayName}!',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Navigation buttons
                  Column(
                    children: [
                      SizedBox(
                        width: 200,
                        child: CupertinoButton.filled(
                          onPressed: () => Navigator.pushNamed(context, '/map'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.map, size: 20),
                              SizedBox(width: 8),
                              Text('Explore Map'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: 200,
                        child: CupertinoButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/reach-overview',
                            arguments: {'reachId': '23021904'},
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.chart_bar, size: 20),
                              SizedBox(width: 8),
                              Text('Demo Forecast'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Phase info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Phase 5: Core Forecast Visualization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Interactive charts and forecast detail pages',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder forecast page for Phase 4
/// Will be replaced with actual forecast page in Phase 5
class ForecastPlaceholderPage extends StatelessWidget {
  const ForecastPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get reachId from navigation arguments
    final reachId = ModalRoute.of(context)?.settings.arguments as String?;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Forecast')),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.chart_bar,
                  size: 80,
                  color: CupertinoColors.systemBlue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Forecast Page',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (reachId != null) ...[
                  const Text(
                    'Selected Reach:',
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reachId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Phase 5: Core Forecast Visualization\nComing Soon!',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> testCompleteForecastSystem() async {
  print('🧪 Testing Complete Forecast System');
  print('=' * 50);

  final api = NoaaApiService();
  final forecastService = ForecastService();
  const testReachId = '23021904';

  // Test 1: Individual API Methods
  print('\n📡 TESTING INDIVIDUAL API METHODS');
  print('-' * 30);

  // Test 1.1: Reach Info
  print('\n📍 Testing fetchReachInfo...');
  try {
    final reachData = await api.fetchReachInfo(testReachId);
    print('✅ Reach info success: ${reachData['name']}');
    print(
      '   📍 Location: ${reachData['latitude']}, ${reachData['longitude']}',
    );
    print('   🌊 Available forecasts: ${reachData['streamflow']}');

    final route = reachData['route'];
    if (route != null) {
      print('   ⬆️ Upstream reaches: ${(route['upstream'] as List).length}');
      print(
        '   ⬇️ Downstream reaches: ${(route['downstream'] as List).length}',
      );
    }
  } catch (e) {
    print('❌ Reach info failed: $e');
  }

  // Test 1.2: Return Periods
  print('\n🔢 Testing fetchReturnPeriods...');
  try {
    final returnPeriods = await api.fetchReturnPeriods(testReachId);
    print('✅ Return periods: ${returnPeriods.length} items');
    if (returnPeriods.isNotEmpty) {
      final data = returnPeriods.first as Map;
      final returnKeys = data.keys
          .where((k) => k.toString().startsWith('return_period_'))
          .toList();
      print('   📊 Available return periods: $returnKeys');
      if (returnKeys.isNotEmpty) {
        final firstKey = returnKeys.first;
        print('   💧 Sample: $firstKey = ${data[firstKey]} CMS');
      }
    }
  } catch (e) {
    print('❌ Return periods failed: $e');
  }

  // Test 1.3: Individual Forecast Types
  final forecastTypes = ['short_range', 'medium_range', 'long_range'];
  for (final type in forecastTypes) {
    print('\n📈 Testing fetchForecast($type)...');
    try {
      final forecastData = await api.fetchForecast(testReachId, type);
      print('✅ $type forecast success');

      // Show sample data
      final typeSection = forecastData[_mapForecastTypeToSection(type)];
      if (typeSection != null && typeSection is Map) {
        _showSampleForecastData(typeSection, type);
      }
    } catch (e) {
      print('❌ $type forecast failed: $e');
    }
  }

  // Test 1.4: All Forecasts Combined
  print('\n🔄 Testing fetchAllForecasts...');
  try {
    final allForecasts = await api.fetchAllForecasts(testReachId);
    print('✅ All forecasts success');
    print('   📦 Response sections: ${allForecasts.keys}');

    // Count available forecast sections
    int sectionCount = 0;
    for (final section in [
      'shortRange',
      'mediumRange',
      'longRange',
      'analysisAssimilation',
      'mediumRangeBlend',
    ]) {
      if (allForecasts[section] != null &&
          allForecasts[section] is Map &&
          (allForecasts[section] as Map).isNotEmpty) {
        sectionCount++;
      }
    }
    print('   ✨ Non-empty forecast sections: $sectionCount/5');
  } catch (e) {
    print('❌ All forecasts failed: $e');
  }

  // Test 2: Forecast Service Methods
  print('\n\n🏢 TESTING FORECAST SERVICE');
  print('-' * 30);

  // Test 2.1: Complete Data Loading
  print('\n🎯 Testing loadCompleteReachData...');
  try {
    final completeData = await forecastService.loadCompleteReachData(
      testReachId,
    );
    print('✅ Complete data loaded successfully');
    print('   🏷️ Reach: ${completeData.reach.displayName}');
    print('   📍 Location: ${completeData.reach.formattedLocation}');
    print('   🔢 Has return periods: ${completeData.reach.hasReturnPeriods}');

    if (completeData.reach.hasReturnPeriods) {
      final periods = completeData.reach.returnPeriods!;
      print('   📊 Return periods available: ${periods.keys.toList()}');
      print('   💧 Sample return period: 2-year = ${periods[2]} CMS');
    }

    // Test forecast availability
    final availableTypes = forecastService.getAvailableForecastTypes(
      completeData,
    );
    print('   📈 Available forecast types: $availableTypes');

    // Test current flow
    final currentFlow = forecastService.getCurrentFlow(completeData);
    print(
      '   🌊 Current flow: ${currentFlow?.toStringAsFixed(1) ?? 'N/A'} CFS',
    );

    // Test flow category
    final flowCategory = forecastService.getFlowCategory(completeData);
    print('   🎯 Flow category: $flowCategory');

    // Test ensemble data
    final hasEnsemble = forecastService.hasEnsembleData(completeData);
    print('   👥 Has ensemble data: $hasEnsemble');

    // Test 2.2: Primary Forecast Access
    print('\n📊 Testing forecast data access...');
    for (final type in availableTypes) {
      final primaryForecast = completeData.getPrimaryForecast(type);
      final dataSource = completeData.getDataSource(type);

      if (primaryForecast != null && primaryForecast.isNotEmpty) {
        final firstPoint = primaryForecast.data.first;
        final lastPoint = primaryForecast.data.last;
        print(
          '   ✅ $type: ${primaryForecast.data.length} points ($dataSource)',
        );
        print(
          '      📅 First: ${_formatDateTime(firstPoint.validTime)} = ${firstPoint.flow.toStringAsFixed(1)} ${primaryForecast.units}',
        );
        print(
          '      📅 Last: ${_formatDateTime(lastPoint.validTime)} = ${lastPoint.flow.toStringAsFixed(1)} ${primaryForecast.units}',
        );
      }
    }

    // Test 2.3: Ensemble Data Access
    print('\n👥 Testing ensemble data access...');
    for (final type in ['medium_range', 'long_range']) {
      if (availableTypes.contains(type)) {
        final ensembleSummary = forecastService.getEnsembleSummary(
          completeData,
          type,
        );
        print('   📊 $type ensemble: $ensembleSummary');

        if (ensembleSummary['available'] == true) {
          final allEnsembleData = completeData.getAllEnsembleData(type);
          print('      🎭 All series: ${allEnsembleData.keys.toList()}');

          // Show sample data from mean if available
          if (allEnsembleData.containsKey('mean')) {
            final meanData = allEnsembleData['mean']!;
            if (meanData.data.isNotEmpty) {
              final first = meanData.data.first;
              print(
                '      💧 Mean sample: ${_formatDateTime(first.validTime)} = ${first.flow.toStringAsFixed(1)} ${meanData.units}',
              );
            }
          }
        }
      }
    }
  } catch (e) {
    print('❌ Complete data loading failed: $e');
  }

  print('\n🎉 Testing complete!');
  print('=' * 50);
}

// Helper functions for testing
String _mapForecastTypeToSection(String type) {
  switch (type) {
    case 'short_range':
      return 'shortRange';
    case 'medium_range':
      return 'mediumRange';
    case 'long_range':
      return 'longRange';
    default:
      return type;
  }
}

void _showSampleForecastData(Map section, String type) {
  // Handle ensemble data (medium/long range)
  if (section.containsKey('member01')) {
    final member01 = section['member01'];
    if (member01 is Map && member01.containsKey('data')) {
      final data = member01['data'] as List?;
      if (data != null && data.isNotEmpty) {
        final first = data.first as Map;
        print(
          '   💧 Sample member01 data: ${first['validTime']} = ${first['flow']} ${member01['units']}',
        );
      }
    }

    // Count members
    final memberKeys = section.keys
        .where((k) => k.toString().startsWith('member'))
        .toList();
    print('   👥 Ensemble members: ${memberKeys.length}');
  }
  // Handle single series data (short range)
  else if (section.containsKey('data')) {
    final data = section['data'] as List?;
    if (data != null && data.isNotEmpty) {
      final first = data.first as Map;
      print(
        '   💧 Sample data: ${first['validTime']} = ${first['flow']} ${section['units']}',
      );
    }
  }
  // Handle series data structure
  else {
    final seriesKeys = section.keys.where((k) => k != 'metadata').toList();
    if (seriesKeys.isNotEmpty) {
      final firstSeries = section[seriesKeys.first];
      if (firstSeries is Map && firstSeries.containsKey('data')) {
        final data = firstSeries['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final first = data.first as Map;
          print(
            '   💧 Sample series data: ${first['validTime']} = ${first['flow']} ${firstSeries['units']}',
          );
        }
      }
    }
  }

  if (section.containsKey('mean')) {
    final mean = section['mean'];
    if (mean is Map && mean.containsKey('data')) {
      final data = mean['data'] as List?;
      if (data != null && data.isNotEmpty) {
        final first = data.first as Map;
        print(
          '   💧 Sample mean data: ${first['validTime']} = ${first['flow']} ${mean['units']}',
        );
      }
    }
  }

  // Count ensemble members
  final memberKeys = section.keys
      .where((k) => k.toString().startsWith('member'))
      .toList();
  if (memberKeys.isNotEmpty) {
    print(
      '   👥 Ensemble members: ${memberKeys.length} (${memberKeys.take(3).join(', ')}${memberKeys.length > 3 ? '...' : ''})',
    );
  }
}

// Helper function to format DateTime for display
String _formatDateTime(DateTime dt) {
  return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
