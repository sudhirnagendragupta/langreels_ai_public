// lib/widgets/video/sentence_video_player.dart - FIXED: Add state callback

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../models/sentence_data.dart';
import '../../providers/auth_provider.dart';
import '../../screens/main_screen.dart';

class SentenceVideoPlayer extends StatefulWidget {
  final AILanguageReel reel;
  final bool isVisible;
  final bool isStudyMode;
  final VoidCallback? onVideoTap;
  final Function(int)? onSentenceChanged;

  // NEW: Callback to pass the state to parent
  final Function(SentenceVideoPlayerState)? onPlayerStateCreated;

  const SentenceVideoPlayer({
    Key? key,
    required this.reel,
    required this.isVisible,
    this.isStudyMode = false,
    this.onVideoTap,
    this.onSentenceChanged,
    this.onPlayerStateCreated, // NEW parameter
  }) : super(key: key);

  @override
  SentenceVideoPlayerState createState() => SentenceVideoPlayerState();
}

class SentenceVideoPlayerState extends State<SentenceVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  int _currentSentenceIndex = -1;
  double _currentVideoPosition = 0.0;
  String _userLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _getUserLanguage();
    _initializeVideo();

    // NEW: Notify parent of state creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayerStateCreated?.call(this);
    });
  }

  @override
  void didUpdateWidget(SentenceVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reel.id != widget.reel.id) {
      _initializeVideo();
    }

    // Enhanced visibility change handling with immediate response
    if (oldWidget.isVisible != widget.isVisible) {
      // Immediate response to visibility change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleVisibilityChangeImmediate();
        }
      });

      // Also handle it synchronously
      _handleVisibilityChangeImmediate();
    }

    // NEW: Update parent callback when widget updates
    if (oldWidget.onPlayerStateCreated != widget.onPlayerStateCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPlayerStateCreated?.call(this);
      });
    }
  }

  void _getUserLanguage() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languagePrefs = authProvider.userProfile?['languagePreferences']
          as Map<String, dynamic>?;
      _userLanguage = languagePrefs?['primaryLanguage'] as String? ?? 'en';
      // print('🌍 Loaded language: $_userLanguage');
    } catch (e) {
      _userLanguage = 'en';
    }
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller?.dispose();

      _controller = VideoPlayerController.network(widget.reel.videoUrl);
      await _controller!.initialize();

      _controller!.addListener(_onVideoPositionChanged);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Auto-play when visible and initialized
        if (widget.isVisible) {
          _play();
        }
      }
    } catch (e) {
      // print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _onVideoPositionChanged() {
    if (_controller == null || !mounted) return;

    final position = _controller!.value.position.inMilliseconds / 1000.0;
    _currentVideoPosition = position;

    if (widget.reel.isSentenceBasedLearning) {
      final newSentenceIndex = _getCurrentSentenceIndex(position);
      if (newSentenceIndex != _currentSentenceIndex) {
        setState(() {
          _currentSentenceIndex = newSentenceIndex;
        });
        widget.onSentenceChanged?.call(newSentenceIndex);
      }
    }

    // Auto-loop
    if (_controller!.value.position >= _controller!.value.duration) {
      _controller!.seekTo(Duration.zero);
    }
  }

  void _handleVisibilityChangeImmediate() {
    if (!_isInitialized) return;

    if (widget.isVisible && !_isPlaying) {
      _play();
    } else if (!widget.isVisible && _isPlaying) {
      _pause();
    }
  }

  bool _isOnActiveHomeTab() {
    try {
      final mainScreenState =
          context.findAncestorStateOfType<MainScreenState>();
      if (mainScreenState == null) return false;
      return mainScreenState.currentIndex == 0;
    } catch (e) {
      return false;
    }
  }

  void _play() {
    _controller?.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _pause() {
    _controller?.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  // Public method for external controls
  void togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _togglePlayPause() {
    togglePlayPause();
  }

  // Public method for study mode controls
  void seekToSentence(int sentenceIndex) {
    if (!_isInitialized || !widget.reel.isSentenceBasedLearning) return;

    final sentence = widget.reel.getSentenceByIndex(sentenceIndex);
    if (sentence != null) {
      final position =
          Duration(milliseconds: (sentence.startTime * 1000).round());
      _controller!.seekTo(position);
      setState(() {
        _currentSentenceIndex = sentenceIndex;
        _currentVideoPosition = sentence.startTime;
      });
      widget.onSentenceChanged?.call(sentenceIndex);
    }
  }

  // Public method for study mode controls
  void replaySentence() {
    if (_currentSentenceIndex >= 0) {
      seekToSentence(_currentSentenceIndex);
      _play();
    }
  }

  // Public getter for study mode controls
  bool get isPlaying => _isPlaying;

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPositionChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<AuthProvider>(context); // Listen to changes!
    final languagePrefs = authProvider.userProfile?['languagePreferences']
        as Map<String, dynamic>?;
    final currentLanguage =
        languagePrefs?['primaryLanguage'] as String? ?? 'en';

    if (_userLanguage != currentLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _userLanguage = currentLanguage);
      });
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            _togglePlayPause();
            widget.onVideoTap?.call();
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        ),
        if (!_isPlaying)
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 60),
            ),
          ),
        if (widget.reel.isSentenceBasedLearning &&
            _currentSentenceIndex >= 0 &&
            _currentSentenceIndex < widget.reel.sentences!.length)
          _buildSentenceSubtitle(widget.reel.sentences![_currentSentenceIndex]),
      ],
    );
  }

  Widget _buildSentenceSubtitle(SentenceData sentence) {
    return widget.isStudyMode
        ? _buildFullSentenceSubtitle(sentence)
        : _buildProgressiveWordSubtitle(sentence);
  }

  Widget _buildProgressiveWordSubtitle(SentenceData sentence) {
    final sourceLanguage = widget.reel.sourceLanguage ?? 'en';
    final translation = sentence.getTranslation(_userLanguage);
    final isTranslated =
        sentence.originalText != translation && sourceLanguage != _userLanguage;
    final progressiveText = _buildProgressiveText(sentence);
    final progressiveTranslation = isTranslated
        ? _buildProgressiveTranslationText(sentence, _userLanguage)
        : null;

    if (progressiveText.isEmpty) return SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 16,
      right: 80,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(progressiveText,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2),
            if (progressiveTranslation != null &&
                progressiveTranslation.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(progressiveTranslation,
                  style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullSentenceSubtitle(SentenceData sentence) {
    final sourceLanguage = widget.reel.sourceLanguage ?? 'en';
    final translation = sentence.getTranslation(_userLanguage);
    final isTranslated =
        sentence.originalText != translation && sourceLanguage != _userLanguage;

    return Positioned(
      bottom: 160,
      left: 16,
      right: 80,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(SupportedLanguages.getLanguageFlag(sourceLanguage),
                    style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text(SupportedLanguages.getLanguageName(sourceLanguage),
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
            SizedBox(height: 8),
            if (isTranslated) ...[
              Text(sentence.originalText,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.left),
              SizedBox(height: 6),
            ],
            Text(translation,
                style: TextStyle(
                    color:
                        isTranslated ? AppColors.textSecondary : Colors.white,
                    fontSize: isTranslated ? 14 : 16,
                    fontStyle:
                        isTranslated ? FontStyle.italic : FontStyle.normal,
                    fontWeight:
                        isTranslated ? FontWeight.normal : FontWeight.w600),
                textAlign: TextAlign.left),
          ],
        ),
      ),
    );
  }

  String _buildProgressiveText(SentenceData sentence) {
    if (sentence.words == null || sentence.words!.isEmpty) {
      return sentence.originalText;
    }

    List<String> revealedWords = [];
    for (final word in sentence.words!) {
      if (_currentVideoPosition >= word.startTime) {
        revealedWords.add(word.word);
      } else {
        break;
      }
    }

    // For single words or if no words revealed yet, show the full text
    if (revealedWords.isEmpty || sentence.words!.length == 1) {
      return sentence.originalText;
    }

    return revealedWords.join(' ');
  }

  String _buildProgressiveTranslationText(
      SentenceData sentence, String userLanguage) {
    final translation = sentence.getTranslation(userLanguage);

    if (sentence.words == null || sentence.words!.isEmpty) {
      // For content without word-level data, show full translation when active
      return translation;
    }

    // For single words, always show full translation
    if (sentence.words!.length == 1) {
      return translation;
    }

    final originalWords = sentence.words!;
    final translationWords = translation.split(' ');

    int visibleOriginalCount = 0;
    for (final word in originalWords) {
      if (_currentVideoPosition >= word.startTime) {
        visibleOriginalCount++;
      } else {
        break;
      }
    }

    if (originalWords.isEmpty) return translation;

    // If no words are visible yet, still show translation for single words
    if (visibleOriginalCount == 0 && originalWords.length == 1) {
      return translation;
    }

    final progressRatio = visibleOriginalCount / originalWords.length;
    final visibleTranslationCount = (progressRatio * translationWords.length)
        .round()
        .clamp(0, translationWords.length);

    final result = translationWords.take(visibleTranslationCount).join(' ');

    // If nothing to show yet, return full translation for short content
    return result.isEmpty && translationWords.length <= 3
        ? translation
        : result;
  }

  int _getCurrentSentenceIndex(double videoPosition) {
    if (!widget.reel.isSentenceBasedLearning) return -1;

    for (int i = 0; i < widget.reel.sentences!.length; i++) {
      final sentence = widget.reel.sentences![i];
      if (sentence.isActiveAt(videoPosition)) {
        return i;
      }
    }
    return -1;
  }

  void setPlaybackSpeed(double speed) {
    _controller?.setPlaybackSpeed(speed);
  }
}
