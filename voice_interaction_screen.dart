import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class VoiceInteractionScreen extends StatefulWidget {
  final Function(String)? onResult;
  
  const VoiceInteractionScreen({super.key, this.onResult});

  @override
  State<VoiceInteractionScreen> createState() => _VoiceInteractionScreenState();
}

class _VoiceInteractionScreenState extends State<VoiceInteractionScreen>
    with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  final ApiClient _apiClient = ApiClient();
  bool _isListening = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
    _voiceService.onSpeechResult = _handleSpeechResult;
  }

  void _handleSpeechResult(String text) {
    setState(() {
      _isListening = false;
      _recognizedText = text;
    });
    _pulseController.stop();
    _processVoiceCommand(text);
  }

  Future<void> _processVoiceCommand(String text) async {
    if (text.isEmpty || text == '__TIMEOUT__') {
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      return;
    }
    
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      final result = await _apiClient.processNLU(cleanedText);
      
      setState(() => _isProcessing = false);
      
      if (result['speak_text'] != null) {
        _voiceService.speak(result['speak_text']);
      }
      
      if (widget.onResult != null) {
        widget.onResult!(result['intent'] ?? 'unknown');
      }
      
      if (mounted && result['intent'] != 'unknown') {
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      print('Error processing voice command: $e');
      await _voiceService.speak('حدث خطأ أثناء معالجة الأمر. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    _pulseController.repeat(reverse: true);
    
    final success = await _voiceService.startListening();
    if (!success && mounted) {
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
      _voiceService.speak('فشل بدء الاستماع. يرجى المحاولة مرة أخرى');
    }
  }

  void _stopListening() {
    _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text(
          'التفاعل الصوتي',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_recognizedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.searchBarBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _recognizedText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'IBMPlexSansArabic',
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? AppTheme.success
                              : AppTheme.secondaryBlue,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? AppTheme.success
                                      : AppTheme.secondaryBlue)
                                  .withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 32),
            Text(
              _isListening
                  ? 'جاري الاستماع...'
                  : _isProcessing
                      ? 'جاري المعالجة...'
                      : 'اضغط على الميكروفون للتحدث',
              style: const TextStyle(
                fontSize: 18,
                fontFamily: 'IBMPlexSansArabic',
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

