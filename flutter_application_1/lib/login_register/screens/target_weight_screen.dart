import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart';
import '/widget/bottom_bar.dart';
import 'target_weight_slider_screen.dart';
import 'duration_slider_screen.dart';

class TargetWeightScreen extends ConsumerStatefulWidget {
  final GoalOption selectedGoal;

  const TargetWeightScreen({super.key, required this.selectedGoal});

  @override
  ConsumerState<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends ConsumerState<TargetWeightScreen> {
  final AuthService _authService = AuthService();

  // Slider values
  double _selectedWeight = 0;
  int _selectedDurationDays = 90;
  bool _showWeightScreen = true;

  double _calculateRecommendedWeight(
      double currentWeight, double minWeight, double maxWeight) {
    double recommended;
    if (widget.selectedGoal == GoalOption.loseWeight) {
      recommended = currentWeight * 0.9;
    } else if (widget.selectedGoal == GoalOption.buildMuscle) {
      recommended = currentWeight * 1.1;
    } else {
      recommended = currentWeight;
    }
    if (recommended < minWeight) recommended = minWeight;
    if (recommended > maxWeight) recommended = maxWeight;
    return recommended;
  }

  double _minTargetWeight(double currentWeight, double bmi, double heightCm) {
    if (widget.selectedGoal == GoalOption.buildMuscle) {
      // สำหรับเพิ่มกล้ามเนื้อ ให้ไม่เกิน BMI ขั้นสูงสุด 30 หากมีความสูง
      if (heightCm > 0) {
        return currentWeight;
      }
      return currentWeight;
    }
    if (widget.selectedGoal == GoalOption.loseWeight) {
      // ถ้า underweight, ไม่ลด
      if (bmi < 18.5) return currentWeight;
      // ต้องไม่ลดต่ำกว่า BMI 18.5
      if (heightCm > 0) {
        final minWeightByBMI = 18.5 * ((heightCm / 100) * (heightCm / 100));
        return minWeightByBMI;
      }
      return currentWeight * 0.85;
    }
    return currentWeight * 0.9;
  }

  double _maxTargetWeight(double currentWeight, double bmi, double heightCm) {
    if (widget.selectedGoal == GoalOption.loseWeight) {
      return currentWeight;
    }
    if (widget.selectedGoal == GoalOption.buildMuscle) {
      if (bmi >= 23 && heightCm > 0) {
        final maxWeightByBMI = 30 * ((heightCm / 100) * (heightCm / 100));
        return maxWeightByBMI;
      }
      return currentWeight * 1.25;
    }
    return currentWeight * 1.05;
  }

  /// ระยะเวลาขั้นต่ำที่ผู้ใช้เลือกได้ตามเกณฑ์งานวิจัย (CDC/WHO)
  /// - ลดน้ำหนัก: ปลอดภัยสูงสุด 1 กก./สัปดาห์
  /// - เพิ่มกล้ามเนื้อ: 0.5 กก./สัปดาห์
  /// - รักษาน้ำหนัก: ขั้นต่ำ 7 วัน
  int _minDurationDays(double currentWeight, double targetWeight) {
    final delta = (currentWeight - targetWeight).abs();
    if (widget.selectedGoal == GoalOption.maintainWeight || delta <= 0) {
      return 7;
    }
    final maxRatePerWeek =
        widget.selectedGoal == GoalOption.loseWeight ? 1.0 : 0.5;
    final minWeeks = (delta / maxRatePerWeek).ceil();
    final minDays = minWeeks * 7;
    return minDays < 28 ? 28 : minDays; // ขั้นต่ำ 4 สัปดาห์เสมอ
  }

  int _calculateRecommendedDuration(double currentWeight, double targetWeight) {
    final weightDifference = (currentWeight - targetWeight).abs();
    int rec;
    if (widget.selectedGoal == GoalOption.loseWeight) {
      rec = (weightDifference * 30).ceil(); // ~0.23 kg/week
    } else if (widget.selectedGoal == GoalOption.buildMuscle) {
      rec = (weightDifference * 60).ceil(); // ~0.12 kg/week
    } else {
      rec = 90;
    }
    final minD = _minDurationDays(currentWeight, targetWeight);
    return rec < minD ? minD : rec;
  }

  void _submit() async {
    if (_selectedWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')));
      return;
    }

    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _selectedDurationDays));

    final userId = ref.read(userDataProvider).userId;

    bool success = await _authService.updateProfile(userId, {
      "target_weight_kg": _selectedWeight,
      "goal_target_date":
          "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}",
    });

    if (success) {
      ref.read(userDataProvider.notifier).setGoalInfo(
          targetWeight: _selectedWeight,
          duration: _selectedDurationDays,
          targetDate: targetDate);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final double currentWeight = userData.weight;
    final double bmi = userData.bmi;
    final double minWeight =
        _minTargetWeight(currentWeight, bmi, userData.height);
    final double maxWeight =
        _maxTargetWeight(currentWeight, bmi, userData.height);
    final double recommendedWeight =
        _calculateRecommendedWeight(currentWeight, minWeight, maxWeight);

    // Initialize selected weight on first build
    if (_selectedWeight == 0) {
      _selectedWeight = recommendedWeight;
    }

    // Ensure selection stays valid
    if (_selectedWeight < minWeight) _selectedWeight = minWeight;
    if (_selectedWeight > maxWeight) _selectedWeight = maxWeight;

    // Initialize selected duration based on weight difference
    int recommendedDuration =
        _calculateRecommendedDuration(currentWeight, _selectedWeight);
    if (_selectedDurationDays == 90 && recommendedDuration != 90) {
      _selectedDurationDays = recommendedDuration;
    }

    if (_showWeightScreen) {
      return TargetWeightSliderScreen(
        selectedGoal: widget.selectedGoal,
        currentWeight: currentWeight,
        recommendedWeight: recommendedWeight,
        minWeight: minWeight,
        maxWeight: maxWeight,
        onWeightSelected: (weight) {
          setState(() {
            _selectedWeight = weight;
          });
        },
        onNext: () {
          setState(() {
            _showWeightScreen = false;
          });
        },
      );
    } else {
      return DurationSliderScreen(
        selectedGoal: widget.selectedGoal,
        currentDate: DateTime.now(),
        minDurationDays:
            _minDurationDays(currentWeight, _selectedWeight),
        recommendedDurationDays:
            _calculateRecommendedDuration(currentWeight, _selectedWeight),
        onBack: () {
          setState(() {
            _showWeightScreen = true;
          });
        },
        onSubmit: _submit,
        onDurationSelected: (days) {
          setState(() {
            _selectedDurationDays = days;
          });
        },
      );
    }
  }
}
