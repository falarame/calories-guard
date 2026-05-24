import 'dart:math' show max;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// รายการอาหารต่อมื้อสำหรับหน้า Home (จาก /daily_summary meal_items)
class HomeLoggedFoodItem {
  final String foodName;
  final String imageUrl;
  final double totalCal;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const HomeLoggedFoodItem({
    required this.foodName,
    this.imageUrl = '',
    this.totalCal = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
  });

  static HomeLoggedFoodItem? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return HomeLoggedFoodItem(
      foodName: m['food_name']?.toString() ?? '',
      imageUrl: m['image_url']?.toString() ?? '',
      totalCal: (m['total_cal'] as num?)?.toDouble() ?? 0,
      totalProtein: (m['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (m['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (m['total_fat'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, List<HomeLoggedFoodItem>> parseMealItemsMap(dynamic raw) {
    final out = <String, List<HomeLoggedFoodItem>>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final k = key.toString();
      if (value is! List) return;
      final list = <HomeLoggedFoodItem>[];
      for (final e in value) {
        final item = tryParse(e);
        if (item != null && item.foodName.trim().isNotEmpty) list.add(item);
      }
      if (list.isNotEmpty) out[k] = list;
    });
    return out;
  }
}

// Enum สำหรับเป้าหมาย
enum GoalOption {
  loseWeight,
  maintainWeight,
  buildMuscle,
}

class UserData {
  // --- 1. ส่วนข้อมูลพื้นฐาน (Login & Profile) ---
  final int userId;
  final String email;
  final String name;
  final String gender;
  final DateTime? birthDate;
  final double height;
  final double weight;

  // --- 2. ส่วนเป้าหมาย (Goal) ---
  final GoalOption? goal;
  final double targetWeight;
  final int duration;
  final String activityLevel;
  final DateTime? targetDate;

  // --- 3. ส่วนข้อมูลโภชนาการรายวัน (Nutrition) ---
  final int consumedCalories;
  final int consumedProtein;
  final int consumedCarbs;
  final int consumedFat;

  /// แคลที่เผาผลาญจากกิจกรรมวันนั้น (จาก /daily_summary total_calories_burned)
  final int dailyCaloriesBurned;

  // --- 4. ส่วนชื่อเมนูอาหาร (Food Menu Names) ---
  final Map<String, String> dailyMeals;

  /// รายการอาหารต่อมื้อ (ชื่อ, รูป, แคล/แมโครต่อมื้อ) จาก API meal_items
  final Map<String, List<HomeLoggedFoodItem>> dailyMealItems;

  // --- 4b. จาก DB: target_calories, target_protein/carbs/fat, streak, total_login ---
  final int? storedTargetCalories;
  final int? storedTargetProtein;
  final int? storedTargetCarbs;
  final int? storedTargetFat;
  final int currentStreak;
  final int totalLoginDays;

  // --- Weekly tier system ---
  final int weeklyXp;
  final String weeklyXpWeek; // YYYY-WW
  final int? weeklyRank;

  // --- 5. หน่วยนับ (Unit) ---
  final String unitWeight;
  final String unitHeight;
  final String unitEnergy;
  final String unitWater;

  // --- 6. การแพ้อาหาร (Allergies) ---
  final List<int> allergyFlagIds;

  // --- 7. Avatar ---
  final String? avatarUrl;

  UserData({
    this.userId = 0,
    this.email = '',
    this.name = 'User',
    this.gender = 'male',
    this.birthDate,
    this.height = 0.0,
    this.weight = 0.0,
    this.goal,
    this.targetWeight = 0.0,
    this.duration = 0,
    this.activityLevel = 'sedentary',
    this.targetDate,
    this.consumedCalories = 0,
    this.consumedProtein = 0,
    this.consumedCarbs = 0,
    this.consumedFat = 0,
    this.dailyCaloriesBurned = 0,
    this.dailyMeals = const {},
    this.dailyMealItems = const {},
    this.storedTargetCalories,
    this.storedTargetProtein,
    this.storedTargetCarbs,
    this.storedTargetFat,
    this.currentStreak = 0,
    this.totalLoginDays = 0,
    this.weeklyXp = 0,
    this.weeklyXpWeek = '',
    this.weeklyRank,
    this.unitWeight = 'kg',
    this.unitHeight = 'cm',
    this.unitEnergy = 'kcal',
    this.unitWater = 'ml',
    this.allergyFlagIds = const [],
    this.avatarUrl,
  });

  // --- 🧮 Logic 1: คำนวณอายุ ---
  int get age {
    if (birthDate == null) return 20;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  // --- BMI: weight(kg) / height(m)^2 ---
  double get bmi {
    if (weight <= 0 || height <= 0) return 0;
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  // --- BMR (Mifflin-St Jeor): Male = (10w)+(6.25h)-(5a)+5 | Female = (10w)+(6.25h)-(5a)-161 ---
  // Asian correction ×0.94 — Huang KC et al., Obesity Research 2004
  static const _asianBmrFactor = 0.94;
  double get bmr {
    if (weight <= 0 || height <= 0) return 1500;
    final base = (10 * weight) + (6.25 * height) - (5 * age);
    final raw = gender == 'male' ? base + 5 : base - 161;
    return raw * _asianBmrFactor;
  }

  // --- TDEE: BMR * ActivityFactor (1.2, 1.375, 1.55, 1.725, 1.9) ---
  double get tdee {
    double factor = 1.2;
    switch (activityLevel) {
      case 'lightly_active':
        factor = 1.375;
        break;
      case 'moderately_active':
        factor = 1.55;
        break;
      case 'very_active':
        factor = 1.725;
        break;
      case 'extra_active':
        factor = 1.9;
        break;
      default:
        factor = 1.2;
    }
    return bmr * factor;
  }

  // --- Daily Target: TDEE + (kg_per_week * (7700/7)) = TDEE + (kg_per_week * 1100) ---
  // ใช้จาก DB (storedTargetCalories) ถ้ามี ไม่ใช่คำนวณจากสูตร
  bool get hasBackendTargetCalories =>
      storedTargetCalories != null && storedTargetCalories! > 0;

  bool get hasBackendTargetMacros =>
      storedTargetProtein != null &&
      storedTargetProtein! > 0 &&
      storedTargetCarbs != null &&
      storedTargetCarbs! > 0 &&
      storedTargetFat != null &&
      storedTargetFat! > 0;

  /// แหล่งที่มาของเป้าแคล — ไม่ผูกกับแมโคร (เป้ากรัมยังเป็น “ประมาณ” ได้แยกต่างหากบนการ์ด P/C/F)
  String get targetCaloriesSourceLabel =>
      hasBackendTargetCalories ? 'คำนวณจากระบบ' : 'คำนวณจากสูตรในเครื่อง';

  double get targetCalories {
    if (hasBackendTargetCalories) {
      return storedTargetCalories!.toDouble();
    }
    double kgPerWeek = 0;
    if (goal == GoalOption.loseWeight) {
      kgPerWeek = -0.5;
    } else if (goal == GoalOption.buildMuscle) {
      kgPerWeek = 0.5;
    }
    final numWeeks = _effectiveWeeks;
    if (numWeeks > 0 && targetWeight > 0 && weight > 0) {
      kgPerWeek = (targetWeight - weight) / numWeeks;
    }
    return tdee + (kgPerWeek * 1100);
  }

  double get _effectiveWeeks {
    if (targetDate != null) {
      final now = DateTime.now();
      final end = targetDate!;
      if (end.isAfter(now)) return end.difference(now).inDays / 7.0;
    }
    return duration > 0 ? duration.toDouble() : 12.0;
  }

  // เป้าหมายแมโคร: ใช้จาก DB ถ้ามี ไม่ใช่คำนวณจากอัตราส่วนตาม goal
  // lose_weight:    Protein 30%, Carbs 40%, Fat 30%
  // maintain_weight: Protein 25%, Carbs 45%, Fat 30%
  // gain_muscle:    Protein 30%, Carbs 50%, Fat 20%
  double get _proteinRatio {
    if (goal == GoalOption.maintainWeight) return 0.25;
    return 0.30;
  }

  double get _carbsRatio {
    if (goal == GoalOption.loseWeight) return 0.40;
    if (goal == GoalOption.buildMuscle) return 0.50;
    return 0.45;
  }

  double get _fatRatio {
    if (goal == GoalOption.buildMuscle) return 0.20;
    return 0.30;
  }

  int get targetProtein {
    if (storedTargetProtein != null && storedTargetProtein! > 0) {
      return storedTargetProtein!;
    }
    return (targetCalories * _proteinRatio / 4).round();
  }

  int get targetCarbs {
    if (storedTargetCarbs != null && storedTargetCarbs! > 0) {
      return storedTargetCarbs!;
    }
    return (targetCalories * _carbsRatio / 4).round();
  }

  int get targetFat {
    if (storedTargetFat != null && storedTargetFat! > 0) {
      return storedTargetFat!;
    }
    return (targetCalories * _fatRatio / 9).round();
  }

  /// แคลสุทธิสำหรับเป้า/วงแหวน: max(0, กิน − เผา)
  int get netCaloriesIntake =>
      max(0, consumedCalories - dailyCaloriesBurned);

  /// แคลสุทธิ signed: กิน − เผา (อนุญาตค่าติดลบ — สำหรับแสดงผล)
  int get netCaloriesSigned => consumedCalories - dailyCaloriesBurned;

  // --- CopyWith ---
  UserData copyWith({
    int? userId,
    String? email,
    String? name,
    String? gender,
    DateTime? birthDate,
    double? height,
    double? weight,
    GoalOption? goal,
    double? targetWeight,
    DateTime? targetDate,
    int? duration,
    String? activityLevel,
    int? consumedCalories,
    int? consumedProtein,
    int? consumedCarbs,
    int? consumedFat,
    int? dailyCaloriesBurned,
    Map<String, String>? dailyMeals,
    Map<String, List<HomeLoggedFoodItem>>? dailyMealItems,
    int? storedTargetCalories,
    int? storedTargetProtein,
    int? storedTargetCarbs,
    int? storedTargetFat,
    int? currentStreak,
    int? totalLoginDays,
    int? weeklyXp,
    String? weeklyXpWeek,
    int? weeklyRank,
    String? unitWeight,
    String? unitHeight,
    String? unitEnergy,
    String? unitWater,
    List<int>? allergyFlagIds,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return UserData(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goal: goal ?? this.goal,
      targetWeight: targetWeight ?? this.targetWeight,
      targetDate: targetDate ?? this.targetDate,
      duration: duration ?? this.duration,
      activityLevel: activityLevel ?? this.activityLevel,
      consumedCalories: consumedCalories ?? this.consumedCalories,
      consumedProtein: consumedProtein ?? this.consumedProtein,
      consumedCarbs: consumedCarbs ?? this.consumedCarbs,
      consumedFat: consumedFat ?? this.consumedFat,
      dailyCaloriesBurned: dailyCaloriesBurned ?? this.dailyCaloriesBurned,
      dailyMeals: dailyMeals ?? this.dailyMeals,
      dailyMealItems: dailyMealItems ?? this.dailyMealItems,
      storedTargetCalories: storedTargetCalories ?? this.storedTargetCalories,
      storedTargetProtein: storedTargetProtein ?? this.storedTargetProtein,
      storedTargetCarbs: storedTargetCarbs ?? this.storedTargetCarbs,
      storedTargetFat: storedTargetFat ?? this.storedTargetFat,
      currentStreak: currentStreak ?? this.currentStreak,
      totalLoginDays: totalLoginDays ?? this.totalLoginDays,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      weeklyXpWeek: weeklyXpWeek ?? this.weeklyXpWeek,
      weeklyRank: weeklyRank ?? this.weeklyRank,
      unitWeight: unitWeight ?? this.unitWeight,
      unitHeight: unitHeight ?? this.unitHeight,
      unitEnergy: unitEnergy ?? this.unitEnergy,
      unitWater: unitWater ?? this.unitWater,
      allergyFlagIds: allergyFlagIds ?? this.allergyFlagIds,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}

// --- Notifier ---
class UserDataNotifier extends StateNotifier<UserData> {
  UserDataNotifier() : super(UserData());

  void logout() {
    state = UserData();
  }

  void setUserId(int id) {
    state = state.copyWith(userId: id);
  }

  void setLoginInfo(String email) {
    state = state.copyWith(email: email);
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void setPersonalInfo({
    required String name,
    required DateTime birthDate,
    required double height,
    required double weight,
  }) {
    state = state.copyWith(
      name: name,
      birthDate: birthDate,
      height: height,
      weight: weight,
    );
  }

  void setGoal(GoalOption goal) {
    state = state.copyWith(goal: goal);
  }

  void setGoalInfo({
    required double targetWeight,
    DateTime? targetDate,
    int? duration,
  }) {
    state = state.copyWith(
      targetWeight: targetWeight,
      targetDate: targetDate,
      duration: duration ?? state.duration,
    );
  }

  void setActivityLevel(String level) {
    state = state.copyWith(activityLevel: level);
  }

  // ✅ อัปเดตข้อมูลอาหารรายวัน (Manual) แบบรับ Map
  void updateDailyFood({
    required int cal,
    required int protein,
    required int carbs,
    required int fat,
    // รับเป็น Map แทนที่จะเป็น String แยก
    Map<String, String>? dailyMeals,
    Map<String, List<HomeLoggedFoodItem>>? dailyMealItems,
  }) {
    state = state.copyWith(
      consumedCalories: cal,
      consumedProtein: protein,
      consumedCarbs: carbs,
      consumedFat: fat,
      dailyMeals: dailyMeals ?? state.dailyMeals, // ✅ บันทึก Map
      dailyMealItems: dailyMealItems ?? state.dailyMealItems,
    );
  }

  // ✅ รับค่าจาก API /daily_summary มาใส่ Provider
  void setDailySummaryFromApi(Map<String, dynamic> data) {
    // แปลงข้อมูลจาก API ('meals': {...}) มาเป็น Map<String, String>
    Map<String, String> meals = {};
    final rawMeals = data['meals'];
    if (rawMeals is Map) {
      meals = rawMeals.map(
        (k, v) =>
            MapEntry(k.toString().trim().toLowerCase(), v?.toString() ?? ''),
      );
    }

    dynamic mealItemsRaw = data['meal_items'];
    if (mealItemsRaw is Map) {
      mealItemsRaw = {
        for (final e in mealItemsRaw.entries)
          e.key.toString().trim().toLowerCase(): e.value
      };
    }

    final mealItems = HomeLoggedFoodItem.parseMealItemsMap(mealItemsRaw);

    state = state.copyWith(
      consumedCalories: (data['total_calories_intake'] as num?)?.toInt() ?? 0,
      consumedProtein: (data['total_protein'] as num?)?.toInt() ?? 0,
      consumedCarbs: (data['total_carbs'] as num?)?.toInt() ?? 0,
      consumedFat: (data['total_fat'] as num?)?.toInt() ?? 0,
      dailyCaloriesBurned:
          (data['total_calories_burned'] as num?)?.round() ?? 0,
      dailyMeals: meals,
      dailyMealItems: mealItems,
    );
  }

  void resetDailyFood() {
    state = state.copyWith(
      consumedCalories: 0,
      consumedProtein: 0,
      consumedCarbs: 0,
      consumedFat: 0,
      dailyCaloriesBurned: 0,
      dailyMeals: {}, // ✅ Reset เป็น Map ว่าง
      dailyMealItems: {},
    );
  }

  void updateUnit(
      {String? weight, String? height, String? energy, String? water}) {
    state = state.copyWith(
      unitWeight: weight ?? state.unitWeight,
      unitHeight: height ?? state.unitHeight,
      unitEnergy: energy ?? state.unitEnergy,
      unitWater: water ?? state.unitWater,
    );
  }

  void setAllergies(List<int> flagIds) {
    state = state.copyWith(allergyFlagIds: flagIds);
  }

  void setUserFromApi(Map<String, dynamic> data) {
    DateTime? tDate;
    if (data['goal_target_date'] != null) {
      tDate = DateTime.tryParse(data['goal_target_date'].toString());
    }
    DateTime? bDate;
    if (data['birth_date'] != null) {
      bDate = DateTime.tryParse(data['birth_date'].toString());
    }

    GoalOption userGoal = GoalOption.loseWeight;
    if (data['goal_type'] == 'maintain_weight') {
      userGoal = GoalOption.maintainWeight;
    }
    if (data['goal_type'] == 'gain_muscle') userGoal = GoalOption.buildMuscle;

    // Null-safe: ใช้ ?? และ default เพื่อไม่ให้เป็น null ที่แสดงผล
    final heightVal = (data['height_cm'] as num?)?.toDouble();
    final weightVal = (data['current_weight_kg'] as num?)?.toDouble();
    state = state.copyWith(
      userId: (data['user_id'] as num?)?.toInt() ?? 0,
      name: ((data['username']?.toString() ?? '').trim().isEmpty)
          ? 'User'
          : (data['username']?.toString() ?? 'User'),
      email: data['email']?.toString() ?? '',
      gender: data['gender']?.toString() ?? 'male',
      birthDate: bDate,
      height: (heightVal != null && heightVal > 0) ? heightVal : 0.0,
      weight: (weightVal != null && weightVal > 0) ? weightVal : 0.0,
      targetWeight: (data['target_weight_kg'] as num?)?.toDouble() ?? 0.0,
      targetDate: tDate,
      goal: userGoal,
      activityLevel: data['activity_level']?.toString() ?? 'sedentary',
      storedTargetCalories: (data['target_calories'] as num?)?.toInt(),
      storedTargetProtein: (data['target_protein'] as num?)?.toInt(),
      storedTargetCarbs: (data['target_carbs'] as num?)?.toInt(),
      storedTargetFat: (data['target_fat'] as num?)?.toInt(),
      currentStreak: (data['current_streak'] as num?)?.toInt() ?? 0,
      totalLoginDays: (data['total_login_days'] as num?)?.toInt() ?? 0,
      weeklyXp: (data['weekly_xp'] as num?)?.toInt() ?? 0,
      weeklyXpWeek: data['weekly_xp_week']?.toString() ?? '',
      weeklyRank: (data['weekly_rank'] as num?)?.toInt(),
      unitWeight: data['unit_weight']?.toString() ?? state.unitWeight,
      unitHeight: data['unit_height']?.toString() ?? state.unitHeight,
      unitEnergy: data['unit_energy']?.toString() ?? state.unitEnergy,
      unitWater: data['unit_water']?.toString() ?? state.unitWater,
      avatarUrl: data['avatar_url']?.toString(),
    );
  }

  void setAvatarUrl(String? url) {
    state = state.copyWith(avatarUrl: url);
  }

  void setCurrentWeight(double weightKg) {
    state = state.copyWith(weight: weightKg);
  }

  void reset() {
    state = UserData();
  }
}

final userDataProvider =
    StateNotifierProvider<UserDataNotifier, UserData>((ref) {
  return UserDataNotifier();
});
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Macro filter that the home screen can pre-select when navigating to the
/// recommend-food tab. 'protein' | 'carbs' | 'fat' | null (= no filter).
final macroFilterProvider = StateProvider<String?>((ref) => null);

/// วันที่ที่หน้า Home แสดง (null = วันนี้). หลังบันทึกอาหารย้อนหลังจะเซ็ตเป็นวันนั้นเพื่อให้กลับมาโชว์วันนั้น
final homeViewDateProvider = StateProvider<DateTime?>((ref) => null);

/// Incremented after meal data is persisted so Home can refresh from backend
/// even when it is kept alive inside the IndexedStack.
final dailyFoodRevisionProvider = StateProvider<int>((ref) => 0);
