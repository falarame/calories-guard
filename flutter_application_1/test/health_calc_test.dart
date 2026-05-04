/// Unit Tests: Health Calculations & Validation
/// สูตรอ้างอิง:
///  - BMI    : Quetelet (1835), WHO 2004 Asian cutoff
///  - BMR    : Mifflin & St Jeor (1990) — PMID 2305711
///             + Asian correction ×0.94 (Huang KC, Obesity Research 2004)
///  - TDEE   : Harris-Benedict Activity Factors (revised Frankenfield 2005)
///  - Macro  : Atwater 4/4/9 kcal convention (FAO 2003)
///  - Weight loss safety: 3-level system
///             recommended ≤ 0.5 kg/week (AND 2016)
///             borderline   ≤ 1.0 kg/week (Stiegler & Cunliffe, Sports Med 2006)
///             unsafe       > 1.0 kg/week (Johansson, Obesity Reviews 2014)
///  - Min intake floor: 1200 kcal/day women, 1500 kcal/day men (NIH VLCD)
///  - Metabolic adaptation: 7700 rule overpredicts long-term (Hall, Lancet 2011)
///  - Age validation: min 13 — AAP/COPPA eating disorder risk < 13
///             Tallest human on record: 272 cm (Wadlow, 1940)
///             Guinness heaviest: 635 kg — app caps at 300 kg for realism

import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════
// Mirror of UserData logic from user_data_provider.dart
// ══════════════════════════════════════════════════════════════

double calcBmi(double weight, double height) {
  if (weight <= 0 || height <= 0) return 0;
  final h = height / 100;
  return weight / (h * h);
}

/// WHO Asia-Pacific 2004 BMI cutoffs
String bmiStatus(double bmi) {
  if (bmi <= 0) return '-';
  if (bmi < 18.5) return 'น้ำหนักน้อย';
  if (bmi < 23.0) return 'ปกติ';
  if (bmi < 25.0) return 'ท้วม';
  if (bmi < 30.0) return 'อ้วน';
  return 'อ้วนมาก';
}

/// Mifflin-St Jeor (1990) — PMID 2305711
/// + Asian correction factor ×0.94
/// อ้างอิง: Huang KC et al., Obesity Research 2004 — indirect calorimetry
/// ใน 150 คนไต้หวัน พบ Mifflin-St Jeor overestimate REE ~6–7% สำหรับ Asians
const _asianBmrFactor = 0.94;
double calcBmr(double weight, double height, int age, String gender) {
  if (weight <= 0 || height <= 0) return 1500;
  final base = (10 * weight) + (6.25 * height) - (5 * age);
  final raw = gender == 'male' ? base + 5 : base - 161;
  return raw * _asianBmrFactor;
}

/// Activity Multipliers (Harris-Benedict revised / Frankenfield 2005)
double activityFactor(String level) {
  switch (level) {
    case 'lightly_active':
      return 1.375;
    case 'moderately_active':
      return 1.55;
    case 'very_active':
      return 1.725;
    case 'extra_active':
      return 1.9;
    default:
      return 1.2; // sedentary
  }
}

double calcTdee(double bmr, String activityLevel) =>
    bmr * activityFactor(activityLevel);

/// Macro → kcal  (Atwater: protein/carbs = 4 kcal/g, fat = 9 kcal/g)
double macroCalories(double protein, double carbs, double fat) =>
    (protein * 4) + (carbs * 4) + (fat * 9);

/// Target calories with safety floor
/// 1 kg fat ≈ 7700 kcal → per day = 7700/7 ≈ 1100 kcal per kg/week
/// ⚠️ Metabolic Adaptation (Hall KD, The Lancet 2011):
/// สูตรนี้ถูกต้องระยะสั้น แต่ metabolism ปรับตัวลงเมื่อลดน้ำหนักนาน 4–6 สัปดาห์
/// ควรแนะนำให้ผู้ใช้ recalculate ทุก 4 สัปดาห์
double calcTargetCalories({
  required double tdee,
  required double kgPerWeek,
  required String gender,
}) {
  final raw = tdee + (kgPerWeek * 1100);
  final floor = gender == 'male' ? 1500.0 : 1200.0;
  return raw < floor ? floor : raw;
}

