import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/image_caption_service.dart';
import '../../services/voice_service.dart';

/// بطاقة منتج للصفحة الرئيسية - فقط صورة بدون سعر
class ProductImageCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductImageCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  String _getImagePath() {
    final imageUrl = product['image_url'] ?? '';
    print('ProductImageCard - image_url from DB: $imageUrl');
    
    // إذا كانت الصورة من assets
    if (imageUrl.startsWith('assets/')) {
      print('ProductImageCard - Using asset path: $imageUrl');
      return imageUrl;
    }
    // إذا كانت URL من الإنترنت
    if (imageUrl.startsWith('http')) {
      print('ProductImageCard - Using network URL: $imageUrl');
      return imageUrl;
    }
    // إذا كانت اسم ملف فقط
    if (imageUrl.isNotEmpty && !imageUrl.contains('/')) {
      final path = 'assets/images/$imageUrl';
      print('ProductImageCard - Constructed asset path: $path');
      return path;
    }
    print('ProductImageCard - No image path found, image_url was: "$imageUrl"');
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _getImagePath();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.divider, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: () async {
          final captionService = ImageCaptionService();
          final productName = product['name_ar'] ?? product['name'] ?? '';
          final description = await captionService.describeProductImage('', productName);
          final voiceService = VoiceService();
          await voiceService.initialize();
          await voiceService.speak(description);
        },
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight > 0 ? constraints.maxHeight : 250.0;
              final width = constraints.maxWidth > 0 ? constraints.maxWidth : double.infinity;
              
              return SizedBox(
                width: width,
                height: height,
                child: imagePath.isEmpty
                    ? Container(
                        width: width,
                        height: height,
                        color: AppTheme.searchBarBackground,
                        child: Icon(
                          Icons.shopping_bag,
                          size: 60,
                          color: AppTheme.iconGray,
                        ),
                      )
                    : imagePath.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: imagePath,
                            fit: BoxFit.cover,
                            width: width,
                            height: height,
                            placeholder: (context, url) => Container(
                              width: width,
                              height: height,
                              color: AppTheme.searchBarBackground,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              print('Error loading image: $url, Error: $error');
                              return Container(
                                width: width,
                                height: height,
                                color: AppTheme.searchBarBackground,
                                child: Icon(
                                  Icons.error_outline,
                                  color: AppTheme.iconGray,
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            width: width,
                            height: height,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading asset: $imagePath, Error: $error');
                              return Container(
                                width: width,
                                height: height,
                                color: AppTheme.searchBarBackground,
                                child: Icon(
                                  Icons.error_outline,
                                  color: AppTheme.iconGray,
                                ),
                              );
                            },
                          ),
              );
            },
          ),
        ),
      ),
    );
  }
}
