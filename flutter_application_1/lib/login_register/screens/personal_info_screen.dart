import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart'; // ✅ Import Service
import 'birth_date_picker_screen.dart';
import 'food_allergy_screen.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  final AuthService _authService = AuthService(); // ✅ สร้างตัวยิง API
  bool _isLoading = false; // สถานะโหลด

  DateTime? _selectedDate;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _openBirthDatePicker(BuildContext context) async {
    final DateTime? picked = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (context) => BirthDatePickerScreen(
            initialDate: _selectedDate ?? DateTime(2000, 1, 1)),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  // ✅ ฟังก์ชันบันทึกข้อมูลลง Database
  void _saveAndNext() async {
    // 1. ตรวจสอบข้อมูล
    if (_selectedDate == null ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. แปลงค่า
    double heightVal = double.tryParse(_heightController.text) ?? 0.0;
    double weightVal = double.tryParse(_weightController.text) ?? 0.0;

    // Validate height: 100–250 cm (WHO/CDC growth standards)
    if (heightVal < 100 || heightVal > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่วนสูงต้องอยู่ระหว่าง 100–250 ซม.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Validate weight: 20–300 kg (CDC growth chart lower / practical upper)
    if (weightVal < 20 || weightVal > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('น้ำหนักต้องอยู่ระหว่าง 20–300 กก.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Validate age: 13–100 ปี (AAP / COPPA 2016 — ป้องกัน disordered eating)
    final now = DateTime.now();
    int computedAge = now.year - _selectedDate!.year;
    if (now.month < _selectedDate!.month ||
        (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
      computedAge--;
    }
    if (computedAge < 13 || computedAge > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อายุต้องอยู่ระหว่าง 13–100 ปี'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }
    // แปลงวันที่เป็น String format YYYY-MM-DD เพื่อส่งให้ Python
    String birthDateStr =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    // 3. ดึง ID จาก Provider
    final userId = ref.read(userDataProvider).userId;

    // 4. ยิง API Update
    bool success = await _authService.updateProfile(userId, {
      "birth_date": birthDateStr,
      "height_cm": heightVal,
      "current_weight_kg": weightVal,
    });

    setState(() => _isLoading = false);

    if (success) {
      // ✅ สำเร็จ: อัปเดต Provider แล้วไปหน้าถัดไป

      // หมายเหตุ: เราไม่ต้องส่ง name ไปอัปเดต เพราะ name ถูกเก็บตอน Register แล้ว
      // แต่เราดึง name เก่าจาก Provider มาใส่กลับเข้าไปได้เพื่อให้ข้อมูลครบถ้วน
      final currentName = ref.read(userDataProvider).name;

      ref.read(userDataProvider.notifier).setPersonalInfo(
            name: currentName,
            birthDate: _selectedDate!,
            height: heightVal,
            weight: weightVal,
          );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FoodAllergyScreen(),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่')),
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
              value: 0.375, // 30% - ข้อมูลส่วนตัว
              backgroundColor: Colors.grey.shade200,
              color: primaryGreen,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFE8EFCF),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 14),
                const Text(
                  'กรอกข้อมูลส่วนตัว',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      color: Colors.black),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    'เพื่อนำไปคำนวณแคลอรี่ที่เหมาะสมกับตัวบุคคล',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 44),
                Center(
                  child: Image.network(
                    'https://api.builder.io/api/v1/image/assets/TEMP/1954e238a987282746e33d33deb711b2c911f3d3?width=554',
                    width: 277,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 150),
                  ),
                ),

                const SizedBox(height: 47),

                // Form Fields (เอาช่องชื่อออกแล้ว)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    children: [
                      _buildBirthDateRow(),
                      const SizedBox(height: 28),
                      _buildFormField(
                        label: 'ส่วนสูง*',
                        controller: _heightController,
                        hintText: '0.00 cm.', // เปลี่ยน hint ให้สื่อความหมาย
                        isNumber: true,
                      ),
                      const SizedBox(height: 28),
                      _buildFormField(
                        label: 'นํ้าหนัก*',
                        controller: _weightController,
                        hintText: '0.00 kg.', // เปลี่ยน hint ให้สื่อความหมาย
                        isNumber: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // ปุ่มถัดไป
                GestureDetector(
                  onTap: _isLoading ? null : _saveAndNext,
                  child: Container(
                    width: 259,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF628141),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'ถัดไป',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDateRow() {
    const label = 'วันเกิด*';
    final displayText = _selectedDate == null
        ? 'วว/ดด/ปปปป'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final isPlaceholder = _selectedDate == null;
    return Row(
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.black),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _openBirthDatePicker(context),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEDED),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isPlaceholder
                            ? const Color(0xB3000000)
                            : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today,
                      size: 18, color: Color(0xFF4C6414)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isNumber = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.black),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDED),
              borderRadius: BorderRadius.circular(100),
            ),
            child: TextField(
              controller: controller,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: const InputDecoration(
                hintText: '',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ).copyWith(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xB3000000),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
