import 'package:flutter/material.dart';
import '../../widget/ruler_slider.dart';
import '../../providers/user_data_provider.dart';

class DurationSliderScreen extends StatefulWidget {
  final GoalOption selectedGoal;
  final DateTime currentDate;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final ValueChanged<int> onDurationSelected;
  final int recommendedDurationDays;
  final int minDurationDays;

  const DurationSliderScreen({
    super.key,
    required this.selectedGoal,
    required this.currentDate,
    required this.onBack,
    required this.onSubmit,
    required this.onDurationSelected,
    this.recommendedDurationDays = 90,
    this.minDurationDays = 28,
  });

  @override
  State<DurationSliderScreen> createState() => _DurationSliderScreenState();
}

class _DurationSliderScreenState extends State<DurationSliderScreen> {
  late int _selectedDurationDays;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDurationDays =
        widget.recommendedDurationDays < widget.minDurationDays
            ? widget.minDurationDays
            : widget.recommendedDurationDays;
  }

  String get _goalTitle {
    switch (widget.selectedGoal) {
      case GoalOption.loseWeight:
        return 'การลดน้ำหนัก';
      case GoalOption.maintainWeight:
        return 'การรักษาน้ำหนัก';
      case GoalOption.buildMuscle:
        return 'การเพิ่มกล้ามเนื้อ';
    }
  }

  String get _goalSubtitle {
    switch (widget.selectedGoal) {
      case GoalOption.loseWeight:
        return 'ควบคุมแคลอรี่';
      case GoalOption.maintainWeight:
        return 'รักษาสมดุล';
      case GoalOption.buildMuscle:
        return 'สร้างความแข็งแรง';
    }
  }

  Color get _goalColor {
    switch (widget.selectedGoal) {
      case GoalOption.loseWeight:
        return const Color(0xFFD76A3C);
      case GoalOption.maintainWeight:
        return const Color(0xFF497CEA);
      case GoalOption.buildMuscle:
        return const Color(0xFFB4AC15);
    }
  }

  String get _iconUrl {
    switch (widget.selectedGoal) {
      case GoalOption.loseWeight:
        return 'https://api.builder.io/api/v1/image/assets/TEMP/2b36cbc83f6282347dd67152d454841cc595df15';
      case GoalOption.maintainWeight:
        return 'https://api.builder.io/api/v1/image/assets/TEMP/caa3690bf64691cf18159ea72b5ec46944c37e66';
      case GoalOption.buildMuscle:
        return 'https://api.builder.io/api/v1/image/assets/TEMP/3ac072bc08b89b53ec34785b4a25b0021535bdd8';
    }
  }

  DateTime get _targetDate {
    return widget.currentDate.add(Duration(days: _selectedDurationDays));
  }

  String _formatDate(DateTime date) {
    final months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Header
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'เป้าหมายของคุณคือ',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            // เพิ่ม style ตรงนี้เพื่อให้ลูกๆ ใช้ค่าเริ่มต้นเดียวกัน และลบเส้นใต้สีแดง
                            style: const TextStyle(
                                color: Colors.black,
                                decoration: TextDecoration.none),
                            children: [
                              TextSpan(
                                  text: '$_goalTitle ',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: _goalColor)),
                              TextSpan(
                                  text: _goalSubtitle,
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: _goalColor)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Icon Circle
                    Center(
                      child: Container(
                        width: 85,
                        height: 85,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                          child: Image.network(
                            _iconUrl,
                            width: 65,
                            height: 65,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.fitness_center, size: 65);
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Info Boxes - Current and Target Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('วันนี้',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 5),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: _goalColor.withValues(alpha: 0.54),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  _formatDate(widget.currentDate),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Target date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('วันที่เป้าหมาย',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 5),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: _goalColor.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  _formatDate(_targetDate),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _goalColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Recommended duration info
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _goalColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: _goalColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ระยะเวลาแนะนำ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(widget.recommendedDurationDays / 7).toStringAsFixed(0)} สัปดาห์',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _goalColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Title - centered with color
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('ระยะเวลาที่ต้องการลดน้ำหนัก',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _goalColor)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ruler Slider - showing weeks
                    RulerSlider(
                      value: _selectedDurationDays.toDouble(),
                      minValue: widget.minDurationDays.toDouble(),
                      maxValue: 365,
                      step: 1,
                      unit: 'วัน',
                      showDecimals: false,
                      displayUnit: 'สัปดาห์',
                      displayDivisor: 7,
                      onChanged: (value) {
                        setState(() {
                          _selectedDurationDays = value.toInt();
                        });
                        widget.onDurationSelected(_selectedDurationDays);
                      },
                    ),

                    const SizedBox(height: 16),

                    // คำแนะนำตามงานวิจัย
                    Builder(builder: (_) {
                      String msg;
                      switch (widget.selectedGoal) {
                        case GoalOption.loseWeight:
                          msg = 'งานวิจัยแนะนำให้ลดน้ำหนัก 0.5-1 กก./สัปดาห์ '
                              'เพื่อความปลอดภัยและยั่งยืน '
                              '(ที่มา: CDC, WHO)';
                          break;
                        case GoalOption.buildMuscle:
                          msg = 'งานวิจัยแนะนำให้เพิ่มกล้ามเนื้อ '
                              '0.25-0.5 กก./สัปดาห์ เพื่อให้ร่างกายสร้าง'
                              'กล้ามเนื้ออย่างมีคุณภาพ';
                          break;
                        case GoalOption.maintainWeight:
                          msg =
                              'การรักษาน้ำหนักสม่ำเสมอช่วยให้สุขภาพดีในระยะยาว';
                          break;
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _goalColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 18, color: _goalColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msg,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    fontFamily: 'Inter',
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),

            // Back button
            Positioned(
              top: 20,
              left: 19,
              child: GestureDetector(
                onTap: widget.onBack,
                child: const Icon(Icons.chevron_left,
                    size: 40, color: Color(0xFF1D1B20)),
              ),
            ),

            // Submit button
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : widget.onSubmit,
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
                              offset: const Offset(0, 4))
                        ]),
                    child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('ถัดไป',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
