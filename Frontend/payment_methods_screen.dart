import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/db_service.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../widgets/voice_mic_button.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final int userId;

  const PaymentMethodsScreen({super.key, required this.userId});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final VoiceService _voiceService = VoiceService();
  final VoiceNavigationService _voiceNav = VoiceNavigationService();
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  bool _isVoiceMode = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _setupVoice();
  }

  Future<void> _setupVoice() async {
    await _voiceService.initialize();
    _voiceNav.onPaymentMethodAdded = () {
      _loadPaymentMethods();
    };
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    final methods = await DBService.getPaymentMethods(widget.userId);
    setState(() {
      _paymentMethods = methods;
      _isLoading = false;
    });
  }

  Future<void> _startVoiceMode() async {
    setState(() => _isVoiceMode = true);
    await _voiceService.speak('تم تفعيل وضع الصوت. قل "أضف طريقة دفع جديدة" لإضافة طريقة دفع');
    _voiceNav.enableVoiceMode();
    _voiceNav.initialize(context, widget.userId);
  }

  Future<void> _stopVoiceMode() async {
    setState(() => _isVoiceMode = false);
    await _voiceNav.disableVoiceMode();
  }

  Future<void> _addPaymentMethodManually() async {
    final type = await _showTypeDialog();
    if (type == null) return;

    if (type == 'بطاقة ائتمان') {
      final cardNumber = await _showInputDialog('رقم البطاقة');
      if (cardNumber == null) return;
      final cardHolder = await _showInputDialog('اسم حامل البطاقة');
      if (cardHolder == null) return;
      final expiryMonth = await _showInputDialog('شهر الانتهاء (1-12)');
      if (expiryMonth == null) return;
      final expiryYear = await _showInputDialog('سنة الانتهاء');
      if (expiryYear == null) return;
      final cvv = await _showInputDialog('CVV');
      if (cvv == null) return;

      try {
        await DBService.addPaymentMethod(
          userId: widget.userId,
          paymentType: type,
          cardNumber: cardNumber.replaceAll(RegExp(r'[^\d]'), ''),
          cardHolder: cardHolder,
          expiryMonth: int.tryParse(expiryMonth),
          expiryYear: int.tryParse(expiryYear),
          cvv: cvv.replaceAll(RegExp(r'[^\d]'), ''),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة طريقة الدفع بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
        _loadPaymentMethods();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إضافة طريقة الدفع: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
      }
    } else if (type == 'محفظة رقمية') {
      final provider = await _showInputDialog('اسم المحفظة', 'مثلاً: Samsung Pay, Google Pay');
      if (provider == null) return;

      try {
        await DBService.addPaymentMethod(
          userId: widget.userId,
          paymentType: type,
          walletProvider: provider,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة طريقة الدفع بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
        _loadPaymentMethods();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إضافة طريقة الدفع: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
      }
    } else if (type == 'تحويل بنكي') {
      final bankName = await _showInputDialog('اسم البنك');
      if (bankName == null) return;

      try {
        await DBService.addPaymentMethod(
          userId: widget.userId,
          paymentType: type,
          bankName: bankName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة طريقة الدفع بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
        _loadPaymentMethods();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إضافة طريقة الدفع: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
          );
        }
      }
    }
  }

  Future<String?> _showTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر نوع طريقة الدفع', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('بطاقة ائتمان', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              onTap: () => Navigator.pop(context, 'بطاقة ائتمان'),
            ),
            ListTile(
              title: const Text('محفظة رقمية', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              onTap: () => Navigator.pop(context, 'محفظة رقمية'),
            ),
            ListTile(
              title: const Text('تحويل بنكي', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              onTap: () => Navigator.pop(context, 'تحويل بنكي'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(String label, [String? hint]) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label, style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('موافق', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePaymentMethod(int methodId) async {
    try {
      await DBService.deletePaymentMethod(methodId);
      _loadPaymentMethods();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف طريقة الدفع', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف طريقة الدفع: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
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
          'طرق الدفع',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'IBMPlexSansArabic'),
        ),
        actions: [
          IconButton(
            icon: Icon(_isVoiceMode ? Icons.mic : Icons.mic_none, color: _isVoiceMode ? AppTheme.secondaryBlue : AppTheme.iconGray),
            onPressed: _isVoiceMode ? _stopVoiceMode : _startVoiceMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment_outlined, size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('لا توجد طرق دفع محفوظة', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, fontFamily: 'IBMPlexSansArabic')),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addPaymentMethodManually,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة طريقة دفع', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryBlue,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _paymentMethods.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _paymentMethods.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: _addPaymentMethodManually,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة طريقة دفع', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryBlue,
                            foregroundColor: AppTheme.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      );
                    }
                    final method = _paymentMethods[index];
                    String displayText = '';
                    if (method['payment_type'] == 'بطاقة ائتمان') {
                      final cardNumber = method['card_number'] ?? '';
                      displayText = '****${cardNumber.length > 4 ? cardNumber.substring(cardNumber.length - 4) : cardNumber}';
                    } else if (method['payment_type'] == 'محفظة رقمية') {
                      displayText = method['wallet_provider'] ?? 'محفظة رقمية';
                    } else {
                      displayText = method['bank_name'] ?? 'تحويل بنكي';
                    }
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
                          method['payment_type'] ?? 'طريقة دفع',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'IBMPlexSansArabic'),
                        ),
                        subtitle: Text(displayText, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontFamily: 'IBMPlexSansArabic')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                          onPressed: () => _deletePaymentMethod(method['id']),
                        ),
                      ),
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
