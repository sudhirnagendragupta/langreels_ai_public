// lib/widgets/video/study_mode_controls.dart - Fixed version with better UI

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';

class StudyModeControls extends StatelessWidget {
  final AILanguageReel reel;
  final int currentSentenceIndex;
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onTogglePlay;
  final Function(double)? onSpeedChanged;

  const StudyModeControls({
    Key? key,
    required this.reel,
    required this.currentSentenceIndex,
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    required this.onTogglePlay,
    this.onSpeedChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!reel.isSentenceBasedLearning) {
      return SizedBox.shrink();
    }

    final totalSentences = reel.totalSentences;
    final currentSentence = currentSentenceIndex >= 0 &&
            currentSentenceIndex < reel.sentences!.length
        ? reel.sentences![currentSentenceIndex]
        : null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          if (currentSentence != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sentence ${currentSentenceIndex + 1} of $totalSentences',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Sentence
              _buildControlButton(
                icon: Icons.skip_previous,
                onTap: currentSentenceIndex > 0 ? onPrevious : null,
                enabled: currentSentenceIndex > 0,
                tooltip: 'Previous sentence',
              ),

              // Replay Current
              _buildControlButton(
                icon: Icons.replay,
                onTap: currentSentence != null ? onReplay : null,
                enabled: currentSentence != null,
                tooltip: 'Replay sentence',
              ),

              // Play/Pause
              _buildControlButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                onTap: onTogglePlay,
                enabled: true,
                isPrimary: true,
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),

              // Speed control (placeholder for future feature)
              _buildControlButton(
                icon: Icons.speed,
                onTap: () => _showSpeedControl(context),
                enabled: true,
                tooltip: 'Playback speed',
              ),

              // Next Sentence
              _buildControlButton(
                icon: Icons.skip_next,
                onTap:
                    currentSentenceIndex < totalSentences - 1 ? onNext : null,
                enabled: currentSentenceIndex < totalSentences - 1,
                tooltip: 'Next sentence',
              ),
            ],
          ),

          // Sentence progress bar
          if (totalSentences > 1) ...[
            SizedBox(height: 12),
            _buildProgressBar(totalSentences, currentSentenceIndex),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
    bool isPrimary = false,
    String? tooltip,
  }) {
    Color backgroundColor;
    Color iconColor;

    if (isPrimary) {
      backgroundColor = AppColors.primary.withOpacity(enabled ? 0.3 : 0.1);
      iconColor = enabled ? AppColors.primary : Colors.grey;
    } else {
      backgroundColor = Colors.grey.withOpacity(enabled ? 0.2 : 0.1);
      iconColor = enabled ? Colors.white : Colors.grey;
    }

    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
    );

    if (tooltip != null && enabled) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }

  Widget _buildProgressBar(int totalSentences, int currentIndex) {
    return Row(
      children: List.generate(totalSentences, (index) {
        final isActive = index == currentIndex;
        final isCompleted = index < currentIndex;

        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 1),
            height: 3,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : isCompleted
                      ? AppColors.primary.withOpacity(0.6)
                      : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  void _showSpeedControl(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20), // Reduced from 24
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Playback Speed',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16), // Reduced from 20

            // Make the speed options scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: speeds
                      .map((speed) => ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8), // Reduced padding
                            title: Text(
                              '${speed}x ${speed == 1.0 ? "(Normal)" : ""}',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: Colors.white),
                            ),
                            onTap: () {
                              onSpeedChanged?.call(speed);
                              Navigator.pop(context);
                            },
                          ))
                      .toList(),
                ),
              ),
            ),

            SizedBox(height: 12), // Reduced from 16
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
