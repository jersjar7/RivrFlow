// lib/features/settings/pages/sponsors_page.dart

import 'package:flutter/cupertino.dart';

/// Placeholder sponsors page
class SponsorsPage extends StatelessWidget {
  const SponsorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Sponsors')),
      child: const Center(
        child: Text(
          'Sponsors',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
    );
  }
}
