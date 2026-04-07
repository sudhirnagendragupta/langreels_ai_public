// lib/widgets/video/reel_grid_item.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_utils.dart';

class ReelGridItem extends StatefulWidget {
  final AILanguageReel reel;
  final VoidCallback onTap;

  const ReelGridItem({
    Key? key,
    required this.reel,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ReelGridItem> createState() => _ReelGridItemState();
}

class _ReelGridItemState extends State<ReelGridItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.reel.videoUrl);
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // print('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Video thumbnail or placeholder
              _buildVideoThumbnail(),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Content overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Author and language
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              widget.reel.authorAvatar,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              // Use display name if available, otherwise username
                              widget.reel.authorDisplayName?.isNotEmpty == true
                                  ? widget.reel.authorDisplayName!
                                  : widget.reel.authorName,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6),

                      // Content preview with translation
                      if (widget.reel.originalText != null)
                        _buildTranslationPreview(),

                      SizedBox(height: 4),

                      // Stats
                      Row(
                        children: [
                          Icon(Icons.favorite, color: AppColors.like, size: 12),
                          SizedBox(width: 2),
                          Text(
                            widget.reel.likes.toString(),
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.visibility, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text(
                            widget.reel.views.toString(),
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Language tag (TOP LEFT)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SupportedLanguages.getLanguageFlag(
                            widget.reel.sourceLanguage ?? 'en'),
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 3),
                      Text(
                        SupportedLanguages.getLanguageName(
                            widget.reel.sourceLanguage ?? 'en'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Processing status indicator (if not processed)
              if (!widget.reel.isProcessed)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationPreview() {
    // print(
    //     '🔍 Translation preview called for ${widget.reel.id}: hasText=${widget.reel.originalText != null}');

    if (widget.reel.originalText == null || widget.reel.originalText!.isEmpty) {
      // print('❌ Returning empty - no original text');
      return SizedBox.shrink();
    }

    // print('✅ Building text widget');
    return Text(
      widget.reel.originalText!,
      style: AppTextStyles.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildVideoThumbnail() {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[900],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withOpacity(0.7),
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'Error loading\nvideo',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[900],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
