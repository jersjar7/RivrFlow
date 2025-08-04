// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'package:rivrflow/core/providers/reach_data_provider.dart';
import 'package:rivrflow/features/forecast/pages/reach_overview_page.dart';
import 'package:rivrflow/features/forecast/pages/short_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/medium_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/long_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/hydrograph_page.dart';
import 'package:rivrflow/test/home_page.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/pages/auth_coordinator.dart';
import 'features/map/map_page.dart';

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
        routes: {
          '/map': (context) => const MapPage(),
          '/forecast': (context) => const ForecastPlaceholderPage(),
        },
        onGenerateRoute: (settings) {
          // Handle routes with arguments
          switch (settings.name) {
            case '/reach-overview':
              final args = settings.arguments as Map<String, dynamic>?;
              return CupertinoPageRoute(
                builder: (context) =>
                    ReachOverviewPage(reachId: args?['reachId'] as String?),
                settings: settings,
              );
            case '/short-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              return CupertinoPageRoute(
                builder: (context) =>
                    ShortRangeDetailPage(reachId: args?['reachId'] as String?),
                settings: settings,
              );
            case '/medium-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              return CupertinoPageRoute(
                builder: (context) =>
                    MediumRangeDetailPage(reachId: args?['reachId'] as String?),
                settings: settings,
              );
            case '/long-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              return CupertinoPageRoute(
                builder: (context) =>
                    LongRangeDetailPage(reachId: args?['reachId'] as String?),
                settings: settings,
              );
            case '/hydrograph':
              final args = settings.arguments as Map<String, dynamic>?;
              return CupertinoPageRoute(
                builder: (context) => HydrographPage(
                  reachId: args?['reachId'] as String?,
                  forecastType: args?['forecastType'] as String?,
                  timeFrame: args?['timeFrame'] as String?,
                  title: args?['title'] as String?,
                ),
                settings: settings,
              );
            default:
              return null;
          }
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
