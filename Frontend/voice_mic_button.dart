import 'package:flutter/material.dart';
import '../../services/voice_navigation_service.dart';
import '../../theme/app_theme.dart';

/// Widget مشترك للميكروفون يمكن إضافته لأي صفحة
class VoiceMicButton extends StatefulWidget {
  final int userId;
  final BuildContext? parentContext;
  
  const VoiceMicButton({
    super.key,
    required this.userId,
    this.parentContext,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  final VoiceNavigationService _voiceNav = VoiceNavigationService();
  bool _isVoiceModeActive = false;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _checkVoiceModeStatus();
  }

  Future<void> _initializeVoice() async {
    final context = widget.parentContext ?? this.context;
    if (context.mounted) {
      await _voiceNav.initialize(context, widget.userId);
    }
  }

  void _checkVoiceModeStatus() {
    // التحقق من حالة وضع الصوت بشكل دوري
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVoiceModeActive = _voiceNav.isVoiceModeActive;
        });
        _checkVoiceModeStatus();
      }
    });
  }

  Future<void> _toggleVoiceMode() async {
    if (_isVoiceModeActive) {
      await _voiceNav.disableVoiceMode();
      setState(() => _isVoiceModeActive = false);
    } else {
      await _voiceNav.enableVoiceMode();
      setState(() => _isVoiceModeActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: _toggleVoiceMode,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _isVoiceModeActive ? AppTheme.success : AppTheme.secondaryBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_isVoiceModeActive ? AppTheme.success : AppTheme.secondaryBlue).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            _isVoiceModeActive ? Icons.mic : Icons.mic_none,
            color: AppTheme.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
