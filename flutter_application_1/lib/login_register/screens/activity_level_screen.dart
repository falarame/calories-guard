import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart'; // ✅ 1. Import AuthService
import '../../utils/bmi_utils.dart';
import '../widgets/bmi_category_table.dart';
import 'goal_selection_screen.dart';

class ActivityLevelScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const ActivityLevelScreen({
    super.key,
    this.isEditing = false, // ถ้าไม่ส่งมา จะถือว่าเป็น false (โหมดสมัคร)
  });

  @override
  ConsumerState<ActivityLevelScreen> createState() =>
      _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends ConsumerState<ActivityLevelScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService(); // ✅ 2. สร้าง instance
  bool _isLoading = false; // สถานะโหลด

  final List<Map<String, dynamic>> _activities = [
    {
      "title": "ไม่ออกกำลังกายเลย",
      "subtitle": "นั่งทำงานตลอดวัน ไม่ค่อยขยับตัว",
      "value": "sedentary", // BMR x 1.2
      "icon": Icons.weekend_outlined,
    },
    {
      "title": "ออกกำลังกายเบาๆ",
      "subtitle": "1-3 วันต่อสัปดาห์ หรือเดินบ่อย",
      "value": "lightly_active", // BMR x 1.375 (แก้ตรงนี้)
      "icon": Icons.directions_walk,
    },
    {
      "title": "ออกกำลังกายปานกลาง",
      "subtitle": "3-5 วันต่อสัปดาห์ (แอโรบิค, วิ่ง)",
      "value": "moderately_active", // BMR x 1.55 (แก้ตรงนี้)
      "icon": Icons.run_circle_outlined,
    },
    {
      "title": "ออกกำลังกายหนัก",
      "subtitle": "6-7 วันต่อสัปดาห์",
      "value": "very_active", // BMR x 1.725 (แก้ตรงนี้)
      "icon": Icons.fitness_center,
    },
  ];

  void _showActivityInfo(BuildContext context) {
    final items = [
      {
        'title': 'ไม่ออกกำลังกายเลย',
        'sub': 'นั่งทำงาน ไม่ขยับตัว',
        'factor': '×1.2',
        'value': 'sedentary'
      },
      {
        'title': 'ออกกำลังกายเบาๆ',
        'sub': '1-3 วัน/สัปดาห์',
        'factor': '×1.375',
        'value': 'lightly_active'
      },
      {
        'title': 'ออกกำลังกายปานกลาง',
        'sub': '3-5 วัน/สัปดาห์',
        'factor': '×1.55',
        'value': 'moderately_active'
      },
      {
        'title': 'ออกกำลังกายหนัก',
        'sub': '6-7 วัน/สัปดาห์',
        'factor': '×1.725',
        'value': 'very_active'
      },
    ];
    final current = _activities[_selectedIndex]['value'] as String;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.directions_run_rounded,
                  size: 18, color: Color(0xFF628141)),
              SizedBox(width: 8),
              Text('ระดับกิจกรรมกายภาพ (PAL)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            const Text('ใช้คำนวณ TDEE = BMR × ตัวคูณ',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 14),
            ...items.map((it) {
              final isMe = it['value'] == current;
              const c = Color(0xFF628141);
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isMe ? c.withOpacity(0.10) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: isMe ? Border.all(color: c, width: 1.5) : null,
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it['title']!,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isMe ? c : Colors.black87)),
                          Text(it['sub']!,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                        ]),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? c : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(it['factor']!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : Colors.black54)),
                  ),
                ]),
              );
            }),
          ]),
        ),
      ),
    );
  }

  Widget _buildBMICard() {
    final userData = ref.watch(userDataProvider);
    final bmi = userData.bmi;
    final bmiStatus = bmiStatusLabel(bmi);
    final bmiColor = bmiRiskColor(bmi);
    final riskData = bmiBandData(bmi);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('BMI',
                  style: TextStyle(fontSize: 12, fontFamily: 'Inter')),
              const SizedBox(width: 20),
              Text(bmi.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: bmiColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(bmiStatus,
                    style: TextStyle(
                        fontSize: 10,
                        color: bmiColor,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showActivityInfo(context),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const minBMI = 15.0;
              const maxBMI = 35.0;
              double normalizedBMI = (bmi - minBMI) / (maxBMI - minBMI);
              if (normalizedBMI < 0) normalizedBMI = 0;
              if (normalizedBMI > 1) normalizedBMI = 1;
              final position = normalizedBMI * (width - 14);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1710ED),
                          Color(0xFF69AE6D),
                          Color(0xFFD3D347),
                          Color(0xFFCAAC58),
                          Color(0xFFFF0000)
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: position,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black54, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2)
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(riskData.riskText,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  // ✅ 3. ปรับปรุงฟังก์ชัน Submit ให้ยิง API
  void _submit() async {
    setState(() => _isLoading = true); // เริ่มโหลด

    // ดึงค่าภาษาอังกฤษ เช่น 'sedentary', 'light'
    final selectedValue = _activities[_selectedIndex]['value'];

    // ดึง userId ปัจจุบัน
    final userId = ref.read(userDataProvider).userId;

    // --- ยิง API บันทึกลง Database ---
    bool success = await _authService.updateProfile(userId, {
      "activity_level": selectedValue,
    });

    setState(() => _isLoading = false); // หยุดโหลด

    if (success) {
      // บันทึกลง Provider เพื่อใช้ในแอป
      ref.read(userDataProvider.notifier).setActivityLevel(selectedValue);

      // ไปหน้าถัดไป
      if (mounted) {
        // ✅ 2. เช็ค Logic การไปต่อ
        if (widget.isEditing) {
          // ถ้ามาจากการแก้ไข -> ให้ย้อนกลับไปหน้า Profile
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('อัปเดตระดับกิจกรรมเรียบร้อย'),
                backgroundColor: Colors.green),
          );
        } else {
          // ถ้ามาจากการสมัคร -> ไปหน้าเลือกเป้าหมายต่อ (Flow เดิม)
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const GoalSelectionScreen()),
          );
        }
      }
    } else {
      // แจ้งเตือนถ้าบันทึกไม่ผ่าน
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Progress Bar ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: 0.625, // 50% - ระดับกิจกรรม
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF628141),
                  ),
                ),
              ),
            ),

            // --- Header ---
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 10, right: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Color(0xFF1D1B20)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ระดับกิจกรรม',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'ข้อมูลนี้ช่วยให้เราคำนวณการเผาผลาญพลังงาน (TDEE) ได้แม่นยำขึ้น',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 14, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 20),

            // --- BMI Card ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildBMICard(),
            ),
            const SizedBox(height: 12),
            // --- BMI Category Table ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BmiCategoryTable(bmi: ref.watch(userDataProvider).bmi),
            ),
            const SizedBox(height: 18),

            // --- List of Cards ---
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: _activities.length,
                separatorBuilder: (c, i) => const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  final item = _activities[index];
                  final isSelected = _selectedIndex == index;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4C6414)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE8EFCF)
                                  : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item['icon'],
                                color: isSelected
                                    ? const Color(0xFF4C6414)
                                    : Colors.grey,
                                size: 28),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'],
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF4C6414)
                                            : Colors.black)),
                                const SizedBox(height: 4),
                                Text(item['subtitle'],
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.black
                                            .withOpacity(0.6))),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Color(0xFF4C6414)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- Button ---
            Container(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit, // ถ้าโหลดอยู่กดไม่ได้
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF628141),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ถัดไป',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
