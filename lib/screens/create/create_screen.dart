// lib/screens/create/create_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../services/firebase_service.dart';
// import '../../utils/app_utils.dart';
// import '../../utils/user_profile_extensions.dart';
import '../../widgets/video/video_preview_widget.dart';
import '../main_screen.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

class CreateScreen extends StatefulWidget {
  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen>
    with TickerProviderStateMixin {
  XFile? _videoFile;
  String? _currentReelId;
  bool _isUploading = false;
  bool _isProcessing = false;
  StreamSubscription? _processingSubscription;

  late AnimationController _promptAnimationController;
  late Animation<double> _promptAnimation;

  // Suggested prompts for content inspiration
  final List<PromptSuggestion> _suggestedPrompts = [
    PromptSuggestion(
      title: 'Daily Greetings',
      prompt:
          'Teach how to say "Good morning" and greet people in your language',
      icon: '👋',
      color: AppColors.success,
      examples: ['Hello, how are you?', 'Good morning!', 'Nice to meet you'],
    ),
    PromptSuggestion(
      title: 'Food & Dining',
      prompt: 'Show how to order food or talk about your favorite dish',
      icon: '🍜',
      color: AppColors.warning,
      examples: ['I would like...', 'This is delicious', 'The check, please'],
    ),
    PromptSuggestion(
      title: 'Directions & Travel',
      prompt: 'Teach essential phrases for asking directions',
      icon: '🗺️',
      color: AppColors.info,
      examples: ['Where is...?', 'How do I get to...?', 'Excuse me'],
    ),
    PromptSuggestion(
      title: 'Numbers & Time',
      prompt: 'Count numbers or explain how to tell time',
      icon: '🕐',
      color: AppColors.secondary,
      examples: ['One, two, three...', 'What time is it?', 'It\'s 3 o\'clock'],
    ),
    PromptSuggestion(
      title: 'Emotions & Feelings',
      prompt: 'Express different emotions and feelings',
      icon: '😊',
      color: AppColors.aiAccent,
      examples: ['I am happy', 'I feel sad', 'I\'m excited'],
    ),
    PromptSuggestion(
      title: 'Shopping & Prices',
      prompt: 'Show how to ask about prices and shop',
      icon: '🛒',
      color: AppColors.aiPrimary,
      examples: ['How much is this?', 'Can I try this on?', 'I\'ll take it'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _promptAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _promptAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _promptAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _processingSubscription?.cancel();
    _promptAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: (_isUploading || _isProcessing)
            ? _buildUploadingState()
            : _buildCreateContent(),
      ),
    );
  }

  Widget _buildCreateContent() {
    if (_videoFile != null) {
      return _buildVideoPreview();
    } else {
      return _buildInitialState();
    }
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Create AI-Powered Reel',
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Record or select a video and let AI handle the rest',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
          ),

          SizedBox(height: 32),

          // Record Button
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showRecordingOptions,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _promptAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_promptAnimation.value * 0.1),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Start Recording',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Max 2 minutes • AI will process automatically',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 32),

          // Suggested Prompts
          Text(
            'Need inspiration?',
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 16),

          // Prompt Cards
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedPrompts.length,
              itemBuilder: (context, index) {
                final prompt = _suggestedPrompts[index];
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(right: 12),
                  child: _buildPromptCard(prompt),
                );
              },
            ),
          ),

          SizedBox(height: 20),

          Text(
            '✨ Record anything you want to teach and AI will automatically make it available in 15+ languages',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(PromptSuggestion prompt) {
    return GestureDetector(
      onTap: () => _showPromptDetails(prompt),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: prompt.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: prompt.color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  prompt.icon,
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    prompt.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Expanded(
              child: Text(
                prompt.prompt,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[400],
                  fontSize: 11,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: _resetForm,
                icon: Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'Preview Video',
                  style: AppTextStyles.h4.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 48),
            ],
          ),

          SizedBox(height: 20),

          // Video Preview
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: VideoPreviewWidget(videoFile: File(_videoFile!.path)),
              ),
            ),
          ),

          SizedBox(height: 20),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadVideo,
              icon: Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                'Process with AI',
                style: AppTextStyles.buttonLarge.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          SizedBox(height: 12),

          Text(
            'AI will automatically transcribe, translate, and moderate your content',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Processing Animation
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  // Rotating outer ring
                  AnimatedBuilder(
                    animation: _promptAnimationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _promptAnimationController.value * 2 * 3.14159,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CustomPaint(
                            painter: SpinningArcPainter(
                              color: AppColors.primary,
                              strokeWidth: 4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Pulsing center
                  Center(
                    child: AnimatedBuilder(
                      animation: _promptAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.8 + (_promptAnimation.value * 0.2),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isUploading
                                  ? Icons.cloud_upload
                                  : Icons.auto_awesome,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            Text(
              _isUploading ? 'Uploading...' : 'Processing...',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12),

            Text(
              _isUploading
                  ? 'Your video is being uploaded'
                  : 'AI is transcribing, translating, and preparing your content',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    // Request permissions
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
        _showError('Camera and microphone permissions are required');
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? videoFile = await picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: AppConstants.maxVideoDurationSeconds),
      );

      if (videoFile != null) {
        final file = File(videoFile.path);

        // Check file size first
        final fileSizeInMB = await file.length() / (1024 * 1024);
        if (fileSizeInMB > AppConstants.maxVideoFileSizeMB) {
          _showError(
              'Video file is too large. Maximum size is ${AppConstants.maxVideoFileSizeMB}MB');
          return;
        }

        // Check video duration (for both camera and gallery)
        VideoPlayerController? tempController;
        try {
          tempController = VideoPlayerController.file(file);
          await tempController.initialize();
          final duration = tempController.value.duration;

          if (duration.inSeconds > AppConstants.maxVideoDurationSeconds) {
            final maxMinutes = AppConstants.maxVideoDurationSeconds ~/ 60;
            _showError(
                'Video is too long. Maximum duration is $maxMinutes minutes (${AppConstants.maxVideoDurationSeconds} seconds)');
            return;
          }
        } catch (e) {
          _showError('Failed to analyze video duration');
          return;
        } finally {
          tempController?.dispose();
        }

        setState(() {
          _videoFile = videoFile;
        });
      }
    } catch (e) {
      _showError('Failed to pick video: ${e.toString()}');
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isUploading = true;
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        _showError('Please log in to upload videos');
        return;
      }

      // Upload video
      final videoUrl = await FirebaseService.uploadVideo(
        videoFile: File(_videoFile!.path),
        userId: authProvider.userId!,
      );

      if (videoUrl == null) {
        _showError('Failed to upload video');
        return;
      }

      // print('User ID: ${authProvider.userId}');
      // print('User email: ${authProvider.user?.email}');
      // print('User display name: ${authProvider.user?.displayName}');
      // print('User profile: ${authProvider.userProfile}');
      // Create initial reel document
      final reelId = await FirebaseService.createInitialReel(
        videoUrl: videoUrl,
        authorId: authProvider.userId!,
        authorName: authProvider.userProfile?['username'] as String? ??
            authProvider.user?.email?.split('@')[0] ??
            'User${authProvider.userId?.substring(0, 6)}',
        authorDisplayName: authProvider.userProfile?['displayName']
            as String?, // NEW: Pass display name
      );

      if (reelId != null) {
        setState(() {
          _currentReelId = reelId;
          _isUploading = false;
          // Keep _isProcessing = true
        });

        // Start monitoring processing status
        _monitorProcessingStatus();
      } else {
        _showError('Failed to create reel');
      }
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _resetForm() {
    // Cancel any active subscriptions first
    _processingSubscription?.cancel();

    // CRITICAL FIX: Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _videoFile = null;
        _currentReelId = null;
        _isUploading = false;
        _isProcessing = false;
      });
    }
  }

  void _monitorProcessingStatus() {
    if (_currentReelId == null) return;

    _processingSubscription?.cancel();

    _processingSubscription =
        FirebaseService.watchReelProcessingStatus(_currentReelId!)
            .listen((reel) async {
      if (!mounted) return;

      if (reel != null &&
          reel.processingStatus == ProcessingStatus.completed &&
          reel.isProcessed) {
        // WAIT for translation data to be fully loaded before showing success
        try {
          final reelWithTranslations =
              await FirebaseService.getReelByIdWithSentences(_currentReelId!);

          if (reelWithTranslations != null) {
            // Update the provider with the complete reel data
            Provider.of<ReelProvider>(context, listen: false)
                .refreshReel(_currentReelId!);

            setState(() {
              _isProcessing = false;
            });

            // Now show success popup with the complete reel
            _showFinalSuccess(reelWithTranslations);
          }
        } catch (e) {
          print('Error loading complete reel data: $e');
          // Fallback to showing success with basic reel
          setState(() {
            _isProcessing = false;
          });
          _showFinalSuccess(reel);
        }
      }
    });
  }

  void _showFinalSuccess(AILanguageReel? completedReel) {
    final screenContext = context;
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);
    final mainScreenState =
        screenContext.findAncestorStateOfType<MainScreenState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            ),
            SizedBox(height: 16),
            Text(
              'Your AI-Powered Reel is Ready!',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Your content has been processed and is now available worldwide in multiple languages!',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: Text('Create Another',
                style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();

              if (mainScreenState != null && completedReel != null) {
                reelProvider.addReelToTop(completedReel);
                mainScreenState.navigateToTab(0);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('View Reel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecordingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Record Your Reel',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            _buildOptionButton(
              icon: Icons.videocam,
              title: 'Record Video',
              subtitle: 'Use camera to record (max 2 min)',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            SizedBox(height: 16),
            _buildOptionButton(
              icon: Icons.video_library,
              title: 'Choose from Gallery',
              subtitle: 'Select existing video',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  void _showPromptDetails(PromptSuggestion prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(prompt.icon, style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                prompt.title,
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt.prompt,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[300]),
            ),
            SizedBox(height: 16),
            Text(
              'Example phrases:',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            ...prompt.examples.map((example) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $example',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

class PromptSuggestion {
  final String title;
  final String prompt;
  final String icon;
  final Color color;
  final List<String> examples;

  PromptSuggestion({
    required this.title,
    required this.prompt,
    required this.icon,
    required this.color,
    required this.examples,
  });
}

class SpinningArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  SpinningArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
