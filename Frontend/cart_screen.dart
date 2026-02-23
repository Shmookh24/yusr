import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../../services/db_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/voice_mic_button.dart';
import 'checkout_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'categories_screen.dart';
import 'voice_interaction_screen.dart';

class CartScreen extends StatefulWidget {
  final int userId;

  const CartScreen({super.key, required this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final VoiceService _voiceService = VoiceService();
  List<Map<String, dynamic>> _cartItems = [];
  double _total = 0.0;
  bool _isLoading = false;
  int _currentIndex = 3; // السلة

  @override
  void initState() {
    super.initState();
    _loadCart();
    _initializeVoice();
    _setupVoiceCommands();
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
  }

  void _setupVoiceCommands() {
    _voiceService.onSpeechResult = (text) async {
      await _handleVoiceCommand(text);
    };
  }

  Future<void> _handleVoiceCommand(String text) async {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('اشتري') ||
        lowerText.contains('شراء') ||
        lowerText.contains('دفع') ||
        lowerText.contains('تأكيد')) {
      await _proceedToCheckout();
    } else if (lowerText.contains('إجمالي') ||
        lowerText.contains('كم') ||
        lowerText.contains('السعر')) {
      _voiceService.speak('الإجمالي: $_total ريال');
    } else if (lowerText.contains('اقرأ') || lowerText.contains('اعرض')) {
      await _readCartContents();
    } else if (lowerText.contains('احذف') || lowerText.contains('شيل')) {
      // Extract product name and remove
      for (var item in _cartItems) {
        if (text.contains(item['name_ar'].toString().toLowerCase())) {
          await DBService.removeFromCart(item['id']);
          _loadCart();
          _voiceService.speak('تم حذف ${item['name_ar']} من السلة');
          return;
        }
      }
    }
  }

  Future<void> _readCartContents() async {
    if (_cartItems.isEmpty) {
      _voiceService.speak('السلة فارغة');
      return;
    }

    String content = 'السلة تحتوي على ';
    for (var item in _cartItems) {
      content += '${item['quantity']} من ${item['name_ar']}، ';
    }
    content += 'الإجمالي: $_total ريال';
    _voiceService.speak(content);
  }

  Future<void> _proceedToCheckout() async {
    if (_cartItems.isEmpty) {
      _voiceService.speak('السلة فارغة');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          userId: widget.userId,
          total: _total,
        ),
      ),
    );
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);

    try {
      final items = await DBService.getCartItems();
      double total = 0.0;
      for (var item in items) {
        total += (item['price'] as double) * (item['quantity'] as int);
      }

      if (mounted) {
        setState(() {
          _cartItems = items;
          _total = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateQuantity(
      int cartId, int productId, int newQuantity) async {
    try {
      await DBService.updateCartQuantity(cartId, newQuantity);
      _loadCart();
    } catch (e) {
      // Handle error
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
            appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text(
          'السلة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: AppTheme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'السلة فارغة',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          final itemTotal = (item['price'] as double) *
                              (item['quantity'] as int);

                          // Get image path
                          String _getImagePath() {
                            final selectedImage = item['selected_image_url'];
                            final defaultImage = item['image_url'] ?? '';
                            
                            if (selectedImage != null && selectedImage.toString().isNotEmpty) {
                              if (selectedImage.toString().startsWith('http')) {
                                return selectedImage.toString();
                              }
                              return 'assets/images/${selectedImage.toString()}';
                            }
                            
                            if (defaultImage.isNotEmpty) {
                              if (defaultImage.startsWith('http')) {
                                return defaultImage;
                              }
                              return 'assets/images/$defaultImage';
                            }
                            
                            return '';
                          }
                          
                          final imagePath = _getImagePath();

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                  color: AppTheme.divider, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.searchBarBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: imagePath.isEmpty
                                          ? Icon(
                                              Icons.shopping_bag,
                                              color: AppTheme.iconGray,
                                            )
                                          : imagePath.startsWith('http')
                                              ? CachedNetworkImage(
                                                  imageUrl: imagePath,
                                                  fit: BoxFit.cover,
                                                  width: 60,
                                                  height: 60,
                                                  placeholder: (context, url) => Container(
                                                    color: AppTheme.searchBarBackground,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Icon(
                                                    Icons.shopping_bag,
                                                    color: AppTheme.iconGray,
                                                  ),
                                                )
                                              : Image.asset(
                                                  imagePath,
                                                  fit: BoxFit.cover,
                                                  width: 60,
                                                  height: 60,
                                                  errorBuilder: (context, error, stackTrace) => Icon(
                                                    Icons.shopping_bag,
                                                    color: AppTheme.iconGray,
                                                  ),
                                                ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name_ar'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            fontFamily: 'IBMPlexSansArabic',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['price']} ريال × ${item['quantity']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                            fontFamily: 'IBMPlexSansArabic',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الإجمالي: $itemTotal ريال',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            fontFamily: 'IBMPlexSansArabic',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                        onPressed: () {
                                          _updateQuantity(
                                            item['id'],
                                            item['product_id'],
                                            (item['quantity'] as int) - 1,
                                          );
                                        },
                                        color: AppTheme.secondaryBlue,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.searchBarBackground,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${item['quantity']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            fontFamily: 'IBMPlexSansArabic',
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline),
                                        onPressed: () {
                                          _updateQuantity(
                                            item['id'],
                                            item['product_id'],
                                            (item['quantity'] as int) + 1,
                                          );
                                        },
                                        color: AppTheme.secondaryBlue,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.white,
                        border: Border(
                          top: BorderSide(color: AppTheme.divider, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'الإجمالي:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                              Text(
                                '$_total ريال',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryBlue,
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Voice Checkout Button
                          ElevatedButton.icon(
                            onPressed: _proceedToCheckout,
                            icon: const Icon(Icons.mic, color: AppTheme.white),
                            label: const Text(
                              'إتمام الشراء بالصوت',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'IBMPlexSansArabic',
                                color: AppTheme.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryBlue,
                              foregroundColor: AppTheme.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _proceedToCheckout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryBlue,
                                foregroundColor: AppTheme.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'إتمام الشراء',
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
                    ),
                  ],
                ),
            bottomNavigationBar: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // الحساب
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: widget.userId),
          ),
        );
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
        // Already on cart screen
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
      height: 70,
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // الحساب (index 0)
            _buildNavItem(Icons.person_outline, Icons.person, 'الحساب', 0),
            // الفئات (index 1)
            _buildNavItem(Icons.category_outlined, Icons.category, 'الفئات', 1),
            // مايكروفون (index 2) - أيقونة أزرق كبيرة في المنتصف
            _buildMicrophoneButton(),
            // السلة (index 3)
            _buildNavItem(
                Icons.shopping_cart_outlined, Icons.shopping_cart, 'السلة', 3),
            // الرئيسية (index 4)
            _buildNavItem(Icons.home_outlined, Icons.home, 'الرئيسية', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return GestureDetector(
      onTap: () => _onNavItemTapped(2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.secondaryBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryBlue.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          color: AppTheme.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
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
}
