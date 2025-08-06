// lib/features/favorites/widgets/favorite_river_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/core/utils/river_image_utility.dart';
import '../../../core/models/favorite_river.dart';
import '../../../core/providers/favorites_provider.dart';
import 'components/slide_action_buttons.dart';
import 'components/slide_action_constants.dart';

/// Individual favorite river card with Cupertino design
/// Supports slide actions, loading states, and tap navigation
class FavoriteRiverCard extends StatefulWidget {
  final FavoriteRiver favorite;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onChangeImage;
  final bool isReorderable;

  const FavoriteRiverCard({
    super.key,
    required this.favorite,
    this.onTap,
    this.onRename,
    this.onChangeImage,
    this.isReorderable = true,
  });

  @override
  State<FavoriteRiverCard> createState() => _FavoriteRiverCardState();
}

class _FavoriteRiverCardState extends State<FavoriteRiverCard>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  bool _isSliding = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Animation will be set up in build method when we have screen width
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate slide offset based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final slideOffset = SlideActionConstants.getSlideOffset(screenWidth);

    // Set up slide animation with calculated offset
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset(slideOffset, 0)).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final isRefreshing = favoritesProvider.isRefreshing(
          widget.favorite.reachId,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 19, vertical: 6),
          child: GestureDetector(
            onTap: _isSliding ? null : widget.onTap,
            // CRITICAL FIX: Remove onLongPress when reorderable - let ReorderableListView handle it
            onLongPress: widget.isReorderable ? null : _handleLongPress,
            // Disable pan gestures when reorderable to avoid conflicts
            onPanStart: widget.isReorderable ? null : _handlePanStart,
            onPanUpdate: widget.isReorderable ? null : _handlePanUpdate,
            onPanEnd: widget.isReorderable ? null : _handlePanEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
              child: Stack(
                children: [
                  // Action buttons (only show when not in reorderable mode)
                  if (_isSliding && !widget.isReorderable)
                    _buildActionButtons(favoritesProvider),

                  // Main card content
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildCardContent(isRefreshing),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(bool isRefreshing) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background image or gradient
            _buildBackground(),

            // Content overlay
            _buildContentOverlay(isRefreshing),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Priority: Custom image -> Random default image -> Gradient fallback

    if (widget.favorite.customImageAsset != null) {
      // User has selected a custom image
      return Positioned.fill(
        child: Image.asset(
          widget.favorite.customImageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // If custom image fails, fall back to random default
            return _buildDefaultImage();
          },
        ),
      );
    } else {
      // No custom image, use random default
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    // Get consistent random image for this river
    final defaultImage = RiverImageUtility.getDefaultImageForRiver(
      widget.favorite.reachId,
    );

    return Positioned.fill(
      child: Image.asset(
        defaultImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If default image fails, fall back to gradient
          print(
            'Failed to load default image: $defaultImage, using gradient fallback',
          );
          return _buildDefaultGradient();
        },
      ),
    );
  }

  Widget _buildDefaultGradient() {
    // Generate gradient based on reach ID for consistency
    final colors = _getGradientColors(widget.favorite.reachId);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String reachId) {
    // Simple hash-based color selection for consistent gradients
    final hash = reachId.hashCode.abs();
    final gradients = [
      [CupertinoColors.systemBlue, CupertinoColors.systemTeal],
      [CupertinoColors.systemPurple, CupertinoColors.systemBlue],
      [CupertinoColors.systemTeal, CupertinoColors.systemGreen],
      [CupertinoColors.systemOrange, CupertinoColors.systemRed],
      [CupertinoColors.systemIndigo, CupertinoColors.systemPurple],
    ];

    return gradients[hash % gradients.length]
        .map((color) => color.withOpacity(0.8))
        .toList();
  }

  Widget _buildContentOverlay(bool isRefreshing) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.0),
              CupertinoColors.black.withOpacity(0.6),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with loading indicator
            Row(
              children: [
                Expanded(child: Container()), // Spacer
                if (isRefreshing)
                  const CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                    radius: 8,
                  ),
              ],
            ),

            const Spacer(),

            // Bottom content
            _buildBottomContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // River name
        Text(
          widget.favorite.displayName,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // Flow information
        Row(
          children: [
            Icon(
              CupertinoIcons.drop,
              color: CupertinoColors.white.withOpacity(0.8),
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.favorite.formattedFlow,
              style: TextStyle(
                color: CupertinoColors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Data freshness indicator
            if (widget.favorite.lastUpdated != null) ...[
              const SizedBox(width: 8),
              Icon(
                widget.favorite.isFlowDataStale
                    ? CupertinoIcons.exclamationmark_circle
                    : CupertinoIcons.checkmark_circle,
                color: widget.favorite.isFlowDataStale
                    ? CupertinoColors.systemYellow
                    : CupertinoColors.systemGreen.withOpacity(0.8),
                size: 12,
              ),
            ],
          ],
        ),

        // Last updated info (if stale)
        if (widget.favorite.isFlowDataStale &&
            widget.favorite.lastUpdated != null) ...[
          const SizedBox(height: 2),
          Text(
            _getLastUpdatedText(),
            style: TextStyle(
              color: CupertinoColors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  // Simplified action buttons using the new component
  Widget _buildActionButtons(FavoritesProvider favoritesProvider) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: SlideActionButtons(
        favorite: widget.favorite,
        favoritesProvider: favoritesProvider,
        onCloseSlide: _closeSlide,
        onChangeImage: widget.onChangeImage,
        onRename: widget.onRename,
      ),
    );
  }

  String _getLastUpdatedText() {
    if (widget.favorite.lastUpdated == null) return '';

    final now = DateTime.now();
    final difference = now.difference(widget.favorite.lastUpdated!);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Gesture handling for slide actions
  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (details.delta.dx < -3 && !_isSliding) {
      // More sensitive swipe detection
      // Swiping left - show actions
      setState(() {
        _isSliding = true;
      });
      _slideController.forward();
    } else if (details.delta.dx > 3 && _isSliding) {
      // More sensitive swipe detection
      // Swiping right - hide actions
      _closeSlide();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _handleLongPress() {
    // Provide haptic feedback when starting to reorder
    HapticFeedback.mediumImpact();

    // Optional: Add a subtle visual indicator that reorder mode is active
    setState(() {
      _isPressed = true;
    });

    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isPressed = false;
        });
      }
    });
  }

  void _closeSlide() {
    if (_isSliding) {
      setState(() {
        _isSliding = false;
      });
      _slideController.reverse();
    }
  }
}
