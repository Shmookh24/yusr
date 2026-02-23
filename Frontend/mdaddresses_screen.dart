import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/db_service.dart';
import '../../services/voice_service.dart';
import '../../services/voice_navigation_service.dart';
import '../widgets/voice_mic_button.dart';

class AddressesScreen extends StatefulWidget {
  final int userId;

  const AddressesScreen({super.key, required this.userId});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final VoiceService _voiceService = VoiceService();
  final VoiceNavigationService _voiceNav = VoiceNavigationService();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  bool _isVoiceMode = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _setupVoice();
  }

  Future<void> _setupVoice() async {
    await _voiceService.initialize();
    _voiceNav.onAddressAdded = () {
      _loadAddresses();
    };
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await DBService.getAddresses(widget.userId);
    setState(() {
      _addresses = addresses;
      _isLoading = false;
    });
  }

  Future<void> _startVoiceMode() async {
    setState(() => _isVoiceMode = true);
    await _voiceService.speak('تم تفعيل وضع الصوت. قل "أضف عنوان جديد" لإضافة عنوان');
    _voiceNav.enableVoiceMode();
    _voiceNav.initialize(context, widget.userId);
  }

  Future<void> _stopVoiceMode() async {
    setState(() => _isVoiceMode = false);
    await _voiceNav.disableVoiceMode();
  }

  Future<void> _addAddressManually() async {
    String? title, street, city, district, building, apartment, postal;
    
    title = await _showInputDialog('اسم العنوان', 'مثلاً: المنزل أو العمل');
    if (title == null) return;
    
    street = await _showInputDialog('اسم الشارع');
    if (street == null) return;
    
    city = await _showInputDialog('المدينة');
    if (city == null) return;
    
    district = await _showInputDialog('الحي أو المنطقة');
    building = await _showInputDialog('رقم المبنى');
    apartment = await _showInputDialog('رقم الشقة');
    postal = await _showInputDialog('الرمز البريدي (اختياري)');
    
    try {
      await DBService.addAddress(
        userId: widget.userId,
        title: title,
        street: street,
        city: city,
        district: district,
        buildingNumber: building,
        apartmentNumber: apartment,
        postalCode: postal,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة العنوان بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
      _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إضافة العنوان: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    }
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

  Future<void> _deleteAddress(int addressId) async {
    try {
      await DBService.deleteAddress(addressId);
      _loadAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العنوان', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف العنوان: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
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
          'العناوين',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد عناوين محفوظة',
                        style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, fontFamily: 'IBMPlexSansArabic'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addAddressManually,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة عنوان جديد', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
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
                  itemCount: _addresses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _addresses.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: _addAddressManually,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة عنوان جديد', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryBlue,
                            foregroundColor: AppTheme.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      );
                    }
                    final address = _addresses[index];
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
                          address['title'] ?? 'عنوان',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'IBMPlexSansArabic'),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('${address['street'] ?? ''}, ${address['city'] ?? ''}', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontFamily: 'IBMPlexSansArabic')),
                            if (address['district'] != null) Text('الحي: ${address['district']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'IBMPlexSansArabic')),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                          onPressed: () => _deleteAddress(address['id']),
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
