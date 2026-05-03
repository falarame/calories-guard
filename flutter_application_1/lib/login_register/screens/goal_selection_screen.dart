import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart';
import '../widgets/bmi_category_table.dart';
import 'target_weight_screen.dart';

class GoalSelectionScreen extends ConsumerStatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  ConsumerState<GoalSelectionScreen> createState() =>
      _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends ConsumerState<GoalSelectionScreen> {
  GoalOption? selectedGoal;
  GoalOption? recommendedGoal; // ตัวแปรเก็บว่าอันไหนคือตัวแนะนำ
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestGoalBasedOnBMI();
    });
  }

  void _suggestGoalBasedOnBMI() {
    final userData = ref.read(userDataProvider);
    double bmi = userData.bmi;
    if (bmi <= 0) return;

    // Logic แนะนำ (ปรับตามความเหมาะสม)
    if (bmi >= 23.0) {
      setState(() {
        selectedGoal = GoalOption.loseWeight;
        recommendedGoal = GoalOption.loseWeight;
      });
    } else if (bmi < 18.5) {
      setState(() {
        selectedGoal = GoalOption.buildMuscle;
        recommendedGoal = GoalOption.buildMuscle;
      });
    } else {
      setState(() {
        selectedGoal = GoalOption.maintainWeight;
        recommendedGoal = GoalOption.maintainWeight;
      });
    }
  }

  String _goalToString(GoalOption goal) {
    switch (goal) {
      case GoalOption.loseWeight:
        return 'lose_weight';
      case GoalOption.maintainWeight:
        return 'maintain_weight';
      case GoalOption.buildMuscle:
        return 'gain_muscle';
    }
  }

  void _saveAndNext() async {
    if (selectedGoal == null) return;
    setState(() => _isLoading = true);
    final userId = ref.read(userDataProvider).userId;
    bool success = await _authService.updateProfile(userId, {
      "goal_type": _goalToString(selectedGoal!),
    });
    setState(() => _isLoading = false);

    if (success) {
      ref.read(userDataProvider.notifier).setGoal(selectedGoal!);
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    TargetWeightScreen(selectedGoal: selectedGoal!)));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    }
  }

  void _showGoalInfo(BuildContext context) {
    final items = [
      {
        'title': 'ลดน้ำหนัก',
        'sub': 'แคลอรี่ต่ำกว่า TDEE • โปรตีน 30% • คาร์บ 40%',
        'icon': Icons.trending_down_rounded,
        'color': const Color(0xFFD76A3C),
        'value': GoalOption.loseWeight,
      },
      {
        'title': 'รักษาน้ำหนัก',
        'sub': 'แคลอรี่เท่ากับ TDEE • สมดุลทุกสารอาหาร',
        'icon': Icons.balance_rounded,
        'color': const Color(0xFF2D58B6),
        'value': GoalOption.maintainWeight,
      },
      {
        'title': 'เพิ่มกล้ามเนื้อ',
        'sub': 'แคลอรี่สูงกว่า TDEE • โปรตีน 30% • คาร์บ 50%',
        'icon': Icons.fitness_center_rounded,
        'color': const Color(0xFF628141),
        'value': GoalOption.buildMuscle,
      },
    ];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.flag_rounded, size: 18, color: Color(0xFF628141)),
              SizedBox(width: 8),
              Text('เป้าหมายแต่ละประเภท',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            const Text('กระทบสัดส่วนสารอาหารรายวันที่แนะนำ',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 14),
            ...items.map((it) {
              final isMe = it['value'] == selectedGoal;
              final c = it['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? c.withValues(alpha: 0.10) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: isMe ? Border.all(color: c, width: 1.5) : null,
                ),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: isMe
                            ? c.withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                        shape: BoxShape.circle),
                    child: Icon(it['icon'] as IconData,
                        size: 16, color: isMe ? c : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(it['title'] as String,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isMe ? FontWeight.bold : FontWeight.normal,
                                color: isMe ? c : Colors.black87)),
                        Text(it['sub'] as String,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ])),
                  if (isMe)
                    Icon(Icons.chevron_left_rounded, color: c, size: 18),
                ]),
              );
            }),
          ]),
        ),
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    double bmi = userData.bmi;

    String bmiStatus;
    Color bmiColor;
    if (bmi < 18.5) {
      bmiStatus = 'น้ำหนักน้อย';
      bmiColor = Colors.blue;
    } else if (bmi < 23) {
      bmiStatus = 'ปกติ';
      bmiColor = Colors.green;
    } else if (bmi < 25) {
      bmiStatus = 'ท้วม';
      bmiColor = Colors.orange;
    } else {
      bmiStatus = 'อ้วน';
      bmiColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: 0.75, // 60% - เลือกเป้าหมาย
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF628141),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.only(left: 19, top: 11),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.chevron_left,
                      size: 40, color: Color(0xFF1D1B20)),
                ),
              ),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.only(left: 33),
                child: Text(
                  'เป้าหมายของคุณคืออะไร?',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      color: Colors.black),
                ),
              ),

              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 50),
                child: Text(
                  'เลือกเป้าหมายเพื่อให้เราช่วยวางแผนที่เหมาะสม',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black),
                ),
              ),

              const SizedBox(height: 30),

              // BMI Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: _buildWhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('BMI',
                              style:
                                  TextStyle(fontSize: 12, fontFamily: 'Inter')),
                          const SizedBox(width: 20),
                          Text(bmi.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: bmiColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(bmiStatus,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: bmiColor,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showGoalInfo(context),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.info_outline_rounded,
                                  size: 15, color: Colors.grey.shade400),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double width = constraints.maxWidth;
                          double minBMI = 15;
                          double maxBMI = 35;
                          double normalizedBMI =
                              (bmi - minBMI) / (maxBMI - minBMI);
                          double position = normalizedBMI * width;
                          if (position < 0) position = 0;
                          if (position > width - 10) position = width - 10;

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
                                      border: Border.all(
                                          color: Colors.black54, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 2)
                                      ]),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text('ค่า BMI ของคุณแสดงผลตามเกณฑ์มาตรฐาน',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // --- BMI Category Table ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: BmiCategoryTable(bmi: bmi),
              ),

              const SizedBox(height: 22),

              // Goal Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  children: [
                    _buildGoalOption(
                      goal: GoalOption.loseWeight,
                      title: 'ลดน้ำหนัก',
                      subtitle: 'ควบคุมแคลอรี่',
                      iconUrl:
                          'https://api.builder.io/api/v1/image/assets/TEMP/2b36cbc83f6282347dd67152d454841cc595df15',
                      defaultGradient: const LinearGradient(
                          colors: [Colors.white, Colors.white]),
                      selectedGradient: const LinearGradient(
                          colors: [Color(0xFFDBA979), Color(0xFFD76A3C)]),
                      isRecommended: recommendedGoal ==
                          GoalOption.loseWeight, // ✅ เช็คแนะนำ
                    ),
                    const SizedBox(height: 36),
                    _buildGoalOption(
                      goal: GoalOption.maintainWeight,
                      title: 'รักษาน้ำหนัก',
                      subtitle: 'รักษาสมดุล สุขภาพดี',
                      iconUrl:
                          'https://api.builder.io/api/v1/image/assets/TEMP/caa3690bf64691cf18159ea72b5ec46944c37e66',
                      defaultGradient: const LinearGradient(
                          colors: [Colors.white, Colors.white]),
                      selectedGradient: const LinearGradient(colors: [
                        Color(0xFF10337F),
                        Color(0xFF2D58B6),
                        Color(0xFF497CEA)
                      ], stops: [
                        0.0,
                        0.36,
                        1.0
                      ]),
                      isRecommended: recommendedGoal ==
                          GoalOption.maintainWeight, // ✅ เช็คแนะนำ
                    ),
                    const SizedBox(height: 36),
                    _buildGoalOption(
                      goal: GoalOption.buildMuscle,
                      title: 'เพิ่มกล้ามเนื้อ',
                      subtitle: 'ลดไขมัน',
                      iconUrl:
                          'https://api.builder.io/api/v1/image/assets/TEMP/3ac072bc08b89b53ec34785b4a25b0021535bdd8',
                      defaultGradient: const LinearGradient(
                          colors: [Colors.white, Colors.white]),
                      selectedGradient: const LinearGradient(colors: [
                        Color(0xFFB4AC15),
                        Color(0xFFFFEA4B),
                        Color(0xFFFAFC83)
                      ], stops: [
                        0.0,
                        0.63,
                        1.0
                      ]),
                      isRecommended: recommendedGoal ==
                          GoalOption.buildMuscle, // ✅ เช็คแนะนำ
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Button
              Center(
                child: GestureDetector(
                  onTap: (selectedGoal != null && !_isLoading)
                      ? _saveAndNext
                      : null,
                  child: Container(
                    width: 259,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C6414),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ถัดไป',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ปรับ Widget นี้ให้รองรับการแสดงป้ายแนะนำที่มุม
  Widget _buildGoalOption({
    required GoalOption goal,
    required String title,
    required String subtitle,
    required String iconUrl,
    required LinearGradient defaultGradient,
    required LinearGradient selectedGradient,
    bool isRecommended = false, // ✅ รับค่าแนะนำ
  }) {
    final bool isSelected = selectedGoal == goal;
    return GestureDetector(
      onTap: () => setState(() => selectedGoal = goal),
      child: Stack(
        clipBehavior: Clip.none, // ให้ป้ายลอยออกมาได้ถ้าต้องการ
        children: [
          // กล่องหลัก
          Container(
            width: double.infinity,
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: isSelected ? selectedGradient : defaultGradient,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
              // ถ้าเป็นตัวแนะนำ ให้มีขอบสีเหลือง/ทองเด่นๆ
              border: isRecommended
                  ? Border.all(color: const Color(0xFFF3E351), width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 29,
                  top: 29,
                  child: Container(
                    width: 59,
                    height: 58,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Center(
                      child: Image.network(
                        iconUrl,
                        width: 43,
                        height: 43,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.fitness_center, size: 43),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 108,
                  top: 39,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: isSelected ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Positioned(
                      right: 19,
                      top: 41,
                      child: Icon(Icons.check_circle,
                          color: Colors.white, size: 29)),
              ],
            ),
          ),

          // ✅ ป้าย "แนะนำสำหรับคุณ" (ตามรูป CSS Frame 90)
          if (isRecommended)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E351), // สีเหลืองตามรูป
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'แนะนำสำหรับคุณ',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.error_outline,
                        size: 14, color: Colors.black), // ไอคอนตกใจ
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
