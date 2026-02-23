import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/image_caption_service.dart';
import '../../services/voice_service.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  String _getImagePath() {
    final imageUrl = product['image_url'] ?? '';
    // إذا كانت الصورة من assets
    if (imageUrl.startsWith('assets/')) {
      return imageUrl;
    }
    // إذا كانت URL من الإنترنت
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // إذا كانت اسم ملف فقط
    if (imageUrl.isNotEmpty && !imageUrl.contains('/')) {
      return 'assets/images/$imageUrl';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final price = product['price'] ?? 0.0;
    final nameAr = product['name_ar'] ?? product['name'] ?? 'منتج';
    final stock = product['stock'] ?? 0;
    final isAvailable = stock > 0;
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
          final productName = nameAr;
          final description = await captionService.describeProductImage('', productName);
          final voiceService = VoiceService();
          await voiceService.initialize();
          await voiceService.speak(description);
        },
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight > 0 
                ? constraints.maxHeight 
                : 200.0; // Default height if unbounded
            final imageHeight = cardHeight * 0.6;
            final contentHeight = cardHeight * 0.4;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Section
                SizedBox(
                  height: imageHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: imagePath.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: AppTheme.searchBarBackground,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.shopping_bag,
                                size: 60,
                                color: AppTheme.iconGray,
                              ),
                            ),
                          )
                        : imagePath.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: imagePath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: imageHeight,
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
                                    color: AppTheme.iconGray,
                                  ),
                                ),
                              )
                            : Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: imageHeight,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.searchBarBackground,
                                  child: Icon(
                                    Icons.error_outline,
                                    color: AppTheme.iconGray,
                                  ),
                                ),
                              ),
                  ),
                ),
                // Content Section
                SizedBox(
                  height: contentHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            nameAr,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$price ريال',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? AppTheme.success.withOpacity(0.2)
                                    : AppTheme.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAvailable ? 'متوفر' : 'غير متوفر',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAvailable ? AppTheme.success : AppTheme.error,
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
