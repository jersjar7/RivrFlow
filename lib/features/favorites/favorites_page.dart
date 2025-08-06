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
  bool _showSearch = false; // New state for search visibility

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
      child: Stack(
        children: [
          // Main content
          Consumer<FavoritesProvider>(
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

          // Floating action button
          _buildFloatingActionButton(),
        ],
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      // No middle title anymore
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _showSettingsMenu,
        child: const Icon(CupertinoIcons.ellipsis),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 50,
      right: 20,
      child: FloatingActionButton(
        onPressed: _navigateToMap,
        backgroundColor: CupertinoColors.darkBackgroundGray,
        child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
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
    return SafeArea(
      child: Column(
        children: [
          // App title header
          _buildAppHeader(),

          // Empty state content
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider favoritesProvider) {
    final filteredFavorites = _searchQuery.isEmpty
        ? favoritesProvider.favorites
        : favoritesProvider.filterFavorites(_searchQuery);

    return SafeArea(
      top: true,
      child: Column(
        children: [
          // App header
          _buildAppHeader(),

          // Search bar (using custom FavoritesSearchBar)
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              if (favoritesProvider.shouldShowSearch) {
                return FavoritesSearchBar(
                  onSearchChanged: (query) {
                    // Defer setState to avoid build-time conflicts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _searchQuery = query);
                      }
                    });
                  },
                  isVisible: _showSearch,
                  onCancel: () {
                    // Defer setState to avoid build-time conflicts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _showSearch = false;
                          _searchQuery = '';
                        });
                      }
                    });
                  },
                  placeholder: 'Search your rivers...',
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Favorites list
          Expanded(
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

                // Bottom padding for floating action button
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 32, 16),
      child: Row(
        children: [
          // App title
          const Text(
            'RivrFlow',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label,
            ),
          ),

          const Spacer(),

          // Search toggle button (only when 4+ favorites and not empty state)
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              if (favoritesProvider.shouldShowSearch &&
                  !favoritesProvider.isEmpty) {
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _toggleSearch,
                  child: Icon(
                    _showSearch
                        ? CupertinoIcons.xmark_circle_fill
                        : CupertinoIcons.search,
                    color: CupertinoColors.systemBlue,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
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
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchQuery = ''; // Clear search when hiding
      }
    });
  }

  void _showSettingsMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings Menu',
      barrierColor: CupertinoColors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(opacity: animation, child: _buildDropdownMenu());
      },
    );
  }

  Widget _buildDropdownMenu() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: 30, right: 30),
          width: 250,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E), // Dark modal background
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuOption('Notifications', CupertinoIcons.bell, () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/notifications-settings');
              }),
              _buildMenuDivider(),
              _buildMenuOption('CFS', CupertinoIcons.drop, () {
                Navigator.pop(context);
                // TODO: Future implementation - user flow unit selection
              }),
              _buildMenuDivider(),
              _buildMenuOption('CMS', CupertinoIcons.drop_triangle, () {
                Navigator.pop(context);
                // TODO: Future implementation - user flow unit selection
              }),
              _buildMenuDivider(),
              _buildMenuOption('App Theme', CupertinoIcons.moon, () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/app-theme-settings');
              }),
              _buildMenuDivider(),
              _buildMenuOption('Sponsors', CupertinoIcons.creditcard, () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/sponsors');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(String title, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Icon(icon, color: CupertinoColors.white, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Container(
      height: 1,
      color: CupertinoColors.separator.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
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
          '1. Tap the + button to open the map\n'
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
