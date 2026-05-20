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

  String? _heightError;
  String? _weightError;
  String? _dateError;

  static const double _minHeightCm = 145;
  static const double _maxHeightCm = 210;
  static const double _minWeightKg = 30;
  static const double _maxWeightKg = 200;

  bool _isAtLeast18(DateTime birth) {
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years >= 18;
  }

  String? _validateHeight(String s) {
    final v = double.tryParse(s.trim());
    if (v == null) return 'กรุณากรอกตัวเลข';
    if (v < _minHeightCm || v > _maxHeightCm) {
      return 'ส่วนสูงต้องอยู่ระหว่าง ${_minHeightCm.toInt()}-${_maxHeightCm.toInt()} ซม.';
    }
    return null;
  }

  String? _validateWeight(String s) {
    final v = double.tryParse(s.trim());
    if (v == null) return 'กรุณากรอกตัวเลข';
    if (v < _minWeightKg || v > _maxWeightKg) {
      return 'น้ำหนักต้องอยู่ระหว่าง ${_minWeightKg.toInt()}-${_maxWeightKg.toInt()} กก.';
    }
    return null;
  }

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
      setState(() {
        _selectedDate = picked;
        _dateError = null;
      });
    }
  }

  // ✅ ฟังก์ชันบันทึกข้อมูลลง Database
  void _saveAndNext() async {
    // 1. ตรวจสอบข้อมูล (inline validation)
    final heightErr = _heightController.text.trim().isEmpty
        ? 'กรุณากรอกส่วนสูง'
        : _validateHeight(_heightController.text);
    final weightErr = _weightController.text.trim().isEmpty
        ? 'กรุณากรอกน้ำหนัก'
        : _validateWeight(_weightController.text);
    final dateErr = _selectedDate == null
        ? 'กรุณาเลือกวันเกิด'
        : (!_isAtLeast18(_selectedDate!) ? 'อายุต้องไม่น้อยกว่า 18 ปี' : null);

    setState(() {
      _heightError = heightErr;
      _weightError = weightErr;
      _dateError = dateErr;
    });
    if (heightErr != null || weightErr != null || dateErr != null) {
      return;
    }

    setState(() => _isLoading = true);

    // 2. แปลงค่า
    double heightVal = double.tryParse(_heightController.text) ?? 0.0;
    double weightVal = double.tryParse(_weightController.text) ?? 0.0;
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
                        errorText: _heightError,
                        onChanged: () {
                          if (_heightError != null) {
                            setState(() => _heightError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      _buildFormField(
                        label: 'นํ้าหนัก*',
                        controller: _weightController,
                        hintText: '0.00 kg.', // เปลี่ยน hint ให้สื่อความหมาย
                        isNumber: true,
                        errorText: _weightError,
                        onChanged: () {
                          if (_weightError != null) {
                            setState(() => _weightError = null);
                          }
                        },
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
                          color: Colors.black.withOpacity( 0.25),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 100,
          child: Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
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
              if (_dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    _dateError!,
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 12, color: Colors.red),
                  ),
                ),
            ],
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
    String? errorText,
    VoidCallback? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
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
                  onChanged: onChanged == null ? null : (_) => onChanged(),
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
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 12, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
