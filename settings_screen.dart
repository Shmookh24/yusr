import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/voice_mic_button.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;

  const SettingsScreen({super.key, required this.userId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final VoiceService _voiceService = VoiceService();
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;
  String _ttsEngine = 'flutter_tts';
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _volume = prefs.getDouble('volume') ?? 1.0;
      _pitch = prefs.getDouble('pitch') ?? 1.0;
      _ttsEngine = prefs.getString('tts_engine') ?? 'flutter_tts';
    });
    await _voiceService.setSpeechRate(_speechRate);
    await _voiceService.setVolume(_volume);
    await _voiceService.setPitch(_pitch);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setDouble('volume', _volume);
    await prefs.setDouble('pitch', _pitch);
    await prefs.setString('tts_engine', _ttsEngine);
    await _voiceService.setSpeechRate(_speechRate);
    await _voiceService.setVolume(_volume);
    await _voiceService.setPitch(_pitch);
    await _voiceService.initialize(ttsEngine: _ttsEngine);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الإعدادات',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      _voiceService.speak('تم حفظ الإعدادات بنجاح');
    }
  }

  void _testVoice() {
    _voiceService.speak('هذا اختبار للصوت. يمكنك تعديل السرعة والحجم من الإعدادات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.white,
            appBar: AppBar(
              backgroundColor: AppTheme.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppTheme.textPrimary),
              title: const Text(
                'الإعدادات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.divider, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إعدادات الصوت',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'سرعة الكلام: ${(_speechRate * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: Slider(
                      value: _speechRate,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: AppTheme.secondaryBlue,
                      label: '${(_speechRate * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() => _speechRate = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'مستوى الصوت: ${(_volume * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: AppTheme.secondaryBlue,
                      label: '${(_volume * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() => _volume = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نبرة الصوت: ${(_pitch * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: Slider(
                      value: _pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      activeColor: AppTheme.secondaryBlue,
                      label: '${(_pitch * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() => _pitch = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'محرك الصوت',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'flutter_tts',
                        groupValue: _ttsEngine,
                        onChanged: (value) {
                          setState(() => _ttsEngine = value!);
                        },
                        activeColor: AppTheme.secondaryBlue,
                      ),
                      const Text('Flutter TTS', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'custom_model',
                        groupValue: _ttsEngine,
                        onChanged: (value) {
                          setState(() => _ttsEngine = value!);
                        },
                        activeColor: AppTheme.secondaryBlue,
                      ),
                      const Text('نموذج مخصص', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 280,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _testVoice,
                      icon: const Icon(Icons.volume_up),
                      label: const Text(
                        'اختبار الصوت',
                        style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryBlue,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.divider, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حول التطبيق',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'يُسر - منصة التسوق الصوتية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'يُسر هو تطبيق تسوق ذكي يعمل بالتحكم الصوتي بالكامل، مصمم خصيصاً لذوي الإعاقة البصرية والحركية. يتيح التطبيق للمستخدمين التسوق والتنقل وإدارة الطلبات باستخدام الأوامر الصوتية العربية فقط، دون الحاجة للمس الشاشة.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontFamily: 'IBMPlexSansArabic',
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الميزات الرئيسية:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureItem('• البحث عن المنتجات بالصوت'),
                  _buildFeatureItem('• إضافة المنتجات للسلة بالصوت'),
                  _buildFeatureItem('• إتمام الشراء بالصوت'),
                  _buildFeatureItem('• إدارة العناوين وطرق الدفع بالصوت'),
                  _buildFeatureItem('• وصف صوتي للصور'),
                  _buildFeatureItem('• فهم اللغة العربية بلهجات مختلفة'),
                  const SizedBox(height: 16),
                  const Text(
                    'الإصدار: 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'جميع الحقوق محفوظة © 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryBlue,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                'حفظ الإعدادات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
          ),
              ],
            ),
            bottomNavigationBar: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.store_outlined, Icons.store, 'المتجر', 0),
          _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'السلة', 1),
          _buildNavItem(Icons.person_outline, Icons.person, 'حسابي', 2),
          _buildNavItem(Icons.settings_outlined, Icons.settings, 'الإعدادات', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProductsScreen(userId: widget.userId),
            ),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CartScreen(userId: widget.userId),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.userId),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppTheme.secondaryBlue : AppTheme.iconGray,
            size: isActive ? 26 : 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? AppTheme.secondaryBlue : AppTheme.textSecondary,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          fontFamily: 'IBMPlexSansArabic',
        ),
      ),
    );
  }
}
