// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/services/forecast_service.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'package:rivrflow/core/providers/reach_data_provider.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/pages/auth_coordinator.dart';

// Add this import at the top with your other imports
import 'core/services/noaa_api_service.dart';

// Add this corrected test function before main()
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
            if (meanData.isNotEmpty) {
              final firstPoint = meanData.data.first;
              print(
                '      📈 Mean first point: ${_formatDateTime(firstPoint.validTime)} = ${firstPoint.flow.toStringAsFixed(1)} ${meanData.units}',
              );
            }
          }
        }
      }
    }

    // Test 2.4: ReachData Helper Methods
    print('\n🛠️ Testing ReachData helper methods...');
    final reach = completeData.reach;
    print('   🏷️ Display name: ${reach.displayName}');
    print('   🎯 Has custom name: ${reach.hasCustomName}');
    print('   📍 Formatted location: ${reach.formattedLocation}');
    print(
      '   ⏰ Cache age: ${DateTime.now().difference(reach.cachedAt).inMinutes} minutes',
    );
    print('   📊 Cache is stale: ${reach.isCacheStale()}');

    // Test flow categorization with sample flows
    if (reach.hasReturnPeriods) {
      final testFlows = [100.0, 1000.0, 5000.0];
      print('   🌊 Flow categories:');
      for (final flow in testFlows) {
        final category = reach.getFlowCategory(flow);
        final nextThreshold = reach.getNextThreshold(flow);
        print(
          '      ${flow.toStringAsFixed(0)} CFS = $category ${nextThreshold != null ? "(next: ${nextThreshold.key}-year)" : ""}',
        );
      }
    }

    // Test 2.5: ForecastSeries Helper Methods
    print('\n📈 Testing ForecastSeries methods...');
    final shortRange = completeData.getPrimaryForecast('short_range');
    if (shortRange != null && shortRange.isNotEmpty) {
      final testTime = shortRange.data.first.validTime.add(
        const Duration(hours: 6),
      );
      final flowAtTime = shortRange.getFlowAt(testTime);
      print(
        '   ⏰ Flow at ${_formatDateTime(testTime)}: ${flowAtTime?.toStringAsFixed(1) ?? 'N/A'} ${shortRange.units}',
      );
      print('   📊 Series info: ${shortRange.toString()}');
    }
  } catch (e) {
    print('❌ Complete data loading failed: $e');
  }

  // Test 2.6: Specific Forecast Loading
  print('\n⚡ Testing loadSpecificForecast...');
  try {
    final specificForecast = await forecastService.loadSpecificForecast(
      testReachId,
      'short_range',
    );
    print('✅ Specific forecast loaded');
    print('   🏷️ Reach: ${specificForecast.reach.displayName}');

    final shortRange = specificForecast.shortRange;
    if (shortRange != null && shortRange.isNotEmpty) {
      print('   📊 Short range: ${shortRange.data.length} points');
      print(
        '   🌊 First flow: ${shortRange.data.first.flow.toStringAsFixed(1)} ${shortRange.units}',
      );
    }
  } catch (e) {
    print('❌ Specific forecast failed: $e');
  }

  // Test 3: Error Handling
  print('\n\n⚠️ TESTING ERROR HANDLING');
  print('-' * 30);

  print('\n🚫 Testing with invalid reach ID...');
  try {
    await api.fetchReachInfo('invalid_reach_id');
    print('❌ Should have failed but didn\'t');
  } catch (e) {
    print('✅ Correctly caught error for invalid reach');
  }

  print('\n🚫 Testing with invalid forecast series...');
  try {
    await api.fetchForecast(testReachId, 'invalid_series');
    print('❌ Should have failed but didn\'t');
  } catch (e) {
    print('✅ Correctly caught error for invalid series');
  }

  print('\n\n🎉 COMPLETE FORECAST SYSTEM TEST FINISHED!');
  print('=' * 50);
}

// Helper function to map forecast type to response section
String _mapForecastTypeToSection(String forecastType) {
  switch (forecastType) {
    case 'short_range':
      return 'shortRange';
    case 'medium_range':
      return 'mediumRange';
    case 'long_range':
      return 'longRange';
    case 'analysis_assimilation':
      return 'analysisAssimilation';
    case 'medium_range_blend':
      return 'mediumRangeBlend';
    default:
      return forecastType;
  }
}

// Helper function to show sample forecast data
void _showSampleForecastData(Map section, String type) {
  if (section.containsKey('series')) {
    final series = section['series'];
    if (series is Map && series.containsKey('data')) {
      final data = series['data'] as List?;
      if (data != null && data.isNotEmpty) {
        final first = data.first as Map;
        print(
          '   💧 Sample series data: ${first['validTime']} = ${first['flow']} ${series['units']}',
        );
      }
    }
  } else if (section.containsKey('mean')) {
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper configuration
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RivrFlowApp());
}

class RivrFlowApp extends StatelessWidget {
  const RivrFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ReachDataProvider()),
      ],
      child: CupertinoApp(
        title: 'RivrFlow',
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemBlue,
          brightness: Brightness.light,
        ),
        home: AuthCoordinator(onAuthSuccess: (context) => const HomePage()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

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
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'River flow monitoring made simple',
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Status indicators
                  _buildStatusCard(
                    'Authentication',
                    'Active',
                    CupertinoColors.systemGreen,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    'NOAA API',
                    'Ready',
                    CupertinoColors.systemBlue,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    'Mapbox',
                    'Ready',
                    CupertinoColors.systemBlue,
                  ),

                  const SizedBox(height: 48),

                  // Coming soon button
                  CupertinoButton.filled(
                    onPressed: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Coming Soon'),
                          content: const Text(
                            'Favorites and map features are being built!',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('View Favorites'),
                  ),

                  const SizedBox(height: 12),

                  // Updated Test API button with ReachDataProvider
                  Consumer<ReachDataProvider>(
                    builder: (context, reachProvider, _) {
                      return Column(
                        children: [
                          CupertinoButton(
                            color: CupertinoColors.systemOrange,
                            onPressed: reachProvider.isLoading
                                ? null
                                : () async {
                                    // Test provider integration
                                    await reachProvider.loadReach('23021904');
                                  },
                            child: Text(
                              reachProvider.isLoading
                                  ? 'Loading...'
                                  : 'Test Provider',
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Show provider results
                          if (reachProvider.hasData)
                            Text(
                              '✅ ${reachProvider.currentReach!.displayName}',
                              style: const TextStyle(
                                color: CupertinoColors.systemGreen,
                                fontSize: 14,
                              ),
                            ),

                          if (reachProvider.errorMessage != null)
                            Text(
                              '❌ ${reachProvider.errorMessage}',
                              style: const TextStyle(
                                color: CupertinoColors.systemRed,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),

                          const SizedBox(height: 8),

                          // Raw API test button
                          CupertinoButton(
                            color: CupertinoColors.systemGrey,
                            onPressed: () async {
                              print('🧪 Starting raw API tests...');
                              await testCompleteForecastSystem();
                            },
                            child: const Text('Raw API Test'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(String title, String status, Color statusColor) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
