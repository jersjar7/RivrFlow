// lib/features/map/widgets/map_control_buttons.dart

import 'package:flutter/cupertino.dart';

class MapControlButtons extends StatelessWidget {
  final VoidCallback onLayersPressed;
  final VoidCallback onRecenterPressed;
  final VoidCallback onStreamsPressed;

  const MapControlButtons({
    super.key,
    required this.onLayersPressed,
    required this.onRecenterPressed,
    required this.onStreamsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Streams list button
        _buildControlButton(
          icon: CupertinoIcons.list_bullet,
          onPressed: onStreamsPressed,
          tooltip: 'Visible Streams',
        ),
        const SizedBox(height: 8),
        // Layers button
        _buildControlButton(
          icon: CupertinoIcons.layers_alt,
          onPressed: onLayersPressed,
          tooltip: 'Map Layers',
        ),
        const SizedBox(height: 8),
        // Recenter button
        _buildControlButton(
          icon: CupertinoIcons.location_fill,
          onPressed: onRecenterPressed,
          tooltip: 'Center on Location',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Icon(icon, color: CupertinoColors.systemBlue, size: 20),
      ),
    );
  }
}
