// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/reel_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/video/sentence_video_player.dart';
import '../../widgets/feed/reel_action_buttons.dart';
import '../../widgets/feed/sentence_info_overlay.dart';
import '../../widgets/video/study_mode_controls.dart';
import '../../widgets/ai/multi_select_language_filter_bar.dart';
import '../main_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(Function(bool))? onVisibilityChanged;

  const HomeScreen({
    Key? key,
    this.onVisibilityChanged,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();

  SentenceVideoPlayerState? _currentVideoPlayerState;

  int _currentIndex = 0;
  int _currentSentenceIndex = 0;
  bool _isStudyMode = false;
  bool _isVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (widget.onVisibilityChanged != null) {
      widget.onVisibilityChanged!((isVisible) {
        setState(() {
          _isVisible = isVisible;
        });
        if (isVisible) {
          _resumeCurrentVideo();
        } else {
          _pauseCurrentVideo();
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _pauseCurrentVideo() {
    if (_currentVideoPlayerState != null &&
        _currentVideoPlayerState!.isPlaying) {
      _currentVideoPlayerState!.togglePlayPause();
    }
  }

  void _resumeCurrentVideo() {
    if (!_isStudyMode) {
      if (_currentVideoPlayerState != null &&
          !_currentVideoPlayerState!.isPlaying) {
        _currentVideoPlayerState!.togglePlayPause();
      }
    }
  }

  void _toggleStudyMode() {
    setState(() {
      _isStudyMode = !_isStudyMode;
      _currentSentenceIndex = 0;
    });

    if (_currentVideoPlayerState != null) {
      if (_isStudyMode) {
        if (_currentVideoPlayerState!.isPlaying) {
          _currentVideoPlayerState!.togglePlayPause();
        }
      } else {
        if (!_currentVideoPlayerState!.isPlaying) {
          _currentVideoPlayerState!.togglePlayPause();
        }
      }
    }
  }

  void _onSentenceChanged(int index) {
    setState(() {
      _currentSentenceIndex = index;
    });
  }

  void _onVideoPlayerCreated(SentenceVideoPlayerState state) {
    _currentVideoPlayerState = state;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ReelProvider>(
        builder: (context, reelProvider, child) {
          final homeState = reelProvider.homeLoadingState;

          if (homeState == ReelLoadingState.loading) {
            return _buildLoadingState();
          }

          if (homeState == ReelLoadingState.empty) {
            return _buildEmptyState();
          }

          if (homeState == ReelLoadingState.error) {
            return _buildErrorState();
          }

          // Show reels if loaded
          return Stack(
            children: [
              // Main feed
              _buildReelsFeed(reelProvider.homeReels),

              // Top header with filters (hide in study mode)
              if (!_isStudyMode) _buildTopHeader(),

              // Language filter bar (hide in study mode)
              if (!_isStudyMode) _buildLanguageFilterBar(),

              // Study mode controls (show only in study mode)
              if (_isStudyMode) _buildStudyModeControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReelsFeed(List<AILanguageReel> reels) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _currentSentenceIndex = 0;
          _isStudyMode = false;
          _currentVideoPlayerState = null;
        });
      },
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        final isCurrentPage = _currentIndex == index;
        return _buildReelPage(reel, isCurrentPage);
      },
    );
  }

  Widget _buildReelPage(AILanguageReel reel, bool isCurrentPage) {
    return Stack(
      children: [
        // Video Player
        Positioned.fill(
          child: SentenceVideoPlayer(
            reel: reel,
            isVisible: _isVisible && isCurrentPage,
            isStudyMode: _isStudyMode,
            onSentenceChanged: _onSentenceChanged,
            onPlayerStateCreated: isCurrentPage ? _onVideoPlayerCreated : null,
          ),
        ),

        // Sentence Info Overlay
        Positioned(
          top: MediaQuery.of(context).padding.top + (_isStudyMode ? 30 : 60),
          left: 16,
          right: 80,
          child: SentenceInfoOverlay(
            reel: reel,
            currentSentenceIndex: _currentSentenceIndex,
            isStudyMode: _isStudyMode,
          ),
        ),

        // Action Buttons
        Positioned(
          bottom: _isStudyMode ? 120 : 80,
          right: 16,
          child: ReelActionButtons(
            reel: reel,
            isStudyMode: _isStudyMode,
            onToggleStudyMode:
                reel.isSentenceBasedLearning ? _toggleStudyMode : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.aiPrimary, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Loading AI-powered reels...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.aiPrimary, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 40,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No reels yet',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to create AI-powered language learning content!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final mainScreenState =
                    context.findAncestorStateOfType<MainScreenState>();
                mainScreenState?.navigateToTab(2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Create Reel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Unable to load reels. Please try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final reelProvider =
                    Provider.of<ReelProvider>(context, listen: false);
                reelProvider.loadHomeReels(refresh: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [],
            ),
            Consumer<ReelProvider>(
              builder: (context, reelProvider, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${reelProvider.homeReels.length}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageFilterBar() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: MultiSelectLanguageFilterBar(),
    );
  }

  Widget _buildStudyModeControls() {
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);
    if (reelProvider.homeReels.isEmpty ||
        _currentIndex >= reelProvider.homeReels.length) {
      return SizedBox.shrink();
    }

    final currentReel = reelProvider.homeReels[_currentIndex];
    if (!currentReel.isSentenceBasedLearning) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: StudyModeControls(
        reel: currentReel,
        currentSentenceIndex: _currentSentenceIndex,
        isPlaying: _currentVideoPlayerState?.isPlaying ?? false,
        onPrevious: () => _onStudyModeNavigation('previous'),
        onNext: () => _onStudyModeNavigation('next'),
        onReplay: () => _onStudyModeNavigation('replay'),
        onTogglePlay: () => _onStudyModeNavigation('togglePlay'),
        onSpeedChanged: (speed) {
          _currentVideoPlayerState?.setPlaybackSpeed(speed);
        },
      ),
    );
  }

  void _onStudyModeNavigation(String action) {
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);
    if (reelProvider.homeReels.isEmpty ||
        _currentIndex >= reelProvider.homeReels.length) return;

    final currentReel = reelProvider.homeReels[_currentIndex];
    if (!currentReel.isSentenceBasedLearning) return;

    if (_currentVideoPlayerState == null) return;

    switch (action) {
      case 'previous':
        if (_currentSentenceIndex > 0) {
          _currentVideoPlayerState!.seekToSentence(_currentSentenceIndex - 1);
        }
        break;
      case 'next':
        if (_currentSentenceIndex < currentReel.totalSentences - 1) {
          _currentVideoPlayerState!.seekToSentence(_currentSentenceIndex + 1);
        }
        break;
      case 'replay':
        _currentVideoPlayerState!.replaySentence();
        break;
      case 'togglePlay':
        _currentVideoPlayerState!.togglePlayPause();
        break;
    }
  }
}
