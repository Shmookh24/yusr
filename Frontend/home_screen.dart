import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../../services/api_client.dart';
import '../widgets/voice_button.dart';
import '../widgets/voice_mic_button.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String userName;
  
  const HomeScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  final ApiClient _apiClient = ApiClient();
  bool _isListening = false;
  late AnimationController _animationController;
  late List<Animation<double>> _buttonAnimations;
  
  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _buttonAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.15,
            0.6 + (index * 0.15),
            curve: Curves.easeOut,
          ),
        ),
      );
    });
    
    _animationController.forward();
  }
  
  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
    _voiceService.onSpeechResult = _handleSpeechResult;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _voiceService.speak('مرحباً ${widget.userName}. كيف يمكنني مساعدتك اليوم؟');
    });
  }
  
  void _handleSpeechResult(String text) {
    setState(() => _isListening = false);
    _voiceService.stopListening();
    _processVoiceCommand(text);
  }
  
  Future<void> _processVoiceCommand(String text) async {
    // التعامل مع timeout أو نص فارغ
    if (text.isEmpty || text == '__TIMEOUT__') {
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      return;
    }
    
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      return;
    }
    
    print('Processing voice command: $cleanedText');
    
    try {
      final result = await _apiClient.processNLU(cleanedText);
      final intent = result['intent'] ?? 'unknown';
      
      print('NLU Intent: $intent');
      
      switch (intent) {
        case 'search_product':
          _navigateToProducts();
          break;
        case 'add_to_cart':
        case 'checkout':
          _navigateToCart();
          break;
        case 'order_status':
          _navigateToProfile();
          break;
        default:
          await _voiceService.speak(result['speak_text'] ?? 'لم أفهم طلبك');
      }
    } catch (e) {
      print('Error processing voice command: $e');
      await _voiceService.speak('حدث خطأ أثناء معالجة الأمر. يرجى المحاولة مرة أخرى');
    }
  }
  
  void _navigateToProducts() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProductsScreen(userId: widget.userId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  void _navigateToCart() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CartScreen(userId: widget.userId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  void _navigateToProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(userId: widget.userId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  void _startVoiceSearch() {
    setState(() => _isListening = true);
    _voiceService.speak('ما الذي تريد البحث عنه؟');
    _voiceService.startListening();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _voiceService.stopSpeaking();
    _voiceService.stopListening();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'يُسر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(userId: widget.userId),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                FadeTransition(
                  opacity: _buttonAnimations[0],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_buttonAnimations[0]),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'مرحباً',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.userName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isListening)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.9 + (value * 0.1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mic,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'جاري الاستماع...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'IBMPlexSansArabic',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _buttonAnimations[1],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_buttonAnimations[1]),
                    child: VoiceButton(
                      icon: Icons.search_rounded,
                      label: 'استمع وابحث',
                      onPressed: _startVoiceSearch,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _buttonAnimations[2],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_buttonAnimations[2]),
                    child: VoiceButton(
                      icon: Icons.shopping_cart_rounded,
                      label: 'السلة',
                      onPressed: _navigateToCart,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _buttonAnimations[3],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_buttonAnimations[3]),
                    child: VoiceButton(
                      icon: Icons.person_rounded,
                      label: 'حسابي',
                      onPressed: _navigateToProfile,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _buttonAnimations[3],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_buttonAnimations[3]),
                    child: VoiceButton(
                      icon: Icons.store_rounded,
                      label: 'تصفح المتجر',
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      onPressed: _navigateToProducts,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
          ),
          VoiceMicButton(userId: widget.userId, parentContext: context),
        ],
      ),
    );
  }
}
