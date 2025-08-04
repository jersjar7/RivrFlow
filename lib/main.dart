// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'package:rivrflow/core/providers/reach_data_provider.dart';
import 'package:rivrflow/core/providers/favorites_provider.dart'; // NEW: Import FavoritesProvider
import 'package:rivrflow/features/favorites/favorites_page.dart';
import 'package:rivrflow/features/forecast/pages/reach_overview_page.dart';
import 'package:rivrflow/features/forecast/pages/short_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/medium_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/long_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/hydrograph_page.dart';
import 'package:rivrflow/features/favorites/pages/image_selection_page.dart'; // NEW: Import ImageSelectionPage
import 'package:rivrflow/test/home_page.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/pages/auth_coordinator.dart';
import 'features/map/map_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
      ],
      child: CupertinoApp(
        title: 'RivrFlow',
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemBlue,
          brightness: Brightness.light,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        // Set FavoritesPage as home page (after authentication)
        home: AuthCoordinator(
          onAuthSuccess: (context) => const FavoritesPage(),
        ),
        routes: {
          '/favorites': (context) => const FavoritesPage(),
          '/map': (context) => const MapPage(),
          '/forecast': (context) => const ForecastPlaceholderPage(),
          '/test-home': (context) =>
              const HomePage(), // Keep test home for development
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
            case '/image-selection':
              final reachId = settings.arguments as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) => const _ErrorPage(
                    message: 'Invalid navigation: missing reach ID',
                  ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => ImageSelectionPage(reachId: reachId),
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

/// Simple error page for navigation errors
class _ErrorPage extends StatelessWidget {
  final String message;

  const _ErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Error')),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 64,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(height: 24),
              Text(
                'Navigation Error',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/favorites', (route) => false),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder page for forecast route
class ForecastPlaceholderPage extends StatelessWidget {
  const ForecastPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Forecast')),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chart_bar,
              size: 64,
              color: CupertinoColors.systemBlue,
            ),
            SizedBox(height: 16),
            Text(
              'Forecast Page',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