// ── Validation helpers ────────────────────────────────────────
bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

/// อ้างอิง: AAP (American Academy of Pediatrics) + COPPA 2016
/// แอป health/calorie tracking เสี่ยงกระตุ้น disordered eating ในเด็ก < 13
/// min 13 = มาตรฐาน COPPA / Instagram / TikTok
/// max 100 ปี = สมเหตุสมผลสำหรับ fitness app
bool isValidAge(int age) => age >= 13 && age <= 100;

/// WHO record สูงสุด 272 cm, ต่ำสุดผู้ใหญ่ ~54 cm
/// App range: 100–250 cm (เด็กอายุ 10 ปีสูงเฉลี่ย 138 cm)
bool isValidHeight(double cm) => cm >= 100 && cm <= 250;

/// Guinness heaviest 635 kg แต่ app cap 300 kg ตามความเป็นจริง
/// ต่ำสุด 20 kg = เด็กอายุ 10 ปี underweight สุดขีด (CDC < 3rd percentile)
bool isValidWeight(double kg) => kg >= 20 && kg <= 300;

/// Weight loss safety — 3 levels (อ้างอิงหลายงานวิจัย):
///   recommended : |kg/week| ≤ 0.5 — AND 2016, WHO sustainable
///   borderline  : |kg/week| ≤ 1.0 — Stiegler & Cunliffe, Sports Med 2006
///                 (ยอมรับได้แต่เสี่ยงสูญเสีย lean mass บางส่วน)
///   unsafe      : |kg/week| > 1.0 — เสี่ยง gallstone, muscle loss
///                 (Johansson et al., Obesity Reviews 2014)
String weightLossSafetyLevel(double kgPerWeek) {
  final abs = kgPerWeek.abs();
  if (abs > 1.0) return 'unsafe';
  if (abs > 0.5) return 'borderline';
  return 'recommended';
}

