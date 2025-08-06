// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/pages/navigation_error_page.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'package:rivrflow/core/providers/reach_data_provider.dart';
import 'package:rivrflow/core/providers/favorites_provider.dart';
import 'package:rivrflow/features/favorites/favorites_page.dart';
import 'package:rivrflow/features/forecast/pages/reach_overview_page.dart';
import 'package:rivrflow/features/forecast/pages/short_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/medium_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/long_range_detail_page.dart';
import 'package:rivrflow/features/forecast/pages/hydrograph_page.dart';
import 'package:rivrflow/features/favorites/pages/image_selection_page.dart';
import 'package:rivrflow/features/settings/pages/notifications_settings_page.dart';
import 'package:rivrflow/features/settings/pages/app_theme_settings_page.dart';
import 'package:rivrflow/features/settings/pages/sponsors_page.dart';
import 'package:rivrflow/features/map/widgets/map_with_favorites.dart';
import 'package:rivrflow/test/home_page.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/pages/auth_coordinator.dart';
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
          '/map': (context) => const MapWithFavorites(),
          '/forecast': (context) {
            final reachId =
                ModalRoute.of(context)?.settings.arguments as String?;
            if (reachId == null) {
              return const NavigationErrorPage.missingArguments(
                routeName: 'forecast',
              );
            }
            return ReachOverviewPage(reachId: reachId);
          },
          // Settings pages
          '/notifications-settings': (context) =>
              const NotificationsSettingsPage(),
          '/app-theme-settings': (context) => const AppThemeSettingsPage(),
          '/sponsors': (context) => const SponsorsPage(),
          '/test-home': (context) =>
              const HomePage(), // Keep test home for development
        },
        onGenerateRoute: (settings) {
          // Handle routes with arguments
          switch (settings.name) {
            case '/reach-overview':
              final args = settings.arguments as Map<String, dynamic>?;
              final reachId = args?['reachId'] as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) =>
                      const NavigationErrorPage.missingArguments(
                        routeName: 'reach overview',
                      ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => ReachOverviewPage(reachId: reachId),
                settings: settings,
              );

            case '/short-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              final reachId = args?['reachId'] as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) =>
                      const NavigationErrorPage.missingArguments(
                        routeName: 'short range detail',
                      ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => ShortRangeDetailPage(reachId: reachId),
                settings: settings,
              );

            case '/medium-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              final reachId = args?['reachId'] as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) =>
                      const NavigationErrorPage.missingArguments(
                        routeName: 'medium range detail',
                      ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => MediumRangeDetailPage(reachId: reachId),
                settings: settings,
              );

            case '/long-range-detail':
              final args = settings.arguments as Map<String, dynamic>?;
              final reachId = args?['reachId'] as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) =>
                      const NavigationErrorPage.missingArguments(
                        routeName: 'long range detail',
                      ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => LongRangeDetailPage(reachId: reachId),
                settings: settings,
              );

            case '/hydrograph':
              final args = settings.arguments as Map<String, dynamic>?;
              final reachId = args?['reachId'] as String?;
              final forecastType = args?['forecastType'] as String?;

              if (reachId == null || forecastType == null) {
                return CupertinoPageRoute(
                  builder: (context) =>
                      const NavigationErrorPage.invalidArguments(
                        expected: 'reachId (String) and forecastType (String)',
                        routeName: 'hydrograph',
                      ),
                  settings: settings,
                );
              }

              return CupertinoPageRoute(
                builder: (context) => HydrographPage(
                  reachId: reachId,
                  forecastType: forecastType,
                  timeFrame: args?['timeFrame'] as String?,
                  title: args?['title'] as String?,
                ),
                settings: settings,
              );

            case '/image-selection':
              final reachId = settings.arguments as String?;
              if (reachId == null) {
                return CupertinoPageRoute(
                  builder: (context) => const NavigationErrorPage(
                    message: 'No river selected for image customization.',
                    title: 'Selection Required',
                    icon: CupertinoIcons.photo,
                  ),
                  settings: settings,
                );
              }
              return CupertinoPageRoute(
                builder: (context) => ImageSelectionPage(reachId: reachId),
                settings: settings,
              );

            default:
              return CupertinoPageRoute(
                builder: (context) => NavigationErrorPage.pageNotFound(
                  routeName: settings.name ?? 'unknown',
                ),
                settings: settings,
              );
          }
        },
        // Handle completely unknown routes
        onUnknownRoute: (settings) {
          return CupertinoPageRoute(
            builder: (context) => NavigationErrorPage.pageNotFound(
              routeName: settings.name ?? 'unknown',
            ),
            settings: settings,
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
