import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../../services/db_service.dart';
import '../../services/api_client.dart';
import '../../services/image_caption_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/voice_mic_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final int userId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.userId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final VoiceService _voiceService = VoiceService();
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic>? _product;
  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _selectedColorImage; // الصورة المختارة للون

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _initializeVoice();
    _setupVoiceCommands();
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
    // مراقبة حالة الصوت
    _checkSpeakingStatus();
  }
  
  void _checkSpeakingStatus() {
    // التحقق من حالة الصوت بشكل دوري
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isSpeaking = _voiceService.isSpeaking;
        if (_isSpeaking != isSpeaking) {
          setState(() => _isSpeaking = isSpeaking);
        }
        if (isSpeaking) {
          _checkSpeakingStatus();
        }
      }
    });
  }

  void _setupVoiceCommands() {
    _voiceService.onSpeechResult = (text) async {
      await _handleVoiceCommand(text);
    };
  }

  Future<void> _handleVoiceCommand(String text) async {
    print('=== _handleVoiceCommand called with: $text ===');
    
    // التعامل مع timeout أو نص فارغ
    if (text.isEmpty || text == '__TIMEOUT__') {
      print('Empty text or timeout - ignoring');
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      if (_isListening) {
        await _voiceService.stopListening();
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
      return;
    }
    
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      print('Cleaned text is empty - ignoring');
      await _voiceService.speak('لم أسمع أي شيء. يرجى المحاولة مرة أخرى');
      if (_isListening) {
        await _voiceService.stopListening();
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
      return;
    }
    
    print('Processing voice command in product detail: $cleanedText');
    
    // كحل احتياطي فوري - تحقق من الكلمات المفتاحية أولاً
    final lowerText = cleanedText.toLowerCase();
    bool handledDirectly = false;
    
    // التحقق من كلمات "أضف إلى السلة" مباشرة - تحقق أكثر مرونة
    // تحقق من أي كلمة من كلمات "أضف" أو "سلة" في النص
    final addKeywords = ['أضف', 'ضيف', 'إضافة', 'أضيف', 'حط', 'ضع', 'أضف إلى', 'ضيف إلى'];
    final cartKeywords = ['سلة', 'عربة', 'السلة', 'العربة', 'للسلة', 'للعربة'];
    
    bool hasAddKeyword = addKeywords.any((keyword) => lowerText.contains(keyword));
    bool hasCartKeyword = cartKeywords.any((keyword) => lowerText.contains(keyword));
    
    // إذا كان النص يحتوي على كلمة "أضف" أو "سلة" أو كلاهما
    if (hasAddKeyword || hasCartKeyword || (hasAddKeyword && hasCartKeyword)) {
      print('Direct match for add_to_cart - executing immediately');
      print('Add keyword found: $hasAddKeyword, Cart keyword found: $hasCartKeyword');
      handledDirectly = true;
      await _addToCart();
    } else if (lowerText.contains('وصف') || lowerText.contains('اقرأ') || lowerText.contains('اقرأ الوصف')) {
      print('Direct match for read_description - executing immediately');
      handledDirectly = true;
      await _readFullDescription();
    } else if (lowerText.contains('السعر') || lowerText.contains('كم')) {
      print('Direct match for price - executing immediately');
      handledDirectly = true;
      if (_product != null) {
        final price = _product!['price'] ?? 0;
        await _voiceService.speak('السعر: $price ريال');
      }
    }
    
    // إذا تم التعامل معه مباشرة، لا حاجة لإرسال للخادم
    if (handledDirectly) {
      print('Command handled directly - stopping listening');
      if (_isListening) {
        await _voiceService.stopListening();
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
      return;
    }
    
    // إذا لم يتم التعامل معه مباشرة، أرسل للخادم NLU
    try {
      print('Sending to NLU server: $cleanedText');
      final result = await _apiClient.processNLU(cleanedText);
      final intent = result['intent'] ?? 'unknown';
      
      print('NLU Intent: $intent, Full result: $result');
      
      // معالجة الأوامر بناءً على intent من NLU
      if (intent == 'add_to_cart') {
        print('Executing add_to_cart from NLU');
        await _addToCart();
      } else if (intent == 'read_description') {
        print('Executing read_description from NLU');
        await _readFullDescription();
      } else {
        // إذا كان هناك نص رد من NLU، استخدمه
        if (result['speak_text'] != null && result['speak_text'].toString().isNotEmpty) {
          await _voiceService.speak(result['speak_text']);
        } else {
          await _voiceService.speak('لم أفهم الأمر. يمكنك قول: أضف إلى السلة، أو اقرأ الوصف');
        }
      }
    } catch (e, stackTrace) {
      print('Error processing voice command: $e');
      print('Stack trace: $stackTrace');
      // كحل احتياطي نهائي
      if (lowerText.contains('أضف') || lowerText.contains('ضيف') || lowerText.contains('سلة')) {
        print('Fallback: executing add_to_cart');
        await _addToCart();
      } else if (lowerText.contains('وصف') || lowerText.contains('اقرأ')) {
        print('Fallback: executing read_description');
        await _readFullDescription();
      } else {
        await _voiceService.speak('حدث خطأ أثناء معالجة الأمر. يرجى المحاولة مرة أخرى');
      }
    }
    
    // Stop listening after handling command
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _readFullDescription() async {
    // Toggle: إذا كان الصوت يعمل، أوقفه. وإلا ابدأه
    if (_isSpeaking || _voiceService.isSpeaking) {
      await _voiceService.stopSpeaking();
      setState(() => _isSpeaking = false);
      return;
    }
    
    if (_product != null) {
      final name = _product!['name_ar'] ?? _product!['name'] ?? '';
      final price = _product!['price'] ?? 0;
      final description =
          _product!['description_ar'] ?? _product!['description'] ?? '';
      final stock = _product!['stock'] ?? 0;

      final fullText =
          '$name. السعر: $price ريال. $description. ${stock > 0 ? "متوفر" : "غير متوفر"}';
      
      setState(() => _isSpeaking = true);
      await _voiceService.speak(fullText);
      _checkSpeakingStatus();
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      // إيقاف أي كلام جاري أولاً
      if (_voiceService.isSpeaking) {
        await _voiceService.stopSpeaking();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // بدء الاستماع مباشرة بدون كلام أولي
      final success = await _voiceService.startListening();
      if (success) {
        setState(() => _isListening = true);
        // بعد بدء الاستماع بنجاح، يمكن إخبار المستخدم
        if (_product != null) {
          final name = _product!['name_ar'] ?? _product!['name'] ?? '';
          final price = _product!['price'] ?? 0;
          // ننتظر قليلاً قبل الكلام
          Future.delayed(const Duration(milliseconds: 300), () {
            _voiceService.speak('المنتج: $name. السعر: $price ريال. يمكنك الآن التحدث');
          });
        }
      } else {
        await _voiceService.speak('فشل بدء الاستماع. يرجى المحاولة مرة أخرى');
      }
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);

    try {
      final product = await DBService.getProduct(widget.productId);

      if (mounted) {
        setState(() {
          _product = product;
          _isLoading = false;
          // Initialize selected color image with default (for iPhone)
          if (product != null) {
            final nameAr = product['name_ar'] ?? '';
            if (nameAr.contains('ايفون') || nameAr.toLowerCase().contains('iphone')) {
              _selectedColorImage = product['image_url'] ?? null;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addToCart() async {
    print('=== _addToCart called ===');
    
    if (_product == null) {
      print('Product is null - cannot add to cart');
      await _voiceService.speak('لم يتم تحديد منتج');
      return;
    }

    print('Adding product ${widget.productId} to cart');
    
    try {
      await DBService.addToCart(
        widget.productId,
        1,
        selectedImageUrl: _selectedColorImage,
      );
      print('Product added to cart successfully');
      
      if (mounted) {
        await _voiceService.speak('تمت إضافة المنتج للسلة بنجاح');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت الإضافة',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error adding to cart: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        await _voiceService.speak('فشلت إضافة المنتج. يرجى المحاولة مرة أخرى');
      }
    }
  }

  void _showFullImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imagePath.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: imagePath,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            color: Colors.black87,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            VoiceMicButton(userId: widget.userId, parentContext: context),
          ],
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        body: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                backgroundColor: AppTheme.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: AppTheme.textPrimary),
              ),
              body: const Center(
                child: Text(
                  'المنتج غير موجود',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
            ),
            VoiceMicButton(userId: widget.userId, parentContext: context),
          ],
        ),
      );
    }

    final price = _product!['price'] ?? 0.0;
    final nameAr = _product!['name_ar'] ?? '';
    final descriptionAr =
        _product!['description_ar'] ?? _product!['description'] ?? '';
    final stock = _product!['stock'] ?? 0;
    final isAvailable = stock > 0;
    final imageUrl = _product!['image_url'] ?? '';
    
    // Check if product is iPhone
    final isIPhone = nameAr.contains('ايفون') || nameAr.toLowerCase().contains('iphone');
    
    // Color options for iPhone
    final colorOptions = [
      {'name': 'أزرق', 'image': 'IPhone-16.jpg'},
      {'name': 'أخضر', 'image': 'iPhone-16-green.jpg'},
    ];
    
    String _getImagePath() {
      // Use selected color image if available, otherwise use default
      final currentImage = _selectedColorImage ?? imageUrl;
      
      if (currentImage.startsWith('assets/')) {
        return currentImage;
      }
      if (currentImage.startsWith('http')) {
        return currentImage;
      }
      if (currentImage.isNotEmpty && !currentImage.contains('/')) {
        return 'assets/images/$currentImage';
      }
      return '';
    }
    
    final imagePath = _getImagePath();

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
        title: Text(
          nameAr,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppTheme.secondaryBlue : AppTheme.iconGray,
            ),
            onPressed: _toggleMicrophone,
            tooltip: 'الميكروفون',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Hero Image - Clickable to view full size
                  GestureDetector(
                    onTap: imagePath.isNotEmpty ? () => _showFullImage(context, imagePath) : null,
                    onLongPress: imagePath.isNotEmpty ? () async {
                      final captionService = ImageCaptionService();
                      final productName = _product?['name_ar'] ?? _product?['name'] ?? '';
                      final description = await captionService.describeProductImage(imagePath, productName);
                      await _voiceService.speak(description);
                    } : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: AppTheme.searchBarBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            imagePath.isEmpty
                                ? Center(
                                    child: Icon(
                                      Icons.shopping_bag,
                                      size: 120,
                                      color: AppTheme.iconGray,
                                    ),
                                  )
                                : imagePath.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: imagePath,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 300,
                                        placeholder: (context, url) => Container(
                                          color: AppTheme.searchBarBackground,
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: AppTheme.searchBarBackground,
                                          child: Icon(
                                            Icons.error_outline,
                                            size: 120,
                                            color: AppTheme.iconGray,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        imagePath,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 300,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: AppTheme.searchBarBackground,
                                          child: Icon(
                                            Icons.error_outline,
                                            size: 120,
                                            color: AppTheme.iconGray,
                                          ),
                                        ),
                                      ),
                            if (imagePath.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Price Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$price ريال',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppTheme.success.withOpacity(0.2)
                              : AppTheme.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAvailable ? 'متوفر' : 'غير متوفر',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isAvailable ? AppTheme.success : AppTheme.error,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'الوصف',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    descriptionAr,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color Selection (iPhone only)
                  if (isIPhone) ...[
                    const Text(
                      'اختر اللون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: colorOptions.map((color) {
                        final isSelected = _selectedColorImage == color['image'] || 
                            (_selectedColorImage == null && color['image'] == imageUrl);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColorImage = color['image'];
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.secondaryBlue : AppTheme.divider,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.asset(
                                'assets/images/${color['image']}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.searchBarBackground,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: AppTheme.iconGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Voice Read Button (Toggle)
                  ElevatedButton.icon(
                    onPressed: _readFullDescription,
                    icon: Icon(
                      _isSpeaking ? Icons.stop : Icons.volume_up,
                      color: AppTheme.white,
                    ),
                    label: Text(
                      _isSpeaking ? 'إيقاف الوصف' : 'استمع للوصف الكامل',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppTheme.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpeaking ? AppTheme.error : AppTheme.secondaryBlue,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Bottom Fixed Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryBlue,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'أضف للسلة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
          ),
          VoiceMicButton(userId: widget.userId, parentContext: context),
        ],
      ),
    );
  }
}
