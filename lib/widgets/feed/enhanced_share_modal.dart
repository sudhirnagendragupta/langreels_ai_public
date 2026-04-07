// lib/widgets/feed/enhanced_share_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/reel_provider.dart';
import '../../utils/app_utils.dart';

class EnhancedShareModal extends StatefulWidget {
  final AILanguageReel reel;

  const EnhancedShareModal({
    Key? key,
    required this.reel,
  }) : super(key: key);

  @override
  _EnhancedShareModalState createState() => _EnhancedShareModalState();
}

class _EnhancedShareModalState extends State<EnhancedShareModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _shareUrl => 'https://langreels.com/reel/${widget.reel.id}';

  String get _shareText {
    final title = widget.reel.originalText ?? 'Learn Languages with AI';
    final language = widget.reel.sourceLanguage ?? 'Language';
    return 'Check out this $language lesson: "$title" on LangReels! 🎓📱\n\n$_shareUrl';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildReelPreview(),
                  _buildShareOptions(),
                  _buildAnalytics(),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.share_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Share Reel',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelPreview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Video Thumbnail
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildDefaultThumbnail(),
            ),
          ),
          SizedBox(width: 16),

          // Reel Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reel.originalText ?? 'Learn Languages with AI',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (widget.reel.sourceLanguage ?? 'LANG').toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.aiPrimary,
                      size: 16,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'By ${widget.reel.authorName}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.3),
            AppColors.aiPrimary.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              widget.reel.sourceLanguage?.substring(0, 2).toUpperCase() ?? 'LA',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOptions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share to',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),

          // Primary Share Options
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildShareOption(
                icon: Icons.link,
                label: 'Copy Link',
                color: AppColors.primary,
                onTap: _copyLink,
              ),
              _buildShareOption(
                icon: Icons.share,
                label: 'More Apps',
                color: Colors.blue,
                onTap: _shareToNativeSheet,
              ),
              _buildShareOption(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: Color(0xFF25D366),
                onTap: _shareToWhatsApp,
              ),
              _buildShareOption(
                icon: Icons.facebook,
                label: 'Facebook',
                color: Color(0xFF1877F2),
                onTap: _shareToFacebook,
              ),
            ],
          ),

          SizedBox(height: 20),

          // Secondary Share Options
          Column(
            children: [
              _buildShareListItem(
                icon: Icons.camera_alt,
                label: 'Instagram Stories',
                subtitle: 'Share as story',
                color: Color(0xFFE4405F),
                onTap: _shareToInstagramStories,
              ),
              _buildShareListItem(
                icon: Icons.email,
                label: 'Email',
                subtitle: 'Send via email',
                color: Colors.orange,
                onTap: _shareViaEmail,
              ),
              _buildShareListItem(
                icon: Icons.sms,
                label: 'SMS',
                subtitle: 'Send as text message',
                color: Colors.green,
                onTap: _shareViaSMS,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareListItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAnalyticItem(
            icon: Icons.visibility,
            label: 'Views',
            value: widget.reel.views,
          ),
          _buildAnalyticItem(
            icon: Icons.favorite,
            label: 'Likes',
            value: widget.reel.likes,
          ),
          _buildAnalyticItem(
            icon: Icons.share,
            label: 'Shares',
            value: widget.reel.shares,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticItem({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        SizedBox(height: 4),
        Text(
          value.formatted,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Share Actions
  void _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: _shareUrl));
      Navigator.pop(context);

      // Only increment on successful copy
      context.read<ReelProvider>().shareReel(widget.reel.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Link copied to clipboard!'),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      _showShareError('Failed to copy link');
    }
  }

  void _shareToNativeSheet() async {
    try {
      final title = widget.reel.originalText ?? 'Learn Languages with AI';
      final language = widget.reel.sourceLanguage ?? 'Language';
      final shareText =
          'Check out this $language lesson: "$title" on LangReels! 🎓📱\n\n$_shareUrl';

      await Share.share(
        shareText,
        subject: 'Check out this $language lesson on LangReels!',
      );

      // Only increment after successful share
      Navigator.pop(context);
      context.read<ReelProvider>().shareReel(widget.reel.id);
    } catch (e) {
      _showShareError('Failed to open share sheet');
    }
  }

  void _shareToWhatsApp() async {
    final title = widget.reel.originalText ?? 'Learn Languages with AI';
    final language = widget.reel.sourceLanguage ?? 'Language';
    final shareText =
        'Check out this $language lesson: "$title" on LangReels! 🎓📱\n\n$_shareUrl';
    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl),
            mode: LaunchMode.externalApplication);

        // Only increment on successful launch
        Navigator.pop(context);
        context.read<ReelProvider>().shareReel(widget.reel.id);
      } else {
        _showShareError('WhatsApp not installed');
      }
    } catch (e) {
      _showShareError('Failed to open WhatsApp');
    }
  }

  void _shareToFacebook() async {
    final facebookUrl =
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareUrl)}';

    try {
      if (await canLaunchUrl(Uri.parse(facebookUrl))) {
        await launchUrl(Uri.parse(facebookUrl),
            mode: LaunchMode.externalApplication);

        // Only increment on successful launch
        Navigator.pop(context);
        context.read<ReelProvider>().shareReel(widget.reel.id);
      } else {
        _showShareError('Failed to open Facebook');
      }
    } catch (e) {
      _showShareError('Failed to open Facebook');
    }
  }

  void _shareToInstagramStories() async {
    // Instagram Stories sharing would require more complex implementation
    // For now, show coming soon message with better UX
    _showComingSoonDialog('Instagram Stories');
  }

  void _shareViaEmail() async {
    final title = widget.reel.originalText ?? 'Learn Languages with AI';
    final language = widget.reel.sourceLanguage ?? 'Language';
    final shareText =
        'Check out this $language lesson: "$title" on LangReels! 🎓📱\n\n$_shareUrl';
    final emailUrl =
        'mailto:?subject=${Uri.encodeComponent('Check out this $language lesson on LangReels!')}&body=${Uri.encodeComponent(shareText)}';

    try {
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));

        // Only increment on successful launch
        Navigator.pop(context);
        context.read<ReelProvider>().shareReel(widget.reel.id);
      } else {
        _showShareError('No email app found');
      }
    } catch (e) {
      _showShareError('Failed to open email');
    }
  }

  void _shareViaSMS() async {
    final title = widget.reel.originalText ?? 'Learn Languages with AI';
    final language = widget.reel.sourceLanguage ?? 'Language';
    final shareText =
        'Check out this $language lesson: "$title" on LangReels! 🎓📱\n\n$_shareUrl';
    final smsUrl = 'sms:?body=${Uri.encodeComponent(shareText)}';

    try {
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));

        // Only increment on successful launch
        Navigator.pop(context);
        context.read<ReelProvider>().shareReel(widget.reel.id);
      } else {
        _showShareError('SMS not available');
      }
    } catch (e) {
      _showShareError('Failed to open SMS');
    }
  }

  void _showShareError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.upcoming, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Coming Soon!',
              style: AppTextStyles.h4.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          '$platform sharing will be available in the next update. Stay tuned!',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
