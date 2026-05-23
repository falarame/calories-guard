import 'package:flutter/material.dart';
import '../../widget/ruler_slider.dart';
import '../../providers/user_data_provider.dart';

class TargetWeightSliderScreen extends StatefulWidget {
  final GoalOption selectedGoal;
  final double currentWeight;
  final double recommendedWeight;
  final double minWeight;
  final double maxWeight;
  final VoidCallback onNext;
  final ValueChanged<double> onWeightSelected;

  const TargetWeightSliderScreen({
    super.key,
    required this.selectedGoal,
    required this.currentWeight,
    required this.recommendedWeight,
    required this.minWeight,
    required this.maxWeight,
    required this.onNext,
    required this.onWeightSelected,
  });

  @override
  State<TargetWeightSliderScreen> createState() =>
      _TargetWeightSliderScreenState();
}

class _TargetWeightSliderScreenState extends State<TargetWeightSliderScreen> {
  late double _selectedWeight;

  @override
  void initState() {
    super.initState();
    _selectedWeight = widget.recommendedWeight;
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

                    // Info Boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current weight
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('น้ำหนักปัจจุบัน',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 5),
                            Container(
                              width: 164,
                              height: 37,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _goalColor.withValues(alpha: 0.54),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                '${widget.currentWeight.toStringAsFixed(1)} กก.',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        // Recommended weight
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('น้ำหนักแนะนำ',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 5),
                            Container(
                              width: 168,
                              height: 37,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _goalColor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                '${widget.recommendedWeight.toStringAsFixed(1)} กก.',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _goalColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Title - centered with color
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('เป้าหมายน้ำหนัก',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _goalColor)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ruler Slider
                    Builder(
                      builder: (context) {
                        if (_selectedWeight < widget.minWeight) {
                          _selectedWeight = widget.minWeight;
                          widget.onWeightSelected(_selectedWeight);
                        }
                        if (_selectedWeight > widget.maxWeight) {
                          _selectedWeight = widget.maxWeight;
                          widget.onWeightSelected(_selectedWeight);
                        }
                        return RulerSlider(
                          value: _selectedWeight,
                          minValue: widget.minWeight,
                          maxValue: widget.maxWeight,
                          step: 0.5,
                          unit: 'กก.',
                          showDecimals: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedWeight = value;
                            });
                            widget.onWeightSelected(value);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Back button
            Positioned(
              top: 20,
              left: 19,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.chevron_left,
                    size: 40, color: Color(0xFF1D1B20)),
              ),
            ),

            // Next button
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: widget.onNext,
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
                    child: const Center(
                        child: Text('ถัดไป',
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
