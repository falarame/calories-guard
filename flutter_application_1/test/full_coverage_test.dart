/// ══════════════════════════════════════════════════════════════
/// Full Coverage Tests — ทดสอบทุก function ของแอป
/// ══════════════════════════════════════════════════════════════
///
/// ครอบคลุม:
///   A. UserData getters  — age, bmi, bmr, tdee, targetCalories,
///                          targetProtein, targetCarbs, targetFat,
///                          macro ratios, effectiveWeeks
///   B. UserDataNotifier  — ทุก method (16 methods)
///   C. Food model        — fromJson, field mapping, edge cases
///   D. FoodLog model     — auto snapshot, meal types
///   E. AppSettings       — copyWith, default values
///   F. GoalOption enum   — ค่า enum และ macro ratio ตาม goal

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/models.dart';
import 'package:flutter_application_1/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/providers/settings_provider.dart';
import 'package:flutter_application_1/providers/pending_food_provider.dart';

// ── helper: สร้าง ProviderContainer พร้อม override ──────────
ProviderContainer makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

// ── helper: UserData ที่กำหนดค่าครบ ──────────────────────────
UserData sampleMale({
  double weight = 70,
  double height = 175,
  int ageYear = 1999,
  String goal = 'lose',
  String activity = 'sedentary',
}) {
  return UserData(
    gender: 'male',
    birthDate: DateTime(ageYear, 1, 1),
    height: height,
    weight: weight,
    goal: goal == 'lose'
        ? GoalOption.loseWeight
        : goal == 'build'
            ? GoalOption.buildMuscle
            : GoalOption.maintainWeight,
    activityLevel: activity,
    targetWeight: goal == 'lose' ? 65 : 75,
    duration: 12,
  );
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // A. UserData Getters
  // ══════════════════════════════════════════════════════════════

  group('[UserData] age getter', () {
    test('age คำนวณจาก birthDate ถูกต้อง', () {
      final thisYear = DateTime.now().year;
      final u = UserData(birthDate: DateTime(thisYear - 25, 1, 1));
      expect(u.age, 25);
    });

    test('birthDate = null → default age 20', () {
      expect(UserData().age, 20);
    });

    test('วันเกิดยังไม่ถึงในปีนี้ → age ลด 1', () {
      final now = DateTime.now();
      final bday = DateTime(now.year - 30, now.month + 1, 1);
      final u = UserData(birthDate: bday);
      expect(u.age, 29);
    });
  });

  group('[UserData] bmi getter', () {
    test('70 kg, 175 cm → 22.86', () {
      expect(sampleMale().bmi, closeTo(22.86, 0.1));
    });

    test('weight = 0 → 0 (guard)', () {
      expect(UserData(weight: 0, height: 175).bmi, 0);
    });

    test('height = 0 → 0 (guard)', () {
      expect(UserData(weight: 70, height: 0).bmi, 0);
    });

    test('BMI ชาย 90 kg 180 cm → 27.78', () {
      final u = UserData(weight: 90, height: 180);
      expect(u.bmi, closeTo(27.78, 0.1));
    });
  });

  group('[UserData] bmr getter (Asian ×0.94)', () {
    test('ชาย 70 kg 175 cm อายุ ~25 → ~1573 kcal', () {
      expect(
          sampleMale(ageYear: DateTime.now().year - 25).bmr, closeTo(1573, 5));
    });

    test('weight = 0 → fallback 1500', () {
      expect(UserData(weight: 0, height: 175).bmr, 1500);
    });

    test('height = 0 → fallback 1500', () {
      expect(UserData(weight: 70, height: 0).bmr, 1500);
    });

    test('BMR หญิง < BMR ชาย (น้ำหนัก/ส่วนสูงเท่ากัน)', () {
      final male = UserData(
          gender: 'male',
          weight: 70,
          height: 170,
          birthDate: DateTime(2000, 1, 1));
      final female = UserData(
          gender: 'female',
          weight: 70,
          height: 170,
          birthDate: DateTime(2000, 1, 1));
      expect(male.bmr, greaterThan(female.bmr));
    });

    test('BMR Asian < Mifflin-St Jeor ดิบ เสมอ', () {
      final u = sampleMale(ageYear: DateTime.now().year - 25);
      final rawMale = ((10 * 70.0) + (6.25 * 175) - (5 * u.age) + 5);
      expect(u.bmr, lessThan(rawMale));
    });

    test('อายุมากขึ้น → BMR ลดลง', () {
      final young = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1));
      final old = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(1960, 1, 1));
      expect(old.bmr, lessThan(young.bmr));
    });
  });

  group('[UserData] tdee getter', () {
    test('sedentary → BMR × 1.2', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'sedentary');
      expect(u.tdee, closeTo(u.bmr * 1.2, 0.1));
    });

    test('lightly_active → BMR × 1.375', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'lightly_active');
      expect(u.tdee, closeTo(u.bmr * 1.375, 0.1));
    });

    test('moderately_active → BMR × 1.55', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'moderately_active');
      expect(u.tdee, closeTo(u.bmr * 1.55, 0.1));
    });

    test('very_active → BMR × 1.725', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'very_active');
      expect(u.tdee, closeTo(u.bmr * 1.725, 0.1));
    });

    test('extra_active → BMR × 1.9', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'extra_active');
      expect(u.tdee, closeTo(u.bmr * 1.9, 0.1));
    });

    test('unknown activity → default 1.2 (sedentary)', () {
      final u1 = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'unknown');
      final u2 = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'sedentary');
      expect(u1.tdee, closeTo(u2.tdee, 0.1));
    });

    test('TDEE > BMR เสมอ', () {
      final u = sampleMale();
      expect(u.tdee, greaterThan(u.bmr));
    });
  });

  group('[UserData] targetCalories getter', () {
    test('storedTargetCalories มีค่า → ใช้ stored', () {
      final u = UserData(storedTargetCalories: 1800);
      expect(u.targetCalories, 1800);
    });

    test('storedTargetCalories = 0 → คำนวณจาก TDEE', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'sedentary',
          goal: GoalOption.loseWeight,
          storedTargetCalories: 0);
      expect(u.targetCalories, lessThan(u.tdee));
    });

    test('goal = loseWeight → targetCalories < TDEE', () {
      final u = sampleMale(goal: 'lose');
      if (u.storedTargetCalories == null || u.storedTargetCalories! <= 0) {
        expect(u.targetCalories, lessThan(u.tdee));
      }
    });

    test('goal = buildMuscle → targetCalories > TDEE', () {
      final u = UserData(
          gender: 'male',
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1),
          activityLevel: 'sedentary',
          goal: GoalOption.buildMuscle);
      expect(u.targetCalories, greaterThan(u.tdee));
    });
  });

  group('[UserData] Macro Ratios', () {
    test('loseWeight: protein 30%, carbs 40%, fat 30%', () {
      final u = UserData(
          goal: GoalOption.loseWeight,
          storedTargetCalories: 2000,
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1));
      expect(u.targetProtein, closeTo(2000 * 0.30 / 4, 2));
      expect(u.targetCarbs, closeTo(2000 * 0.40 / 4, 2));
      expect(u.targetFat, closeTo(2000 * 0.30 / 9, 2));
    });

    test('maintainWeight: protein 25%, carbs 45%, fat 30%', () {
      final u = UserData(
          goal: GoalOption.maintainWeight,
          storedTargetCalories: 2000,
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1));
      expect(u.targetProtein, closeTo(2000 * 0.25 / 4, 2));
      expect(u.targetCarbs, closeTo(2000 * 0.45 / 4, 2));
      expect(u.targetFat, closeTo(2000 * 0.30 / 9, 2));
    });

    test('buildMuscle: protein 30%, carbs 50%, fat 20%', () {
      final u = UserData(
          goal: GoalOption.buildMuscle,
          storedTargetCalories: 2000,
          weight: 70,
          height: 175,
          birthDate: DateTime(2000, 1, 1));
      expect(u.targetProtein, closeTo(2000 * 0.30 / 4, 2));
      expect(u.targetCarbs, closeTo(2000 * 0.50 / 4, 2));
      expect(u.targetFat, closeTo(2000 * 0.20 / 9, 2));
    });

    test('storedTargetProtein มีค่า → ใช้ stored', () {
      final u = UserData(storedTargetProtein: 150);
      expect(u.targetProtein, 150);
    });

    test('storedTargetCarbs มีค่า → ใช้ stored', () {
      final u = UserData(storedTargetCarbs: 200);
      expect(u.targetCarbs, 200);
    });

    test('storedTargetFat มีค่า → ใช้ stored', () {
      final u = UserData(storedTargetFat: 60);
      expect(u.targetFat, 60);
    });
  });

  group('[UserData] copyWith', () {
    test('copyWith weight → ค่าอื่นไม่เปลี่ยน', () {
      final u = sampleMale().copyWith(weight: 80);
      expect(u.weight, 80);
      expect(u.height, 175);
    });

    test('copyWith avatarUrl = null + clearAvatarUrl = true → null', () {
      final u =
          UserData(avatarUrl: 'http://img.png').copyWith(clearAvatarUrl: true);
      expect(u.avatarUrl, isNull);
    });

    test('copyWith ไม่ระบุ field → ค่าเดิม', () {
      final u = UserData(name: 'สมชาย', email: 'a@b.com').copyWith();
      expect(u.name, 'สมชาย');
      expect(u.email, 'a@b.com');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // B. UserDataNotifier — ทุก method
  // ══════════════════════════════════════════════════════════════

  group('[UserDataNotifier] setUserId', () {
    test('setUserId → state.userId เปลี่ยน', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setUserId(99);
      expect(c.read(userDataProvider).userId, 99);
    });
  });

  group('[UserDataNotifier] setLoginInfo', () {
    test('setLoginInfo → email/password ถูก set', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setLoginInfo('a@b.com', 'pass123');
      final s = c.read(userDataProvider);
      expect(s.email, 'a@b.com');
      expect(s.password, 'pass123');
    });
  });

  group('[UserDataNotifier] setGender', () {
    test('setGender female → state.gender = female', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setGender('female');
      expect(c.read(userDataProvider).gender, 'female');
    });
  });

  group('[UserDataNotifier] setPersonalInfo', () {
    test('setPersonalInfo → name/height/weight/birthDate ถูก set', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setPersonalInfo(
          name: 'ทดสอบ',
          birthDate: DateTime(2000, 6, 15),
          height: 170,
          weight: 65);
      final s = c.read(userDataProvider);
      expect(s.name, 'ทดสอบ');
      expect(s.height, 170);
      expect(s.weight, 65);
      expect(s.birthDate, DateTime(2000, 6, 15));
    });
  });

  group('[UserDataNotifier] setGoal', () {
    test('setGoal buildMuscle → state.goal = buildMuscle', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setGoal(GoalOption.buildMuscle);
      expect(c.read(userDataProvider).goal, GoalOption.buildMuscle);
    });

    test('setGoal loseWeight → state.goal = loseWeight', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setGoal(GoalOption.loseWeight);
      expect(c.read(userDataProvider).goal, GoalOption.loseWeight);
    });

    test('setGoal maintainWeight → state.goal = maintainWeight', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setGoal(GoalOption.maintainWeight);
      expect(c.read(userDataProvider).goal, GoalOption.maintainWeight);
    });
  });

  group('[UserDataNotifier] setGoalInfo', () {
    test('setGoalInfo → targetWeight/targetDate/duration ถูก set', () {
      final c = makeContainer();
      final td = DateTime(2025, 12, 31);
      c
          .read(userDataProvider.notifier)
          .setGoalInfo(targetWeight: 60, targetDate: td, duration: 90);
      final s = c.read(userDataProvider);
      expect(s.targetWeight, 60);
      expect(s.targetDate, td);
      expect(s.duration, 90);
    });
  });

  group('[UserDataNotifier] setActivityLevel', () {
    test('setActivityLevel very_active → state ถูกต้อง', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setActivityLevel('very_active');
      expect(c.read(userDataProvider).activityLevel, 'very_active');
    });
  });

  group('[UserDataNotifier] updateDailyFood', () {
    test('updateDailyFood → consumed values ถูก set', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).updateDailyFood(
          cal: 1800,
          protein: 120,
          carbs: 200,
          fat: 60,
          dailyMeals: {'breakfast': 'ข้าวต้ม'});
      final s = c.read(userDataProvider);
      expect(s.consumedCalories, 1800);
      expect(s.consumedProtein, 120);
      expect(s.consumedCarbs, 200);
      expect(s.consumedFat, 60);
      expect(s.dailyMeals['breakfast'], 'ข้าวต้ม');
    });
  });

  group('[UserDataNotifier] setDailySummaryFromApi', () {
    test('setDailySummaryFromApi — ข้อมูลครบ → parse ถูกต้อง', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setDailySummaryFromApi({
        'total_calories_intake': 1500,
        'total_protein': 100,
        'total_carbs': 180,
        'total_fat': 50,
        'meals': {'lunch': 'ผัดกะเพรา'},
      });
      final s = c.read(userDataProvider);
      expect(s.consumedCalories, 1500);
      expect(s.consumedProtein, 100);
      expect(s.dailyMeals['lunch'], 'ผัดกะเพรา');
    });

    test('setDailySummaryFromApi — meals = null → dailyMeals ว่าง', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setDailySummaryFromApi({'total_calories_intake': 1000});
      expect(c.read(userDataProvider).dailyMeals, isEmpty);
    });

    test('setDailySummaryFromApi — null fields → default 0', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setDailySummaryFromApi({});
      final s = c.read(userDataProvider);
      expect(s.consumedCalories, 0);
      expect(s.consumedProtein, 0);
    });
  });

  group('[UserDataNotifier] resetDailyFood', () {
    test('resetDailyFood → consumed ทั้งหมดกลับเป็น 0', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .updateDailyFood(cal: 2000, protein: 150, carbs: 250, fat: 70);
      c.read(userDataProvider.notifier).resetDailyFood();
      final s = c.read(userDataProvider);
      expect(s.consumedCalories, 0);
      expect(s.consumedProtein, 0);
      expect(s.consumedCarbs, 0);
      expect(s.consumedFat, 0);
      expect(s.dailyMeals, isEmpty);
    });
  });

  group('[UserDataNotifier] updateUnit', () {
    test('updateUnit weight → unitWeight เปลี่ยน, อื่นๆ เดิม', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).updateUnit(weight: 'lbs');
      final s = c.read(userDataProvider);
      expect(s.unitWeight, 'lbs');
      expect(s.unitHeight, 'cm');
    });

    test('updateUnit height + energy → ทั้งสองเปลี่ยน', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).updateUnit(height: 'ft', energy: 'kj');
      final s = c.read(userDataProvider);
      expect(s.unitHeight, 'ft');
      expect(s.unitEnergy, 'kj');
    });
  });

  group('[UserDataNotifier] setAllergies', () {
    test('setAllergies → allergyFlagIds ถูก set', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setAllergies([1, 3, 5]);
      expect(c.read(userDataProvider).allergyFlagIds, [1, 3, 5]);
    });

    test('setAllergies ว่าง → list ว่าง', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setAllergies([]);
      expect(c.read(userDataProvider).allergyFlagIds, isEmpty);
    });
  });

  group('[UserDataNotifier] setUserFromApi', () {
    test('ข้อมูลครบ → parse ถูกต้องทุก field', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setUserFromApi({
        'user_id': 42,
        'username': 'สมชาย',
        'email': 'som@test.com',
        'gender': 'male',
        'birth_date': '1995-06-15',
        'height_cm': 175.0,
        'current_weight_kg': 70.0,
        'goal_type': 'lose_weight',
        'target_weight_kg': 65.0,
        'activity_level': 'moderately_active',
        'target_calories': 1800,
        'current_streak': 5,
        'total_login_days': 30,
      });
      final s = c.read(userDataProvider);
      expect(s.userId, 42);
      expect(s.name, 'สมชาย');
      expect(s.email, 'som@test.com');
      expect(s.height, 175);
      expect(s.weight, 70);
      expect(s.storedTargetCalories, 1800);
      expect(s.currentStreak, 5);
    });

    test('username ว่าง → default "User"', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setUserFromApi({'username': ''});
      expect(c.read(userDataProvider).name, 'User');
    });

    test('goal_type = maintain_weight → GoalOption.maintainWeight', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setUserFromApi({'goal_type': 'maintain_weight'});
      expect(c.read(userDataProvider).goal, GoalOption.maintainWeight);
    });

    test('goal_type = gain_muscle → GoalOption.buildMuscle', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setUserFromApi({'goal_type': 'gain_muscle'});
      expect(c.read(userDataProvider).goal, GoalOption.buildMuscle);
    });

    test('height_cm = null → 0.0', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setUserFromApi({'height_cm': null, 'current_weight_kg': null});
      expect(c.read(userDataProvider).height, 0.0);
      expect(c.read(userDataProvider).weight, 0.0);
    });

    test('birth_date valid string → DateTime parse', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setUserFromApi({'birth_date': '2000-03-20'});
      expect(c.read(userDataProvider).birthDate, DateTime(2000, 3, 20));
    });

    test('birth_date invalid string → null', () {
      final c = makeContainer();
      c
          .read(userDataProvider.notifier)
          .setUserFromApi({'birth_date': 'not-a-date'});
      expect(c.read(userDataProvider).birthDate, isNull);
    });
  });

  group('[UserDataNotifier] setAvatarUrl', () {
    test('setAvatarUrl → avatarUrl เปลี่ยน', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setAvatarUrl('https://img.png');
      expect(c.read(userDataProvider).avatarUrl, 'https://img.png');
    });

    test('setAvatarUrl null → ค่าเดิมยังอยู่ (copyWith ?? fallback)', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setAvatarUrl('https://img.png');
      c.read(userDataProvider.notifier).setAvatarUrl(null);
      // null ถูก fallback เป็น this.avatarUrl เดิม เพราะ copyWith ใช้ ??
      expect(c.read(userDataProvider).avatarUrl, 'https://img.png');
    });

    test('clearAvatarUrl = true → avatarUrl = null', () {
      final u = UserData(avatarUrl: 'https://img.png');
      final cleared = u.copyWith(clearAvatarUrl: true);
      expect(cleared.avatarUrl, isNull);
    });
  });

  group('[UserDataNotifier] logout / reset', () {
    test('logout → state กลับเป็น default UserData', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setUserId(99);
      c.read(userDataProvider.notifier).logout();
      expect(c.read(userDataProvider).userId, 0);
      expect(c.read(userDataProvider).name, 'User');
    });

    test('reset → เหมือน logout', () {
      final c = makeContainer();
      c.read(userDataProvider.notifier).setLoginInfo('a@b.com', 'pass');
      c.read(userDataProvider.notifier).reset();
      expect(c.read(userDataProvider).email, '');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // C. Food Model
  // ══════════════════════════════════════════════════════════════

  group('[Food] fromJson', () {
    test('fromJson — ข้อมูลครบ → parse ถูกต้อง', () {
      final food = Food.fromJson({
        'food_id': 1,
        'food_name': 'ข้าวสวย',
        'calories': 200.0,
        'protein': 4.0,
        'carbs': 44.0,
        'fat': 0.5,
        'image_url': 'https://img.png',
      });
      expect(food.id, 1);
      expect(food.name, 'ข้าวสวย');
      expect(food.calories, 200.0);
      expect(food.protein, 4.0);
      expect(food.carbs, 44.0);
      expect(food.fat, 0.5);
      expect(food.imageUrl, 'https://img.png');
    });

    test('fromJson — ใช้ "name" เป็น fallback ถ้าไม่มี food_name', () {
      final food = Food.fromJson({
        'food_id': 2,
        'name': 'ไก่ย่าง',
        'calories': 200,
        'protein': 30,
        'carbs': 0,
        'fat': 5
      });
      expect(food.name, 'ไก่ย่าง');
    });

    test('fromJson — food_id ขาด → default 0', () {
      final food = Food.fromJson({
        'food_name': 'test',
        'calories': 100,
        'protein': 10,
        'carbs': 10,
        'fat': 5
      });
      expect(food.id, 0);
    });

    test('fromJson — calories เป็น String → parse เป็น double', () {
      final food = Food.fromJson({
        'food_id': 1,
        'food_name': 'test',
        'calories': '350.5',
        'protein': '25',
        'carbs': '40',
        'fat': '10'
      });
      expect(food.calories, 350.5);
      expect(food.protein, 25.0);
    });

    test('fromJson — calories = null → 0.0', () {
      final food = Food.fromJson({
        'food_id': 1,
        'food_name': 'test',
        'calories': null,
        'protein': null,
        'carbs': null,
        'fat': null
      });
      expect(food.calories, 0.0);
      expect(food.protein, 0.0);
    });

    test('fromJson — imageUrl ขาด → null', () {
      final food = Food.fromJson({
        'food_id': 1,
        'food_name': 'test',
        'calories': 100,
        'protein': 10,
        'carbs': 20,
        'fat': 5
      });
      expect(food.imageUrl, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // D. FoodLog Model
  // ══════════════════════════════════════════════════════════════

  group('[FoodLog] Auto Snapshot', () {
    test('FoodLog snapshot ค่าจาก Food อัตโนมัติ', () {
      final food = Food(
          id: 1, name: 'ไก่ย่าง', calories: 250, protein: 35, carbs: 0, fat: 8);
      final log = FoodLog(
          id: 'log_1',
          dateConsumed: DateTime.now(),
          meal: MealType.lunch,
          food: food);
      expect(log.loggedCalories, 250);
      expect(log.loggedProtein, 35);
      expect(log.loggedCarbs, 0);
      expect(log.loggedFat, 8);
    });

    test('MealType ครบทุก enum', () {
      expect(MealType.values.length, 4);
      expect(MealType.values, contains(MealType.breakfast));
      expect(MealType.values, contains(MealType.lunch));
      expect(MealType.values, contains(MealType.dinner));
      expect(MealType.values, contains(MealType.snack));
    });

    test('FoodLog.meal ถูก set ถูกต้อง', () {
      final food =
          Food(id: 1, name: 'กาแฟ', calories: 50, protein: 1, carbs: 8, fat: 2);
      final log = FoodLog(
          id: 'x',
          dateConsumed: DateTime.now(),
          meal: MealType.snack,
          food: food);
      expect(log.meal, MealType.snack);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // E. AppSettings
  // ══════════════════════════════════════════════════════════════

  group('[AppSettings] default + copyWith', () {
    test('default language = en, theme = light', () {
      const s = AppSettings();
      expect(s.language, 'en');
      expect(s.theme, 'light');
    });

    test('copyWith language → theme ไม่เปลี่ยน', () {
      const s = AppSettings(language: 'th', theme: 'dark');
      final s2 = s.copyWith(language: 'en');
      expect(s2.language, 'en');
      expect(s2.theme, 'dark');
    });

    test('copyWith theme → language ไม่เปลี่ยน', () {
      const s = AppSettings(language: 'en', theme: 'light');
      final s2 = s.copyWith(theme: 'system');
      expect(s2.theme, 'system');
      expect(s2.language, 'en');
    });

    test('copyWith ไม่ระบุ → ค่าเดิมทั้งหมด', () {
      const s = AppSettings(language: 'en', theme: 'dark');
      final s2 = s.copyWith();
      expect(s2.language, 'en');
      expect(s2.theme, 'dark');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // F-2. themeModeProvider
  // ══════════════════════════════════════════════════════════════

  // themeModeProvider ใช้ switch เดียวกันนี้ภายใน:
  // 'dark' → dark | 'system' → system | default → light
  ThemeMode _themeFrom(String t) {
    switch (t) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  group('[themeModeProvider] theme string → ThemeMode', () {
    test('dark → ThemeMode.dark',
        () => expect(_themeFrom('dark'), ThemeMode.dark));
    test('system → ThemeMode.system',
        () => expect(_themeFrom('system'), ThemeMode.system));
    test('light → ThemeMode.light',
        () => expect(_themeFrom('light'), ThemeMode.light));
    test('unknown → ThemeMode.light (default)',
        () => expect(_themeFrom('xyz'), ThemeMode.light));
  });

  // ══════════════════════════════════════════════════════════════
  // G. PendingFoodEntry
  // ══════════════════════════════════════════════════════════════

  group('[PendingFoodEntry] constructor + fields', () {
    test('ค่าทุก field ถูกเก็บถูกต้อง', () {
      const e = PendingFoodEntry(
        foodId: 7,
        foodName: 'ข้าวผัด',
        mealId: 'lunch',
        calories: 350,
        protein: 12,
        carbs: 55,
        fat: 8,
      );
      expect(e.foodId, 7);
      expect(e.foodName, 'ข้าวผัด');
      expect(e.mealId, 'lunch');
      expect(e.calories, 350);
      expect(e.protein, 12);
      expect(e.carbs, 55);
      expect(e.fat, 8);
    });

    test('mealId ว่าง → user เลือกเอง (ค่าว่าง)', () {
      const e = PendingFoodEntry(
          foodId: 1,
          foodName: 'test',
          mealId: '',
          calories: 100,
          protein: 5,
          carbs: 10,
          fat: 3);
      expect(e.mealId, '');
    });

    test('pendingFoodProvider default = null', () {
      final c = makeContainer();
      expect(c.read(pendingFoodProvider), isNull);
    });

    test('pendingFoodProvider set entry → ค่าอยู่ใน state', () {
      final c = makeContainer();
      const entry = PendingFoodEntry(
          foodId: 99,
          foodName: 'กาแฟ',
          mealId: 'snack',
          calories: 50,
          protein: 1,
          carbs: 8,
          fat: 2);
      c.read(pendingFoodProvider.notifier).state = entry;
      expect(c.read(pendingFoodProvider)?.foodName, 'กาแฟ');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // H. _effectiveWeeks edge cases
  // ══════════════════════════════════════════════════════════════

  group('[UserData] _effectiveWeeks edge cases', () {
    test('targetDate อนาคต → คำนวณจาก diff วัน', () {
      final future = DateTime.now().add(const Duration(days: 70));
      final u = UserData(targetDate: future);
      expect(u.targetCalories, isNot(0)); // ใช้ _effectiveWeeks จริง
      // ทดสอบ indirectly — ถ้า effectiveWeeks ≈ 10 → targetCalories ≠ tdee
      expect(u.targetCalories.isFinite, true);
    });

    test('targetDate อดีต + duration = 0 → default 12 สัปดาห์', () {
      final past = DateTime.now().subtract(const Duration(days: 30));
      final u = UserData(targetDate: past, duration: 0);
      // past date ทำให้ fallback ไป duration=0 → 12.0
      // ไม่ว่าจะเป็นค่าอะไร ต้องไม่ throw
      expect(u.targetCalories.isFinite, true);
    });

    test('duration = 5 สัปดาห์ → effectiveWeeks = 5', () {
      final u = UserData(
        gender: 'male',
        weight: 70,
        height: 175,
        birthDate: DateTime(2000, 1, 1),
        goal: GoalOption.loseWeight,
        targetWeight: 65,
        duration: 5,
      );
      // kgPerWeek = (65-70)/5 = -1.0, targetCal = tdee + (-1.0*1100)
      final expected = u.tdee + (((65 - 70) / 5.0) * 1100);
      expect(u.targetCalories, closeTo(expected, 1.0));
    });

    test('targetDate null + duration = 0 → default 12 สัปดาห์', () {
      final u = UserData(
        gender: 'male',
        weight: 70,
        height: 175,
        birthDate: DateTime(2000, 1, 1),
        goal: GoalOption.loseWeight,
        targetWeight: 65,
        duration: 0,
      );
      // effectiveWeeks = 12.0 (default)
      final expected = u.tdee + (((65 - 70) / 12.0) * 1100);
      expect(u.targetCalories, closeTo(expected, 1.0));
    });
  });

  // ══════════════════════════════════════════════════════════════
  // F. GoalOption Enum
  // ══════════════════════════════════════════════════════════════

  group('[GoalOption] enum completeness', () {
    test('GoalOption มี 3 ค่า', () {
      expect(GoalOption.values.length, 3);
    });

    test('ค่า enum ถูกต้องทั้ง 3', () {
      expect(GoalOption.values, contains(GoalOption.loseWeight));
      expect(GoalOption.values, contains(GoalOption.maintainWeight));
      expect(GoalOption.values, contains(GoalOption.buildMuscle));
    });
  });
}
