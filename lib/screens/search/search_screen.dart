// lib/screens/search/search_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reel_provider.dart';
import '../../utils/app_utils.dart';
import '../../widgets/video/reel_grid_item.dart';
import '../../services/firebase_service.dart';
import '../profile/other_user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // CHANGED: Multi-select language support
  List<String> _selectedLanguages = ['all'];
  bool _showFilters = false;

  // User search functionality
  late TabController _tabController;
  List<Map<String, dynamic>> _userResults = [];
  bool _isLoadingUsers = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(),

            // Filters (if visible)
            if (_showFilters) _buildFiltersSection(),

            // Search Results
            Expanded(
              child: _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Title and Filter Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discover',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: _showFilters ? AppColors.primary : Colors.white,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _searchFocusNode.hasFocus
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for users or reels...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Language Filters',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),

          // Multi-select language chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLanguageChip('all', 'All Languages'),
              ...SupportedLanguages.languageEntries.map(
                (entry) => _buildLanguageChip(entry.key, entry.value.name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String code, String name) {
    final isSelected = _selectedLanguages.contains(code);

    return GestureDetector(
      onTap: () => _toggleLanguage(code),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code != 'all') ...[
              Text(SupportedLanguages.getLanguageFlag(code),
                  style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
            ],
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLanguage(String code) {
    setState(() {
      if (code == 'all') {
        _selectedLanguages = ['all'];
      } else {
        _selectedLanguages.remove('all');

        if (_selectedLanguages.contains(code)) {
          _selectedLanguages.remove(code);
        } else {
          _selectedLanguages.add(code);
        }

        if (_selectedLanguages.isEmpty) {
          _selectedLanguages = ['all'];
        }
      }
    });
    _applyFilters();
  }

  Widget _buildSearchContent() {
    if (_searchController.text.isEmpty) {
      return _buildExploreContent();
    }

    // When searching, show tabs
    return Column(
      children: [
        // Search Tabs
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[400],
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_collection, size: 16),
                    SizedBox(width: 8),
                    Text('Reels'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 16),
                    SizedBox(width: 8),
                    Text('Users'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReelsTab(),
              _buildUsersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReelsTab() {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        if (reelProvider.isLoading) {
          return _buildLoadingState();
        }

        if (reelProvider.searchResults.isEmpty) {
          return _buildEmptyReelsState();
        }

        return _buildReelsGrid(reelProvider.searchResults);
      },
    );
  }

  Widget _buildUsersTab() {
    if (_isLoadingUsers) {
      return _buildLoadingState();
    }

    if (_userResults.isEmpty) {
      return _buildEmptyUsersState();
    }

    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: _userResults.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return _buildUserSearchItem(user);
      },
    );
  }

  Widget _buildEmptyReelsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No reels found',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          Text(
            'Try different keywords',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUsersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No users found',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          Text(
            'Try searching by username',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSearchItem(Map<String, dynamic> user) {
    final username = user['username'] as String;
    final displayName = user['displayName'] as String?;
    final bio = user['bio'] as String?;
    final profileImageUrl = user['profileImageUrl'] as String?;
    final followersCount = user['followersCount'] as int? ?? 0;

    // Determine what name to show
    final bool hasDisplayName = displayName != null && displayName.isNotEmpty;
    final String nameToShow = hasDisplayName ? displayName : username;
    final bool shouldShowUsername = hasDisplayName;

    // Check if this is the current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCurrentUser = authProvider.userId == user['uid'];

    return GestureDetector(
      onTap: () => _openUserProfile(user),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Profile Picture
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackAvatar(username),
                      ),
                    )
                  : _buildFallbackAvatar(username),
            ),

            SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameToShow,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shouldShowUsername) ...[
                    SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  if (bio != null && bio.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      bio,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Colors.grey[400]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(
                    '$followersCount followers',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Follow Button (if not current user)
            if (!isCurrentUser) ...[
              SizedBox(width: 16),
              _FollowButton(userId: user['uid']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String username) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(colors: [AppColors.aiPrimary, AppColors.primary]),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExploreContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendingSection(),
          SizedBox(height: 24),
          _buildLanguagesSection(),
        ],
      ),
    );
  }

  Widget _buildTrendingSection() {
    return FutureBuilder<List<AILanguageReel>>(
      future: FirebaseService.getTrendingReels(limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTrendingSkeleton();
        }

        // Always show trending if we have any data
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return _buildHorizontalSection(
            'Trending Now',
            'Most engaging content',
            snapshot.data!,
          );
        }

        // Only fall back to recent content if no data at all
        return Consumer<ReelProvider>(
          builder: (context, reelProvider, child) {
            final recentReels = reelProvider.homeReels.take(10).toList();
            if (recentReels.isEmpty) return SizedBox.shrink();

            return _buildHorizontalSection(
              'Recent Content',
              'Latest language learning videos',
              recentReels,
            );
          },
        );
      },
    );
  }

  Widget _buildHorizontalSection(
    String title,
    String subtitle,
    List<AILanguageReel> reels,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // Add "View All" button
            TextButton(
              onPressed: () => _showAllTrending(reels),
              child: Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              final reel = reels[index];
              return Container(
                width: 120,
                margin: EdgeInsets.only(right: 12),
                child: ReelGridItem(
                  reel: reel,
                  onTap: () => _openReel(reel),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAllTrending(List<AILanguageReel> reels) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'All Trending Content',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  return ReelGridItem(
                    reel: reels[index],
                    onTap: () {
                      Navigator.pop(context);
                      _openReel(reels[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagesSection() {
    return FutureBuilder<List<String>>(
      future: FirebaseService.getPopularLanguages(limit: 6),
      builder: (context, snapshot) {
        final popularLanguages =
            snapshot.data ?? ['en', 'es', 'fr', 'de', 'ja', 'ko'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Popular Languages',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              snapshot.hasData
                  ? 'Based on recent activity'
                  : 'Top language choices',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: popularLanguages.map((langCode) {
                final isSelected = _selectedLanguages.contains(langCode);
                return GestureDetector(
                  onTap: () => _selectLanguage(langCode),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          SupportedLanguages.getLanguageFlag(langCode),
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(width: 8),
                        Text(
                          SupportedLanguages.getLanguageName(langCode),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelsGrid(List<AILanguageReel> reels) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 9 / 16,
      ),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return ReelGridItem(
          reel: reel,
          onTap: () => _openReel(reel),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Searching...',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});

    // Debounce search
    Future.delayed(Duration(milliseconds: 500), () {
      if (_searchController.text == value && value.isNotEmpty) {
        _performSearch(value);
      }
    });
  }

  void _onSearchSubmitted(String value) {
    if (value.isNotEmpty) {
      _performSearch(value);
    }
  }

  void _performSearch(String query) async {
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);

    // Search reels (existing functionality)
    reelProvider.searchReels(query);

    // Search users (new functionality)
    setState(() => _isLoadingUsers = true);
    try {
      final userResults = await FirebaseService.searchUsers(query);
      setState(() {
        _userResults = userResults;
        _isLoadingUsers = false;
      });

      // AUTO-SWITCH TAB LOGIC
      // Wait a bit for reel search to complete
      await Future.delayed(Duration(milliseconds: 300));

      final hasReels = reelProvider.searchResults.isNotEmpty;
      final hasUsers = userResults.isNotEmpty;

      // Switch to the tab with results
      if (!hasReels && hasUsers) {
        // Only users found - switch to Users tab
        _tabController.animateTo(1);
      } else if (hasReels && !hasUsers) {
        // Only reels found - switch to Reels tab
        _tabController.animateTo(0);
      }
      // If both have results or both are empty, stay on current tab
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      context.showErrorSnackbar('Error searching users');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);
    reelProvider.searchReels('');
    setState(() {
      _userResults = [];
      _isLoadingUsers = false;
    });
  }

  void _applyFilters() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _selectLanguage(String language) {
    setState(() {
      _selectedLanguages = [language];
    });
    _applyFilters();
  }

  void _openReel(AILanguageReel reel) {
    // This would open the reel in a viewer
    context.showInfoSnackbar('Opening ${reel.authorName}\'s reel...');
  }

  void _openUserProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: user['uid'],
          username: user['username'],
        ),
      ),
    );
  }
}

// NEW: Separate StatefulWidget for follow button to handle its own state
class _FollowButton extends StatefulWidget {
  final String userId;

  const _FollowButton({required this.userId});

  @override
  __FollowButtonState createState() => __FollowButtonState();
}

class __FollowButtonState extends State<_FollowButton> {
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final following = await userProvider.isFollowing(widget.userId);
      if (mounted) {
        setState(() {
          _isFollowing = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error checking follow status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      bool success;
      if (_isFollowing) {
        success = await userProvider.unfollowUser(widget.userId);
      } else {
        success = await userProvider.followUser(widget.userId);
      }

      if (success && mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isFollowing ? 'Now following user' : 'Unfollowed user'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update follow status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // print('Error in _toggleFollow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: 90,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey[700] : AppColors.primary,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size(90, 36),
      ),
      child: Text(
        _isFollowing
            ? 'Unfollow'
            : 'Follow', // CHANGED: "Following" -> "Unfollow"
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FilterItem {
  final String value;
  final String label;

  FilterItem(this.value, this.label);
}
