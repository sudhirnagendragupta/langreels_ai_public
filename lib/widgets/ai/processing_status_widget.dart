// lib/widgets/ai/processing_status_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_utils.dart';

class ProcessingStatusWidget extends StatefulWidget {
  final String reelId;
  final VoidCallback onProcessingComplete;
  final Function(String) onProcessingFailed;

  const ProcessingStatusWidget({
    Key? key,
    required this.reelId,
    required this.onProcessingComplete,
    required this.onProcessingFailed,
  }) : super(key: key);

  @override
  _ProcessingStatusWidgetState createState() => _ProcessingStatusWidgetState();
}

class _ProcessingStatusWidgetState extends State<ProcessingStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AILanguageReel?>(
      stream: FirebaseService.watchReelProcessingStatus(widget.reelId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final reel = snapshot.data!;

        // Handle completion
        if (reel.processingStatus == ProcessingStatus.completed &&
            reel.isProcessed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onProcessingComplete();
          });
        }

        // Handle failure
        if (reel.processingStatus == ProcessingStatus.failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onProcessingFailed(reel.processingError ?? 'Unknown error');
          });
        }

        return _buildProcessingUI(reel);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            'Connecting to AI processor...',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingUI(AILanguageReel reel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress Circle
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              children: [
                // Background circle
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
                ),

                // Progress circle
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  child: CircularProgressIndicator(
                    value: reel.processingProgress,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ProcessingStatusColors.getStatusColor(
                          reel.processingStatus.name),
                    ),
                  ),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                ),

                // Center icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ProcessingStatusColors.getStatusColor(
                          reel.processingStatus.name),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      _getStatusIcon(reel.processingStatus),
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 32),

          // Status title
          Text(
            ProcessingStatusColors.getStatusMessage(reel.processingStatus.name),
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 12),

          // Progress percentage
          Text(
            '${(reel.processingProgress * 100).round()}% Complete',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.grey[400],
            ),
          ),

          SizedBox(height: 24),

          // Processing steps
          _buildProcessingSteps(reel.processingStatus),

          SizedBox(height: 32),

          // Estimated time remaining
          if (reel.estimatedTimeRemaining > 0)
            Text(
              'Estimated time: ${_formatDuration(Duration(seconds: reel.estimatedTimeRemaining))}',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingSteps(ProcessingStatus currentStatus) {
    final steps = ProcessingStatus.values
        .where((status) => status != ProcessingStatus.failed)
        .toList();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Processing Pipeline',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isCompleted = step.index <= currentStatus.index;
              final isCurrent = step == currentStatus;

              return Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? ProcessingStatusColors.getStatusColor(step.name)
                          : Colors.grey[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getStepName(step),
                    style: AppTextStyles.caption.copyWith(
                      color: isCurrent ? Colors.white : Colors.grey[500],
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.uploading:
        return Icons.cloud_upload;
      case ProcessingStatus.moderating:
        return Icons.security;
      case ProcessingStatus.extractingAudio:
        return Icons.audiotrack;
      case ProcessingStatus.transcribing:
        return Icons.hearing;
      case ProcessingStatus.translating:
        return Icons.translate;
      case ProcessingStatus.completed:
        return Icons.check;
      case ProcessingStatus.failed:
        return Icons.error;
    }
  }

  String _getStepName(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.uploading:
        return 'Upload';
      case ProcessingStatus.moderating:
        return 'Moderate';
      case ProcessingStatus.extractingAudio:
        return 'Extract';
      case ProcessingStatus.transcribing:
        return 'Transcribe';
      case ProcessingStatus.translating:
        return 'Translate';
      case ProcessingStatus.completed:
        return 'Complete';
      case ProcessingStatus.failed:
        return 'Failed';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
