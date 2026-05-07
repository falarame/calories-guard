import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart';
import 'personal_info_screen.dart';

class GenderSelectionScreen extends ConsumerStatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  ConsumerState<GenderSelectionScreen> createState() =>
      _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends ConsumerState<GenderSelectionScreen> {
  String? selectedGender;
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _saveGenderToDb() async {
    if (selectedGender == null) return;

    // 1. ดึง user_id
    final userId = ref.read(userDataProvider).userId;

    // ⚠️ เช็คความปลอดภัย: ถ้า userId เป็น 0 แสดงว่าการสมัคร/ล็อกอินมีปัญหา
    if (userId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'เกิดข้อผิดพลาด: ไม่พบข้อมูลผู้ใช้ (กรุณาเข้าสู่ระบบใหม่)'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // 2. ยิง API อัปเดตเพศ
    bool isSuccess = await _authService.updateProfile(userId, {
      "gender": selectedGender,
    });

    setState(() => _isLoading = false);

    if (isSuccess) {
      // ✅ 3. อัปเดตข้อมูลในแอป แล้วไปหน้าถัดไป
      ref.read(userDataProvider.notifier).setGender(selectedGender!);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ไม่สามารถบันทึกเพศได้ กรุณาลองใหม่อีกครั้ง'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF628141);
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 200,
            height: 8,
            child: LinearProgressIndicator(
              value: 0.25, // 20% - เลือกเพศ
              backgroundColor: Colors.grey.shade200,
              color: primaryGreen,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('เลือกเพศของคุณ',
                style: TextStyle(
                    fontSize: 32,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                'เพื่อนำไปคำนวณค่า BMR ซึ่งเพศส่งผลต่อระบบเผาผลาญ',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGenderCard(
                    'female', 'หญิง', 'assets/images/picture/girl.png'),
                const SizedBox(width: 20),
                _buildGenderCard(
                    'male', 'ชาย', 'assets/images/picture/boy.png'),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onTap: (selectedGender != null && !_isLoading)
                    ? _saveGenderToDb
                    : null,
                child: Container(
                  width: 259,
                  height: 54,
                  decoration: BoxDecoration(
                    color: selectedGender != null
                        ? const Color(0xFF4C6414)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ถัดไป',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(String gender, String label, String imgPath) {
    bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF4C6414), width: 3)
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10)
                ]
              : [],
        ),
        child: Column(
          children: [
            Image.asset(imgPath, width: 100, height: 100),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