// ══════════════════════════════════════════════════════════════
void main() {
  // ────────────────────────────────────────────────────────────
  // 1. BMI Calculation
  // ────────────────────────────────────────────────────────────
  group('BMI Calculation (weight/height²)', () {
    test('ปกติ: ชาย 70 kg, 175 cm → 22.86', () {
      expect(calcBmi(70, 175), closeTo(22.86, 0.01));
    });

    test('น้ำหนักน้อย: 45 kg, 170 cm → 15.57', () {
      expect(calcBmi(45, 170), closeTo(15.57, 0.01));
    });

    test('อ้วน: 100 kg, 165 cm → 36.73', () {
      expect(calcBmi(100, 165), closeTo(36.73, 0.01));
    });

    test('ท้วม (Asian cutoff): 68 kg, 170 cm → 23.53', () {
      expect(calcBmi(68, 170), closeTo(23.53, 0.01));
    });

    test('weight = 0 → ส่งคืน 0 (guard)', () {
      expect(calcBmi(0, 170), 0);
    });

    test('height = 0 → ส่งคืน 0 (guard)', () {
      expect(calcBmi(70, 0), 0);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 2. BMI Status (WHO Asia-Pacific 2004)
  // ────────────────────────────────────────────────────────────
  group('BMI Status — Asian cutoff (WHO Asia-Pacific 2004)', () {
    test('BMI 17.0 → น้ำหนักน้อย (<18.5)', () {
      expect(bmiStatus(17.0), 'น้ำหนักน้อย');
    });

    test('BMI 18.5 → ปกติ (18.5–22.9)', () {
      expect(bmiStatus(18.5), 'ปกติ');
    });

    test('BMI 22.9 → ปกติ (boundary)', () {
      expect(bmiStatus(22.9), 'ปกติ');
    });

    test('BMI 23.0 → ท้วม (23.0–24.9)', () {
      expect(bmiStatus(23.0), 'ท้วม');
    });

    test('BMI 25.0 → อ้วน (25.0–29.9)', () {
      expect(bmiStatus(25.0), 'อ้วน');
    });

    test('BMI 30.0 → อ้วนมาก (≥30)', () {
      expect(bmiStatus(30.0), 'อ้วนมาก');
    });

    test('BMI 0 → - (invalid)', () {
      expect(bmiStatus(0), '-');
    });
  });

  // ────────────────────────────────────────────────────────────
  // 3. BMR — Mifflin-St Jeor 1990 + Asian correction ×0.94
  //    Male:   ((10w)+(6.25h)-(5a)+5)   × 0.94
  //    Female: ((10w)+(6.25h)-(5a)-161) × 0.94
  //    อ้างอิง: Huang KC et al., Obesity Research 2004
  // ────────────────────────────────────────────────────────────
  group('BMR — Mifflin-St Jeor 1990 + Asian ×0.94', () {
    test('ชาย 70 kg, 175 cm, อายุ 25 → 1573.3 kcal (Asian corrected)', () {
      // raw = 1673.75 × 0.94 = 1573.325
      expect(calcBmr(70, 175, 25, 'male'), closeTo(1573.3, 0.5));
    });

    test('หญิง 60 kg, 162 cm, อายุ 30 → 1223.4 kcal (Asian corrected)', () {
      // raw = 1301.5 × 0.94 = 1223.41
      expect(calcBmr(60, 162, 30, 'female'), closeTo(1223.4, 0.5));
    });

    test('ชาย 90 kg, 180 cm, อายุ 40 → 1720.2 kcal (Asian corrected)', () {
      // raw = 1830.0 × 0.94 = 1720.2
      expect(calcBmr(90, 180, 40, 'male'), closeTo(1720.2, 0.5));
    });

    test('หญิง 50 kg, 155 cm, อายุ 20 → 1135.3 kcal (Asian corrected)', () {
      // raw = 1207.75 × 0.94 = 1135.285
      expect(calcBmr(50, 155, 20, 'female'), closeTo(1135.3, 0.5));
    });

    test('Asian BMR < Mifflin-St Jeor ดิบ เสมอ (correction ลด ~6%)', () {
      final rawMale = (10 * 70.0) + (6.25 * 175) - (5 * 25) + 5;
      expect(calcBmr(70, 175, 25, 'male'), lessThan(rawMale));
    });

    test('weight/height = 0 → fallback 1500', () {
      expect(calcBmr(0, 175, 25, 'male'), 1500);
      expect(calcBmr(70, 0, 25, 'male'), 1500);
    });

    test('อายุมาก: ชาย 70 kg, 170 cm, อายุ 65 → BMR ลดลง', () {
      final young = calcBmr(70, 170, 25, 'male');
      final old = calcBmr(70, 170, 65, 'male');
      expect(old, lessThan(young));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 4. Activity Factor
  // ────────────────────────────────────────────────────────────
  group('Activity Factor (PAL Multipliers)', () {
    test('sedentary → 1.2', () {
      expect(activityFactor('sedentary'), 1.2);
    });

    test('lightly_active → 1.375', () {
      expect(activityFactor('lightly_active'), 1.375);
    });

    test('moderately_active → 1.55', () {
      expect(activityFactor('moderately_active'), 1.55);
    });

    test('very_active → 1.725', () {
      expect(activityFactor('very_active'), 1.725);
    });

    test('extra_active → 1.9', () {
      expect(activityFactor('extra_active'), 1.9);
    });

    test('ค่าไม่รู้จัก → 1.2 (default sedentary)', () {
      expect(activityFactor('unknown'), 1.2);
      expect(activityFactor(''), 1.2);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 5. TDEE = BMR × Activity Factor
  // ────────────────────────────────────────────────────────────
  group('TDEE Calculation', () {
    test('BMR 1674 × sedentary 1.2 → 2008.8', () {
      expect(calcTdee(1674, 'sedentary'), closeTo(2008.8, 0.5));
    });

    test('BMR 1674 × moderately_active 1.55 → 2594.7', () {
      expect(calcTdee(1674, 'moderately_active'), closeTo(2594.7, 0.5));
    });

    test('BMR 1674 × very_active 1.725 → 2887.7', () {
      expect(calcTdee(1674, 'very_active'), closeTo(2887.7, 0.5));
    });

    test('TDEE > BMR เสมอ (activity เพิ่มพลังงาน)', () {
      final bmr = calcBmr(70, 175, 25, 'male');
      expect(calcTdee(bmr, 'moderately_active'), greaterThan(bmr));
    });

    test('TDEE very_active > moderately_active > sedentary', () {
      final bmr = 1500.0;
      expect(calcTdee(bmr, 'very_active'),
          greaterThan(calcTdee(bmr, 'moderately_active')));
      expect(calcTdee(bmr, 'moderately_active'),
          greaterThan(calcTdee(bmr, 'sedentary')));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 6. Macro → Calories  (Atwater: P=4, C=4, F=9 kcal/g)
  //    อ้างอิง FAO/WHO 2003 Food Energy – Methods of Analysis
  // ────────────────────────────────────────────────────────────
  group('Calorie from Macronutrients (Atwater 4/4/9)', () {
    test('protein 30g, carbs 50g, fat 20g → 500 kcal', () {
      // (30×4)+(50×4)+(20×9) = 120+200+180 = 500
      expect(macroCalories(30, 50, 20), closeTo(500, 0.1));
    });

    test('pure protein 25g → 100 kcal', () {
      expect(macroCalories(25, 0, 0), closeTo(100, 0.1));
    });

    test('pure carbs 100g → 400 kcal', () {
      expect(macroCalories(0, 100, 0), closeTo(400, 0.1));
    });

    test('pure fat 10g → 90 kcal', () {
      expect(macroCalories(0, 0, 10), closeTo(90, 0.1));
    });

    test('ทุกค่า 0 → 0 kcal', () {
      expect(macroCalories(0, 0, 0), 0);
    });

    test('ข้าวสวย 1 ถ้วย (~200g): carbs≈44g, protein≈4g, fat≈0.5g → 196.5 kcal',
        () {
      // (4×4)+(44×4)+(0.5×9) = 16+176+4.5 = 196.5
      expect(macroCalories(4, 44, 0.5), closeTo(196.5, 0.1));
    });

    test('fat มีพลังงานมากกว่า carbs ที่น้ำหนักเท่ากัน', () {
      expect(macroCalories(0, 0, 10), greaterThan(macroCalories(0, 10, 0)));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 7. Target Calories + Safety Floor
  //    อ้างอิง: NIH — Very Low Calorie Diets
  //    Floor: 1200 kcal/day หญิง, 1500 kcal/day ชาย
  //    Weight loss: 1 kg ≈ 7700 kcal → 0.5 kg/week = 550 kcal/day deficit
  // ────────────────────────────────────────────────────────────
  group('Target Calories & Safety Floor (NIH guideline)', () {
    test('ลดน้ำหนัก 0.5 kg/week: TDEE 2200 หญิง → target 1650 kcal', () {
      // 2200 + (-0.5 × 1100) = 2200 - 550 = 1650 > floor 1200 → ใช้ค่าคำนวณ
      expect(
        calcTargetCalories(tdee: 2200, kgPerWeek: -0.5, gender: 'female'),
        closeTo(1650, 1),
      );
    });

    test('เพิ่มกล้ามเนื้อ 0.5 kg/week: TDEE 2000 → target 2550 kcal', () {
      expect(
        calcTargetCalories(tdee: 2000, kgPerWeek: 0.5, gender: 'male'),
        closeTo(2550, 1),
      );
    });

    test('คง goal: TDEE 2000, 0 kg/week → target = TDEE 2000', () {
      expect(
        calcTargetCalories(tdee: 2000, kgPerWeek: 0, gender: 'male'),
        closeTo(2000, 1),
      );
    });

    test('Floor ชาย: ถ้าคำนวณได้ต่ำกว่า 1500 → บังคับ 1500 kcal', () {
      final result =
          calcTargetCalories(tdee: 1600, kgPerWeek: -1.0, gender: 'male');
      // 1600 - 1100 = 500 < floor 1500 → clamp to 1500
      expect(result, greaterThanOrEqualTo(1500));
    });

    test('Floor หญิง: ถ้าคำนวณได้ต่ำกว่า 1200 → บังคับ 1200 kcal', () {
      final result =
          calcTargetCalories(tdee: 1400, kgPerWeek: -1.0, gender: 'female');
      // 1400 - 1100 = 300 < floor 1200 → clamp to 1200
      expect(result, greaterThanOrEqualTo(1200));
    });

    test('Target calories เมื่อ TDEE สูงพอ ไม่โดน floor', () {
      final result =
          calcTargetCalories(tdee: 2500, kgPerWeek: -0.5, gender: 'female');
      // 2500 - 550 = 1950 > floor 1200 → ใช้ค่าคำนวณ
      expect(result, closeTo(1950, 1));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 8. Email Validation
  // ────────────────────────────────────────────────────────────
  group('Email Validation', () {
    test('email ถูกต้อง: user@example.com', () {
      expect(isValidEmail('user@example.com'), true);
    });

    test('email ถูกต้อง: sub.domain+tag@mail.co.th', () {
      expect(isValidEmail('sub.domain+tag@mail.co.th'), true);
    });

    test('ไม่มี @ → invalid', () {
      expect(isValidEmail('userexample.com'), false);
    });

    test('ไม่มี domain → invalid', () {
      expect(isValidEmail('user@'), false);
    });

    test('ว่างเปล่า → invalid', () {
      expect(isValidEmail(''), false);
    });

    test('มีแค่ @ → invalid', () {
      expect(isValidEmail('@'), false);
    });

    test('ไม่มี TLD → invalid', () {
      expect(isValidEmail('user@domain'), false);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 9. Input Validation — Age
  //    อ้างอิง: AAP + COPPA — min 13 เพื่อป้องกัน disordered eating
  //    max 100 = สมเหตุสมผลสำหรับ fitness app
  // ────────────────────────────────────────────────────────────
  group('Validation — Age (13–100 ปี, AAP/COPPA)', () {
    test('อายุ 25 → valid', () {
      expect(isValidAge(25), true);
    });

    test('อายุ 13 → valid (min boundary, COPPA)', () {
      expect(isValidAge(13), true);
    });

    test('อายุ 100 → valid (max boundary)', () {
      expect(isValidAge(100), true);
    });

    test('อายุ 12 → invalid (< COPPA/AAP min)', () {
      expect(isValidAge(12), false);
    });

    test('อายุ 10 → invalid (เสี่ยง disordered eating)', () {
      expect(isValidAge(10), false);
    });

    test('อายุ 101 → invalid', () {
      expect(isValidAge(101), false);
    });

    test('อายุ 0 → invalid', () {
      expect(isValidAge(0), false);
    });

    test('อายุ -1 → invalid', () {
      expect(isValidAge(-1), false);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 10. Input Validation — Height
  //    อ้างอิง: Guinness world's tallest = 272 cm (Robert Wadlow, 1940)
  //    World's shortest adult = ~54 cm
  //    App range: 100–250 cm (เด็กอายุ 10 สูงเฉลี่ย ~138 cm)
  // ────────────────────────────────────────────────────────────
  group('Validation — Height (100–250 cm)', () {
    test('ส่วนสูง 170 cm → valid', () {
      expect(isValidHeight(170), true);
    });

    test('ส่วนสูง 100 cm → valid (min boundary)', () {
      expect(isValidHeight(100), true);
    });

    test('ส่วนสูง 250 cm → valid (max boundary)', () {
      expect(isValidHeight(250), true);
    });

    test('ส่วนสูง 99 cm → invalid', () {
      expect(isValidHeight(99), false);
    });

    test('ส่วนสูง 251 cm → invalid', () {
      expect(isValidHeight(251), false);
    });

    test('ส่วนสูง 0 → invalid', () {
      expect(isValidHeight(0), false);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 11. Input Validation — Weight
  //    อ้างอิง: CDC growth chart เด็ก 10 ปี underweight = ~20 kg
  //    Guinness heaviest living = 635 kg — App cap 300 kg เพื่อ UX
  // ────────────────────────────────────────────────────────────
  group('Validation — Weight (20–300 kg)', () {
    test('น้ำหนัก 65 kg → valid', () {
      expect(isValidWeight(65), true);
    });

    test('น้ำหนัก 20 kg → valid (min boundary)', () {
      expect(isValidWeight(20), true);
    });

    test('น้ำหนัก 300 kg → valid (max boundary)', () {
      expect(isValidWeight(300), true);
    });

    test('น้ำหนัก 19 kg → invalid', () {
      expect(isValidWeight(19), false);
    });

    test('น้ำหนัก 301 kg → invalid', () {
      expect(isValidWeight(301), false);
    });

    test('น้ำหนัก 0 → invalid', () {
      expect(isValidWeight(0), false);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 12. Weight Loss Safety — 3 levels
  //    recommended : ≤ 0.5 kg/week (AND 2016)
  //    borderline  : ≤ 1.0 kg/week (Stiegler & Cunliffe, Sports Med 2006)
  //    unsafe      : > 1.0 kg/week (Johansson, Obesity Reviews 2014)
  // ────────────────────────────────────────────────────────────
  group('Weight Loss Safety — 3 Levels (AND/Stiegler/Johansson)', () {
    test('ลด 0.5 kg/week → recommended ✅ (แนะนำที่สุด)', () {
      expect(weightLossSafetyLevel(-0.5), 'recommended');
    });

    test('ลด 0.3 kg/week → recommended ✅', () {
      expect(weightLossSafetyLevel(-0.3), 'recommended');
    });

    test('คง goal 0 kg/week → recommended ✅', () {
      expect(weightLossSafetyLevel(0), 'recommended');
    });

    test('ลด 0.6 kg/week → borderline ⚠️ (ยอมรับได้แต่เฝ้าระวัง)', () {
      expect(weightLossSafetyLevel(-0.6), 'borderline');
    });

    test('ลด 1.0 kg/week → borderline ⚠️ (ขีดบน Stiegler 2006)', () {
      expect(weightLossSafetyLevel(-1.0), 'borderline');
    });

    test('เพิ่ม 0.8 kg/week (bulk) → borderline ⚠️', () {
      expect(weightLossSafetyLevel(0.8), 'borderline');
    });

    test('ลด 1.1 kg/week → unsafe ❌ (เสี่ยง muscle loss + gallstone)', () {
      expect(weightLossSafetyLevel(-1.1), 'unsafe');
    });

    test('ลด 2.0 kg/week (crash diet) → unsafe ❌', () {
      expect(weightLossSafetyLevel(-2.0), 'unsafe');
    });

    test('เพิ่ม 1.5 kg/week → unsafe ❌ (เสี่ยง fat gain สูง)', () {
      expect(weightLossSafetyLevel(1.5), 'unsafe');
    });
  });
}
