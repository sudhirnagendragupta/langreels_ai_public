// lib/widgets/video/video_preview_widget.dart

import 'package:flutter/material.dart';
import 'dart:io';
import '../../constants/app_constants.dart';

class VideoPreviewWidget extends StatelessWidget {
  final File videoFile;

  const VideoPreviewWidget({
    Key? key,
    required this.videoFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Video preview placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.play_circle_filled,
                    color: AppColors.primary,
                    size: 64,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Video Preview',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ready to process with AI',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),

          // File info overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      videoFile.path.split('/').last,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _getFileSize(),
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFileSize() {
    try {
      final bytes = videoFile.lengthSync();
      return _formatFileSize(bytes);
    } catch (e) {
      return 'Unknown size';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;

    double size = bytes / (1 << (i * 10));
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
