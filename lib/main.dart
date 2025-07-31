// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'firebase_options.dart'; // This file should be auto-generated
import 'features/auth/presentation/pages/auth_coordinator.dart';

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
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
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
