import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../widgets/voice_mic_button.dart';
import 'login_screen.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'voice_interaction_screen.dart';
import 'orders_screen.dart';
import 'returns_screen.dart';
import 'addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final VoiceService _voiceService = VoiceService();
  int _currentIndex = 0; // الحساب
  String _userName = 'وفاء';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
  }

  Future<void> _loadUserName() async {
    final name = await SessionManager.getUserName();
    if (name != null && mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.white,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                    // Header - "اهلا وفاء"
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 20),
                      child: Text(
                        'اهلا $_userName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF000000),
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Settings Items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildSettingsItem(
                            icon: Icons.assignment_outlined,
                            text: 'الطلبات',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrdersScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildSettingsItem(
                            icon: Icons.reply_outlined,
                            text: 'المرتجعات',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReturnsScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildSettingsItem(
                            icon: Icons.location_on_outlined,
                            text: 'العناوين',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddressesScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildSettingsItem(
                            icon: Icons.payment_outlined,
                            text: 'طرق الدفع',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentMethodsScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildSettingsItem(
                            icon: Icons.settings_outlined,
                            text: 'الإعدادات',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SettingsScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Logout Button at bottom
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildLogoutButton(),
                ),
              ],
            ),
          ),
            bottomNavigationBar: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Icon (Rightmost)
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF000000),
            ),
            const SizedBox(width: 12),
            // Text
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF000000),
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
            const Spacer(),
            // Arrow Icon (Leftmost)
            Icon(
              Icons.chevron_left,
              size: 18,
              color: const Color(0xFF000000),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        // مسح الجلسة
        await SessionManager.clearSession();
        _voiceService.speak('تم تسجيل الخروج');
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logout Icon (Rightmost)
            Icon(
              Icons.logout,
              size: 20,
              color: const Color(0xFFE53935),
            ),
            const SizedBox(width: 12),
            // Text - Centered and Bold
            const Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // الحساب
        // Already on profile screen
        break;
      case 1: // الفئات
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CategoriesScreen(userId: widget.userId),
          ),
        );
        break;
      case 2: // مايكروفون
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VoiceInteractionScreen(),
          ),
        );
        break;
      case 3: // السلة
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CartScreen(userId: widget.userId),
          ),
        );
        break;
      case 4: // الرئيسية
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductsScreen(userId: widget.userId),
          ),
        );
        break;
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // الرئيسية (index 4)
                _buildNavItem(Icons.home_outlined, Icons.home, 'الرئيسية', 4),
                // السلة (index 3)
                _buildNavItem(
                    Icons.shopping_cart_outlined, Icons.shopping_cart, 'السلة', 3),
                // Empty space for microphone button
                const SizedBox(width: 56),
                // الفئات (index 1)
                _buildNavItem(Icons.category_outlined, Icons.category, 'الفئات', 1),
                // الحساب (index 0)
                _buildNavItem(Icons.person_outline, Icons.person, 'الحساب', 0),
              ],
            ),
          ),
          // Floating Voice Button (Center)
          Center(
            child: GestureDetector(
              onTap: () => _onNavItemTapped(2),
              child: Icon(
                Icons.mic,
                size: 32,
                color: const Color(0xFF2979FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? const Color(0xFF2979FF) : const Color(0xFF9E9E9E),
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF2979FF) : const Color(0xFF9E9E9E),
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        ],
      ),
    );
  }
}
