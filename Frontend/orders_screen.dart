import 'package:flutter/material.dart';
import '../../services/db_service.dart';
import '../../theme/app_theme.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../widgets/voice_mic_button.dart';
import 'profile_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int userId;

  const OrdersScreen({super.key, required this.userId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final VoiceService _voiceService = VoiceService();
  final VoiceNavigationService _voiceNav = VoiceNavigationService();
  bool _isVoiceMode = false;

  @override
  void initState() {
    super.initState();
    _setupVoice();
  }

  Future<void> _setupVoice() async {
    await _voiceService.initialize();
    _voiceNav.initialize(context, widget.userId);
  }

  Future<void> _startVoiceMode() async {
    setState(() => _isVoiceMode = true);
    await _voiceService.speak('تم تفعيل وضع الصوت. قل "احذف الطلب رقم" متبوعاً برقم الطلب لحذفه');
    _voiceNav.enableVoiceMode();
  }

  Future<void> _stopVoiceMode() async {
    setState(() => _isVoiceMode = false);
    await _voiceNav.disableVoiceMode();
  }

  Future<void> _deleteOrder(int orderId) async {
    try {
      await DBService.deleteOrder(orderId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطلب بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
      await _voiceService.speak('تم حذف الطلب بنجاح');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف الطلب: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text(
          'الطلبات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isVoiceMode ? Icons.mic : Icons.mic_none, color: _isVoiceMode ? AppTheme.secondaryBlue : AppTheme.iconGray),
            onPressed: _isVoiceMode ? _stopVoiceMode : _startVoiceMode,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBService.getAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 80,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد طلبات',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.divider, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    'طلب #${order['id']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        order['product_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الإجمالي: ${order['total']} ريال',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryBlue,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الكمية: ${order['quantity']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الحالة: ${order['status'] ?? 'قيد الانتظار'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: () => _deleteOrder(order['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
          ),
          VoiceMicButton(userId: widget.userId, parentContext: context),
        ],
      ),
    );
  }
}
