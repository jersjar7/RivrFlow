// lib/features/favorites/widgets/favorite_river_card.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/models/favorite_river.dart';
import '../../../core/providers/favorites_provider.dart';

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
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.45, 0), // Slide left further to reveal actions
        ).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final isRefreshing = favoritesProvider.isRefreshing(
          widget.favorite.reachId,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: GestureDetector(
            onTap: _isSliding ? null : widget.onTap,
            onLongPress: widget.isReorderable ? _handleLongPress : null,
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
              child: Stack(
                children: [
                  // Action buttons (revealed when sliding)
                  if (_isSliding) _buildActionButtons(favoritesProvider),

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
      height: 140, // ADD FIXED HEIGHT
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

            // Reorder handle (if reorderable)
            if (widget.isReorderable) _buildReorderHandle(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.favorite.customImageAsset != null) {
      return Positioned.fill(
        child: Image.asset(
          widget.favorite.customImageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultGradient(),
        ),
      );
    }

    return _buildDefaultGradient();
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

  Widget _buildReorderHandle() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: CupertinoColors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          CupertinoIcons.bars,
          color: CupertinoColors.white.withOpacity(0.8),
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActionButtons(FavoritesProvider favoritesProvider) {
    return Positioned.fill(
      child: Row(
        children: [
          const Spacer(),

          // Action buttons on the right
          Container(
            width: 150, // Increased width for better text display
            height: double.infinity,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Change Image button
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _closeSlide();
                      widget.onChangeImage?.call();
                    },
                    child: Container(
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Image',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 11, // Slightly smaller text
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Rename button
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _closeSlide();
                      widget.onRename?.call();
                    },
                    child: Container(
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemOrange,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      // color: CupertinoColors.systemOrange,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.pencil,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Rename',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 11, // Slightly smaller text
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Delete button
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _closeSlide();
                      _confirmDelete(favoritesProvider);
                    },
                    child: Container(
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.trash,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 11, // Slightly smaller text
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    // Provide haptic feedback for reordering
    // The actual reordering is handled by ReorderableListView
    // This just provides user feedback
  }

  void _closeSlide() {
    if (_isSliding) {
      setState(() {
        _isSliding = false;
      });
      _slideController.reverse();
    }
  }

  void _confirmDelete(FavoritesProvider favoritesProvider) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remove Favorite'),
        content: Text(
          'Remove "${widget.favorite.displayName}" from your favorites?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await favoritesProvider.removeFavorite(widget.favorite.reachId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
