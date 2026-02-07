import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import '../../services/db_service.dart';
import '../../services/voice_navigation_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../widgets/voice_mic_button.dart';
import 'products_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final int userId;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.userId,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final VoiceService _voiceService = VoiceService();
  final VoiceNavigationService _voiceNav = VoiceNavigationService();
  final ApiClient _apiClient = ApiClient();
  String _paymentMethod = 'عند الاستلام';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _setupVoiceCommands();
    _setupVoiceNavigation();
    _announceCheckout();
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
  }

  void _setupVoiceCommands() {
    _voiceService.onSpeechResult = (text) async {
      await _handleVoiceCommand(text);
    };
  }

  Future<void> _setupVoiceNavigation() async {
    if (mounted) {
      await _voiceNav.initialize(context, widget.userId);
    }
  }

  Future<void> _announceCheckout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _voiceService.speak('صفحة إتمام الشراء. الإجمالي: ${widget.total} ريال. قل "تأكيد" لإتمام الطلب');
  }

  Future<void> _handleVoiceCommand(String text) async {
    final lowerText = text.toLowerCase();
    
    // إرسال للـ NLU أولاً
    final result = await _apiClient.processNLU(text);
    final intent = result['intent'] ?? 'unknown';
    
    if (intent == 'complete_order' || lowerText.contains('تأكيد') || lowerText.contains('أكيد') || lowerText.contains('نعم') || lowerText.contains('تمام')) {
      await _completeCheckout();
    } else if (lowerText.contains('عند الاستلام') || lowerText.contains('استلام')) {
      setState(() => _paymentMethod = 'عند الاستلام');
      _voiceService.speak('تم اختيار الدفع عند الاستلام');
    } else if (lowerText.contains('بطاقة') || lowerText.contains('كارت')) {
      setState(() => _paymentMethod = 'بطاقة');
      _voiceService.speak('تم اختيار الدفع بالبطاقة');
    } else if (lowerText.contains('عنوان') || lowerText.contains('العنوان')) {
      _voiceService.speak('قل العنوان الذي تريد التوصيل إليه');
      // Start listening for address
      await _voiceService.startListening();
    } else if (lowerText.contains('الإجمالي') || lowerText.contains('كم')) {
      _voiceService.speak('الإجمالي: ${widget.total} ريال');
    }
  }

  String _readOrderId(int orderId) {
    // تحويل رقم الطلب إلى نص عربي واضح
    final digits = orderId.toString().split('');
    final arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    
    // قراءة كل رقم بشكل منفصل
    String result = '';
    for (int i = 0; i < digits.length; i++) {
      final digit = int.tryParse(digits[i]) ?? 0;
      if (i > 0) {
        result += ' ';
      }
      result += arabicDigits[digit];
    }
    
    // إرجاع الرقم بالعربية
    return result;
  }

  Future<void> _completeCheckout() async {
    if (_addressController.text.isEmpty) {
      _voiceService.speak('يرجى إدخال عنوان التوصيل');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _voiceService.speak('يرجى التحقق من البيانات');
      return;
    }

    setState(() => _isLoading = true);
    _voiceService.speak('جاري إتمام الطلب...');

    try {
      final cartItems = await DBService.getCartItems();
      if (cartItems.isEmpty) {
        _voiceService.speak('السلة فارغة');
        setState(() => _isLoading = false);
        return;
      }

      final orderId = await DBService.createOrder(cartItems);
      await DBService.clearCart();

      if (mounted) {
        // قراءة رقم الطلب بشكل صحيح
        final orderIdText = _readOrderId(orderId);
        _voiceService.speak('تم إتمام الطلب بنجاح. رقم الطلب: $orderIdText. سيتم التوصيل إلى ${_addressController.text}');
        await Future.delayed(const Duration(seconds: 3));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ProductsScreen(userId: widget.userId),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _voiceService.speak('فشل إتمام الطلب. يرجى المحاولة مرة أخرى');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خطأ في إتمام الطلب',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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
                'إتمام الشراء',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
            body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
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
                        '${widget.total} ريال',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'طريقة الدفع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.divider, width: 1),
                  ),
                  child: RadioListTile<String>(
                    title: const Text(
                      'عند الاستلام',
                      style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                    ),
                    subtitle: const Text(
                      'ادفع عند استلام الطلب',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    value: 'عند الاستلام',
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      setState(() => _paymentMethod = value!);
                    },
                    activeColor: AppTheme.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.divider, width: 1),
                  ),
                  child: RadioListTile<String>(
                    title: const Text(
                      'بطاقة',
                      style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                    ),
                    subtitle: const Text(
                      'الدفع بالبطاقة الائتمانية',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    value: 'بطاقة',
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      setState(() => _paymentMethod = value!);
                    },
                    activeColor: AppTheme.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'عنوان التوصيل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'العنوان',
                    hintText: 'أدخل عنوان التوصيل الكامل',
                    prefixIcon: const Icon(Icons.location_on, color: AppTheme.iconGray),
                    filled: true,
                    fillColor: AppTheme.inputBackground,
                  ),
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'العنوان مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryBlue,
                      foregroundColor: AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                            ),
                          )
                        : const Text(
                            'تأكيد وإتمام الطلب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
