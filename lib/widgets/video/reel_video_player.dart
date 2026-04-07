// lib/widgets/video/reel_video_player.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../constants/app_constants.dart';

class ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isVisible;
  final VoidCallback? onVideoTap;

  const ReelVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.isVisible,
    this.onVideoTap,
  }) : super(key: key);

  @override
  _ReelVideoPlayerState createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeVideo();
    }

    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange();
    }
  }

  void _initializeVideo() async {
    _controller?.dispose();

    _controller = VideoPlayerController.network(widget.videoUrl);

    try {
      await _controller!.initialize();
      _controller!.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.isVisible) {
          _play();
        }
      }
    } catch (e) {
      // print('Error initializing video: $e');
    }
  }

  void _handleVisibilityChange() {
    if (!_isInitialized) return;

    if (widget.isVisible) {
      _play();
    } else {
      _pause();
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

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return GestureDetector(
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
    );
  }
}
