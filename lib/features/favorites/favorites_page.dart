// lib/features/favorites/favorites_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/favorites/widgets/favorite_river_card.dart';
import 'package:rivrflow/features/favorites/widgets/favorites_search_bar.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/models/favorite_river.dart';

/// Main favorites page - serves as app home screen
/// Features: reorderable list, pull-to-refresh, search, empty state
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Initialize favorites when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFavorites();
    });
  }

  Future<void> _initializeFavorites() async {
    final favoritesProvider = context.read<FavoritesProvider>();
    await favoritesProvider.initializeAndRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          if (favoritesProvider.isLoading) {
            return _buildLoadingState();
          }

          if (favoritesProvider.isEmpty) {
            return _buildEmptyState();
          }

          return _buildFavoritesList(favoritesProvider);
        },
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      middle: const Text('My Rivers'),
      trailing: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          if (favoritesProvider.isEmpty) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _navigateToMap,
              child: const Icon(CupertinoIcons.add),
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search toggle button (only when 4+ favorites)
              if (favoritesProvider.shouldShowSearch)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _toggleSearch,
                  child: Icon(
                    _searchQuery.isNotEmpty
                        ? CupertinoIcons.search_circle_fill
                        : CupertinoIcons.search,
                  ),
                ),

              // Add new favorite button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToMap,
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 16),
          SizedBox(height: 16),
          Text(
            'Loading your rivers...',
            style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                CupertinoIcons.heart,
                size: 60,
                color: CupertinoColors.systemBlue,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'No Favorite Rivers Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            const Text(
              'Discover rivers on the map and add them to your favorites for quick access to flow forecasts.',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Call to action button
            CupertinoButton.filled(
              onPressed: _navigateToMap,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.map, size: 18),
                  SizedBox(width: 8),
                  Text('Explore Rivers'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Secondary action
            CupertinoButton(
              onPressed: _showHelpDialog,
              child: const Text('How do I add favorites?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider favoritesProvider) {
    final filteredFavorites = _searchQuery.isEmpty
        ? favoritesProvider.favorites
        : favoritesProvider.filterFavorites(_searchQuery);

    return PullDownSearchWrapper(
      shouldShowSearch: favoritesProvider.shouldShowSearch,
      onSearchChanged: (query) => setState(() => _searchQuery = query),
      searchPlaceholder: 'Search your rivers...',
      child: SafeArea(
        top: true,
        child: CustomScrollView(
          slivers: [
            // Pull-to-refresh
            CupertinoSliverRefreshControl(
              onRefresh: () => _handleRefresh(favoritesProvider),
            ),

            // Error message (if any)
            if (favoritesProvider.errorMessage != null)
              SliverToBoxAdapter(
                child: _buildErrorBanner(favoritesProvider.errorMessage!),
              ),

            // Search results info (when searching)
            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSearchResultsHeader(filteredFavorites.length),
              ),

            // Favorites list
            SliverToBoxAdapter(
              child: _buildReorderableList(
                filteredFavorites,
                favoritesProvider,
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsHeader(int resultCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        resultCount == 1 ? '1 river found' : '$resultCount rivers found',
        style: const TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildReorderableList(
    List<FavoriteRiver> favorites,
    FavoritesProvider favoritesProvider,
  ) {
    if (favorites.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: favorites.length,
      onReorder: (oldIndex, newIndex) =>
          _handleReorder(oldIndex, newIndex, favoritesProvider),
      proxyDecorator: _proxyDecorator,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return FavoriteRiverCard(
          key: ValueKey(favorite.reachId),
          favorite: favorite,
          onTap: () => _navigateToForecast(favorite.reachId),
          onRename: () => _showRenameDialog(favorite),
          onChangeImage: () => _navigateToImageSelection(favorite),
          isReorderable:
              _searchQuery.isEmpty, // Only allow reordering when not searching
        );
      },
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 48,
            color: CupertinoColors.systemGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No rivers found for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try searching by river name or reach ID',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.05,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Event handlers
  Future<void> _handleRefresh(FavoritesProvider favoritesProvider) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await favoritesProvider.refreshAllFavorites();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleReorder(
    int oldIndex,
    int newIndex,
    FavoritesProvider favoritesProvider,
  ) async {
    // Adjust newIndex if needed (ReorderableListView quirk)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    await favoritesProvider.reorderFavorites(oldIndex, newIndex);
  }

  void _toggleSearch() {
    // This could expand search bar or focus existing one
    // Implementation depends on your search bar design choice
  }

  void _navigateToMap() {
    Navigator.of(context).pushNamed('/map');
  }

  void _navigateToForecast(String reachId) {
    Navigator.of(context).pushNamed('/forecast', arguments: reachId);
  }

  void _navigateToImageSelection(FavoriteRiver favorite) {
    Navigator.of(
      context,
    ).pushNamed('/image-selection', arguments: favorite.reachId);
  }

  void _showRenameDialog(FavoriteRiver favorite) {
    final controller = TextEditingController(text: favorite.customName);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Rename River'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Enter new name',
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final newName = controller.text.trim();
              Navigator.pop(context);

              if (newName.isNotEmpty && newName != favorite.customName) {
                final provider = context.read<FavoritesProvider>();
                await provider.updateFavorite(
                  favorite.reachId,
                  customName: newName,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Adding Favorites'),
        content: const Text(
          '1. Tap "Explore Rivers" to open the map\n'
          '2. Find a river you\'re interested in\n'
          '3. Tap the river to view details\n'
          '4. Tap the heart button to add it to favorites\n\n'
          'Your favorites will appear here for quick access to flow forecasts.',
          textAlign: TextAlign.center,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToMap();
            },
            child: const Text('Explore Now'),
          ),
        ],
      ),
    );
  }
}
