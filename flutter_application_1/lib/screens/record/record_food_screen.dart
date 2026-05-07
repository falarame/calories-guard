import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '/providers/user_data_provider.dart';
import '/providers/pending_food_provider.dart';
import '../../services/health_service.dart';
import '../../services/notification_helper.dart';
import '../../widget/ai_meal_estimate_sheet.dart';
import '../../services/error_reporter.dart';
import '../recommend_food/recipe_detail_screen.dart';

String _foodDisplayName(Map<String, dynamic> food) =>
    food['display_name']?.toString().trim().isNotEmpty == true
        ? food['display_name'].toString()
        : food['food_name']?.toString() ?? '';

// ─────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────
class LoggedFood {
  final String name;
  final double calories; // cal_per_unit
  final double protein; // protein_per_unit
  final double carbs; // carbs_per_unit
  final double fat; // fat_per_unit
  final double amount; // จำนวน (quantity)
  final int? unitId;
  final String unitName;
  final int? foodId;
  final bool isPending;
  // waterMl > 0 หมายความว่าอาหารนี้เป็นเครื่องดื่ม → นับรวมใน water tracker
  final double waterMl;

  LoggedFood({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.amount = 1.0,
    this.unitId,
    this.unitName = 'กรัม (g)',
    this.foodId,
    this.isPending = false,
    this.waterMl = 0,
  });

  double get totalCalories => calories * amount;
  double get totalProtein => protein * amount;
  double get totalCarbs => carbs * amount;
  double get totalFat => fat * amount;
  // ปริมาณน้ำรวมของรายการนี้ (ml)
  double get totalWaterMl => waterMl * amount;
}

class MealSlot {
  final String id;
  final String name;
  final String emoji;
  final String timeHint;
  List<LoggedFood> foods;
  MealSlot({
    required this.id,
    required this.name,
    required this.emoji,
    required this.timeHint,
    List<LoggedFood>? foods,
  }) : foods = foods ?? [];

  double get totalCalories => foods.fold(0, (s, f) => s + f.totalCalories);
  double get totalProtein => foods.fold(0, (s, f) => s + f.totalProtein);
  double get totalCarbs => foods.fold(0, (s, f) => s + f.totalCarbs);
  double get totalFat => foods.fold(0, (s, f) => s + f.totalFat);
}

class Activity {
  final String name;
  final String emoji;
  final int durationMin;
  final double caloriesBurned;
  Activity({
    required this.name,
    required this.emoji,
    required this.durationMin,
    required this.caloriesBurned,
  });
}

// ─────────────────────────────────────────────
//  FoodLogScreen
// ─────────────────────────────────────────────
class FoodLogScreen extends ConsumerStatefulWidget {
  const FoodLogScreen({super.key});

  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen>
    with TickerProviderStateMixin {
  static const _green = Color(0xFF628141);
  static const _greenL = Color(0xFFE8EFCF);
  static const _greenM = Color(0xFFAFD198);
  static const _orange = Color(0xFFD76A3C);
  static const _blue = Color(0xFF1565C0);
  static const _bg = Color(0xFFF2F7F4);
  static const _mealWriteTimeout = Duration(seconds: 90);
  static const _mealSummaryTimeout = Duration(seconds: 60);

  DateTime _selectedDate = DateTime.now();
  int _waterGlasses = 0;
  static const _waterGoal = 8;
  late List<MealSlot> _meals;
  final List<Activity> _activities = [];
  late AnimationController _waterAnim;
  bool _isSaving = false;
  bool _isLoadingData = false;
  Timer? _waterDebounce;
  final Set<String> _shownWaterSafetyKeys = {};

  @override
  void initState() {
    super.initState();
    _initMeals();
    _waterAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fetchDailyLog();
    _fetchWaterLog();
  }

  @override
  void dispose() {
    _waterAnim.dispose();
    _waterDebounce?.cancel();
    super.dispose();
  }

  void _initMeals() {
    _meals = [
      MealSlot(
          id: 'breakfast',
          name: 'มื้อเช้า',
          emoji: '🌅',
          timeHint: '06:00–10:00'),
      MealSlot(
          id: 'lunch',
          name: 'มื้อกลางวัน',
          emoji: '☀️',
          timeHint: '11:00–14:00'),
      MealSlot(
          id: 'dinner', name: 'มื้อเย็น', emoji: '🌙', timeHint: '17:00–21:00'),
      MealSlot(id: 'snack', name: 'ของว่าง', emoji: '🍎', timeHint: 'ตลอดวัน'),
    ];
  }

  // ─── Water Intake API ───────────────────────────────────────
  Future<void> _fetchWaterLog() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    if (mounted) setState(() => _waterGlasses = 0);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final res = await ApiClient().get(
        '/water_logs/$userId',
        queryParams: {'date_record': dateStr},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final ml = (data['amount_ml'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() => _waterGlasses = (ml / 250).round().clamp(0, 20));
        }
      }
    } catch (e, st) {
      ErrorReporter.report('record.fetch_water_log', e, st);
    }
  }

  void _debouncedSaveWater() {
    _waterDebounce?.cancel();
    _waterDebounce = Timer(const Duration(milliseconds: 600), _saveWaterLog);
  }

  Future<void> _saveWaterLog() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    try {
      final res = await ApiClient().post(
        '/water_logs/$userId',
        body: {
          'amount_ml': _waterGlasses * 250,
          'date_record': DateFormat('yyyy-MM-dd').format(_selectedDate),
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final safety =
            decoded is Map<String, dynamic> ? decoded['water_safety'] : null;
        if (safety is List && safety.isNotEmpty && mounted) {
          final warning = safety.whereType<Map>().map((item) {
            return item.map((key, value) => MapEntry(key.toString(), value));
          }).first;
          final code = warning['code']?.toString() ?? 'water_safety';
          final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final shownKey = '$dateKey:$code';
          if (_shownWaterSafetyKeys.add(shownKey)) {
            final title =
                warning['title']?.toString() ?? 'วันนี้น้ำยังไม่ถึงเป้า';
            final message = warning['message']?.toString() ??
                'ระบบพบว่าวันนี้คุณบันทึกน้ำต่ำกว่าเป้าหมาย';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$title\n$message'),
              backgroundColor: _blue,
              duration: const Duration(seconds: 5),
            ));
            NotificationHelper.showWaterSafetyWarning(title, message);
          }
        }
      }
    } catch (e, st) {
      ErrorReporter.report('record.save_water_log', e, st);
    }
  }

  Future<void> _fetchDailyLog() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    if (mounted) setState(() => _isLoadingData = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final res = await ApiClient().get(
        '/daily_logs/$userId',
        queryParams: {'date_query': dateStr},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // โหลดข้อมูลมื้ออาหาร
        if (data['meals'] != null) {
          final mealsData = data['meals'] as Map<String, dynamic>;

          setState(() {
            // Clear ข้อมูลเก่า
            for (var meal in _meals) {
              meal.foods.clear();
            }

            // โหลดข้อมูลแต่ละมื้อ
            for (var mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
              if (mealsData[mealType] != null && mealsData[mealType] is List) {
                final items = mealsData[mealType] as List;
                final targetMeal = _meals.firstWhere(
                  (m) => m.id == mealType,
                  orElse: () => _meals.last, // fallback to snack
                );

                for (var item in items) {
                  targetMeal.foods.add(LoggedFood(
                    name: item['food_name'] ?? '',
                    calories: (item['cal_per_unit'] ?? 0).toDouble(),
                    protein: (item['protein_per_unit'] ?? 0).toDouble(),
                    carbs: (item['carbs_per_unit'] ?? 0).toDouble(),
                    fat: (item['fat_per_unit'] ?? 0).toDouble(),
                    amount: (item['amount'] ?? 1.0).toDouble(),
                    unitId: item['unit_id'],
                    unitName: item['unit_name'] ?? 'กรัม (g)',
                    foodId: item['food_id'],
                    waterMl: (item['water_ml_per_serving'] ?? 0).toDouble(),
                  ));
                }
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching daily log: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
      _applyPendingFood();
    }
  }

  Future<void> _applyPendingFood() async {
    final pending = ref.read(pendingFoodProvider);
    if (pending == null) return;
    // consume it immediately so it won’t re-apply on the next load
    ref.read(pendingFoodProvider.notifier).state = null;

    // gap time (mealId == '') → let user pick manually
    if (pending.mealId.isEmpty) return;

    final meal = _meals.firstWhere(
      (m) => m.id == pending.mealId,
      orElse: () => _meals.first,
    );
    final food = LoggedFood(
      name: pending.foodName,
      calories: pending.calories,
      protein: pending.protein,
      carbs: pending.carbs,
      fat: pending.fat,
      foodId: pending.foodId,
    );
    if (mounted) setState(() => meal.foods.add(food));
    final saved = await _saveSingleMeal(meal);
    if (!saved && mounted) {
      setState(() => meal.foods.remove(food));
    }
  }

  double get _totalCalIn => _meals.fold(0, (s, m) => s + m.totalCalories);
  double get _totalCalBurned =>
      _activities.fold(0, (s, a) => s + a.caloriesBurned);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildTopBar(),
        if (_isLoadingData)
          const LinearProgressIndicator(
              color: _green, backgroundColor: Color(0xFFE8EFCF), minHeight: 3),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              _buildWaterTracker(),
              ..._meals
                  .asMap()
                  .entries
                  .map((e) => _buildMealCard(e.value, e.key)),
              _buildAddCustomMealBtn(),
              _buildActivitiesSection(),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 52, bottom: 14, left: 16, right: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dateNavBtn(Icons.chevron_left, () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _initMeals();
                _fetchDailyLog();
                _fetchWaterLog();
              });
            }),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme:
                              const ColorScheme.light(primary: _green)),
                      child: child!),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _initMeals();
                    _fetchDailyLog();
                    _fetchWaterLog();
                  });
                }
              },
              child: Column(children: [
                Text(_formatDateTh(_selectedDate),
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                Text(_isToday(_selectedDate) ? 'วันนี้' : '',
                    style: const TextStyle(fontSize: 11, color: _green)),
              ]),
            ),
            const SizedBox(width: 8),
            _dateNavBtn(
                Icons.chevron_right,
                _isToday(_selectedDate)
                    ? null
                    : () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.add(const Duration(days: 1));
                          _initMeals();
                          _fetchDailyLog();
                          _fetchWaterLog();
                        });
                      }),
          ],
        ),
      ),
    );
  }

  Widget _dateNavBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade200 : _greenL,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon,
            size: 18, color: onTap == null ? Colors.grey.shade400 : _green),
      ),
    );
  }

  Widget _buildWaterTracker() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _blue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Row(children: [
          const Text('💧', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ดื่มน้ำวันนี้',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Inter')),
            Text(
                '$_waterGlasses/$_waterGoal แก้ว (${(_waterGlasses * 250)} ml)',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const Spacer(),
          Row(children: [
            _waterBtn(Icons.remove, () {
              if (_waterGlasses > 0) {
                setState(() => _waterGlasses--);
                _debouncedSaveWater();
              }
            }),
            const SizedBox(width: 8),
            Text('$_waterGlasses',
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            _waterBtn(Icons.add, () {
              if (_waterGlasses < 20) {
                setState(() => _waterGlasses++);
                _debouncedSaveWater();
              }
            }),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(
            children: List.generate(
                _waterGoal,
                (i) => Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _waterGlasses = i + 1);
                          _debouncedSaveWater();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 28,
                          decoration: BoxDecoration(
                            color: i < _waterGlasses
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(i < _waterGlasses ? '💧' : '○',
                                style: TextStyle(
                                    fontSize: i < _waterGlasses ? 14 : 12,
                                    color: Colors.white70)),
                          ),
                        ),
                      ),
                    ))),
      ]),
    );
  }

  Widget _waterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildMealCard(MealSlot meal, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: _greenL, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text(meal.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal.name,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(meal.timeHint,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${meal.totalCalories.toInt()} kcal',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _green)),
              Text(
                  'P:${meal.totalProtein.toInt()}g  C:${meal.totalCarbs.toInt()}g  F:${meal.totalFat.toInt()}g',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ]),
        ),
        if (meal.foods.isNotEmpty) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...meal.foods
              .asMap()
              .entries
              .map((e) => _buildFoodItem(e.value, meal, e.key)),
        ],
        const Divider(height: 1, indent: 16, endIndent: 16),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showAddFoodSheet(meal),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: _greenL, shape: BoxShape.circle),
                    child: const Icon(Icons.add, size: 16, color: _green),
                  ),
                  const SizedBox(width: 8),
                  Text('เพิ่มอาหาร${meal.name.replaceAll('มื้อ', '')}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _green,
                          fontFamily: 'Inter')),
                ]),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade200),
          GestureDetector(
            onTap: () => _showAiEstimateSheet(meal),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: const Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: _green),
                SizedBox(width: 6),
                Text('AI',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green,
                        fontFamily: 'Inter')),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showAiEstimateSheet(MealSlot meal) {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    final mealType = ['breakfast', 'lunch', 'dinner', 'snack'].contains(meal.id)
        ? meal.id
        : 'snack';
    showAiMealEstimateSheet(
      context: context,
      userId: userId,
      mealType: mealType,
      date: _selectedDate,
      onSaved: () {
        ref.read(homeViewDateProvider.notifier).state = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        ref.read(dailyFoodRevisionProvider.notifier).state++;
        _fetchDailyLog();
      },
    );
  }

  Widget _buildFoodItem(LoggedFood food, MealSlot meal, int index) {
    final canOpenRecipe =
        food.foodId != null && food.foodId != 0 && !food.isPending;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: food.isPending ? _orange : _greenM,
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpenRecipe
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(foodId: food.foodId!),
                    ),
                  )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(food.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (food.isPending) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(99)),
                    child: const Text('รอตรวจสอบ',
                        style: TextStyle(
                            fontSize: 9,
                            color: _orange,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                if (food.waterMl > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('💧${food.totalWaterMl.toInt()}ml',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              Text(
                  '${food.amount % 1 == 0 ? food.amount.toInt() : food.amount} ${food.unitName}  •  '
                  'P:${food.totalProtein.toInt()}g  C:${food.totalCarbs.toInt()}g  F:${food.totalFat.toInt()}g',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        )),
        Text('${food.totalCalories.toInt()} kcal',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _green,
                fontFamily: 'Inter')),
        const SizedBox(width: 8),
        Tooltip(
          message:
              canOpenRecipe ? 'เปิดวิธีการทำ' : 'ยังไม่มีวิธีทำสำหรับรายการนี้',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: canOpenRecipe
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RecipeDetailScreen(foodId: food.foodId!),
                      ),
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: canOpenRecipe
                    ? const Color(0xFFE8EFCF)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_outlined,
                    size: 14,
                    color: canOpenRecipe ? _green : Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(
                  'วิธีทำ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: canOpenRecipe ? _green : Colors.grey.shade400,
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final removedFood = meal.foods[index];
            setState(() => meal.foods.removeAt(index));
            // บันทึกทันทีหลังลบ
            final saved = await _saveSingleMeal(meal);
            if (!saved && mounted) {
              setState(() => meal.foods.insert(index, removedFood));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
          ),
        ),
      ]),
    );
  }

  Widget _buildAddCustomMealBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: _showAddCustomMealDialog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _greenM, style: BorderStyle.solid),
          ),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, color: _green, size: 20),
            SizedBox(width: 8),
            Text('เพิ่มมื้ออาหารเอง',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                    fontFamily: 'Inter')),
          ]),
        ),
      ),
    );
  }

  void _showAddCustomMealDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('เพิ่มมื้ออาหาร',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'เช่น มื้อดึก, ก่อนนอน',
            filled: true,
            fillColor: _greenL,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _meals.add(MealSlot(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: ctrl.text.trim(),
                    emoji: '🍴',
                    timeHint: 'มื้อเพิ่มเติม')));
                Navigator.pop(ctx);
              }
            },
            child: const Text('เพิ่ม', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: const Text('🏃', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('กิจกรรมวันนี้',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text('เผาผลาญรวม ${_totalCalBurned.toInt()} kcal',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ]),
        ),
        if (_activities.isNotEmpty) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          ..._activities.asMap().entries.map((e) {
            final a = e.value;
            return Dismissible(
              key: Key('act_${e.key}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade50,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              onDismissed: (_) => setState(() => _activities.removeAt(e.key)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Text(a.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${a.durationMin} นาที',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  )),
                  Text('-${a.caloriesBurned.toInt()} kcal',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _orange,
                          fontFamily: 'Inter')),
                ]),
              ),
            );
          }),
        ],
        const Divider(height: 1, indent: 16, endIndent: 16),
        // ── Add manually ────────────────────────────────────────
        GestureDetector(
          onTap: _showAddActivitySheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0), shape: BoxShape.circle),
                child: const Icon(Icons.add, size: 16, color: _orange),
              ),
              const SizedBox(width: 8),
              const Text('เพิ่มกิจกรรม',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _orange,
                      fontFamily: 'Inter')),
            ]),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        // ── Samsung Health Sync ──────────────────────────────────
        GestureDetector(
          onTap: _isSyncingHealth ? null : _syncSamsungHealth,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: _isSyncingHealth
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1565C0)),
                    ),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE3F0FF), shape: BoxShape.circle),
                      child: const Icon(Icons.watch_rounded,
                          size: 14, color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(width: 8),
                    const Text('ซิงค์ Samsung Health',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                            fontFamily: 'Inter')),
                  ]),
          ),
        ),
      ]),
    );
  }

  void _showAddFoodSheet(MealSlot meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddFoodSheet(
        meal: meal,
        onFoodAdded: (food) async {
          setState(() => meal.foods.add(food));
          // ถ้าเป็นเครื่องดื่ม → นับน้ำเพิ่มอัตโนมัติ
          if (food.waterMl > 0) {
            final addedMl = food.totalWaterMl;
            final currentMl = _waterGlasses * 250;
            final newMl = currentMl + addedMl;
            final newGlasses = (newMl / 250).round().clamp(0, 20);
            setState(() => _waterGlasses = newGlasses);
            _debouncedSaveWater();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('💧 เพิ่มน้ำ ${addedMl.toInt()} ml จากเครื่องดื่มนี้ '
                        '(รวม ${newMl.toInt()} ml วันนี้)'),
                backgroundColor: const Color(0xFF1565C0),
                duration: const Duration(seconds: 3),
              ));
            }
          }
          // Auto-save ทันทีเมื่อเพิ่มอาหาร
          final saved = await _saveSingleMeal(meal);
          if (!saved && mounted) {
            setState(() => meal.foods.remove(food));
          }
          return saved;
        },
      ),
    );
  }

  // ─── Samsung Health Sync ──────────────────────────────────────────────────
  bool _isSyncingHealth = false;

  Future<void> _syncSamsungHealth() async {
    setState(() => _isSyncingHealth = true);
    try {
      final readiness = await HealthService.ensureReady();
      if (!mounted) return;

      switch (readiness) {
        case HealthReadiness.unsupported:
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'อุปกรณ์นี้ไม่รองรับ Health Connect — ซิงค์ Samsung Health ไม่ได้'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ));
          return;
        case HealthReadiness.needsInstall:
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'ยังไม่ได้ติดตั้ง Health Connect — แตะปุ่มติดตั้งเพื่อดาวน์โหลด'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'ติดตั้ง',
              textColor: Colors.white,
              onPressed: HealthService.openHealthConnectInstall,
            ),
          ));
          return;
        case HealthReadiness.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่ได้รับสิทธิ์อ่านข้อมูลสุขภาพ\n'
                'เปิดแอป Health Connect → Apps → Calories Guard → อนุญาตการอ่านทั้งหมด'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ));
          return;
        case HealthReadiness.ok:
          break;
      }

      final summary = await HealthService.fetchActivitySummary(_selectedDate);
      final calories = summary.caloriesBurned;
      final steps = summary.steps;
      if (!mounted) return;

      if (calories > 0 || steps > 0) {
        final act = Activity(
          name: 'Samsung Health — กิจกรรมรวม',
          emoji: '⌚',
          durationMin: 0,
          caloriesBurned: calories,
        );
        setState(() {
          _activities.removeWhere((a) => a.name.startsWith('Samsung Health'));
          if (calories > 0) _activities.add(act);
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            summary.usesTotalCaloriesFallback
                ? 'ซิงค์สำเร็จ! เผาผลาญ ${calories.toInt()} kcal | ก้าว $steps ก้าว\n'
                    'ใช้ข้อมูลพลังงานจาก Samsung Health ผ่าน Health Connect'
                : 'ซิงค์สำเร็จ! เผาผลาญ ${calories.toInt()} kcal | ก้าว $steps ก้าว',
          ),
          backgroundColor: const Color(0xFF628141),
          duration:
              Duration(seconds: summary.usesTotalCaloriesFallback ? 5 : 3),
        ));
      } else {
        // Permissions are fine but no data — typically means Samsung Health
        // hasn't been linked to Health Connect yet.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ไม่พบข้อมูลกิจกรรมในวันนี้\n'
              'เปิด Samsung Health → ตั้งค่า → Health Connect และเปิดการซิงค์'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
          action: SnackBarAction(
            label: 'ติดตั้ง Samsung Health',
            textColor: Colors.white,
            onPressed: HealthService.openSamsungHealthInstall,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  void _showAddActivitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddActivitySheet(
        onActivityAdded: (act) => setState(() => _activities.add(act)),
      ),
    );
  }

  bool _isHttpSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  String _apiErrorMessage(dynamic response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['message'];
        if (detail != null) return detail.toString();
      }
    } catch (_) {
      // Fall back to the status code below.
    }
    return 'HTTP ${response.statusCode}';
  }

  Future<void> _syncProviderFromServerSummary({
    required int userId,
    required String dateStr,
    String? expectedMealType,
    List<LoggedFood> expectedFoods = const [],
  }) async {
    final summaryRes = await ApiClient().get(
      '/daily_summary/$userId',
      queryParams: {'date_record': dateStr},
      timeout: _mealSummaryTimeout,
    );
    if (!_isHttpSuccess(summaryRes.statusCode)) {
      throw Exception('โหลดข้อมูลที่บันทึกจากฐานข้อมูลไม่สำเร็จ: '
          '${_apiErrorMessage(summaryRes)}');
    }

    final summaryData = jsonDecode(utf8.decode(summaryRes.bodyBytes));
    if (summaryData is! Map<String, dynamic>) {
      throw Exception('รูปแบบข้อมูลสรุปจากฐานข้อมูลไม่ถูกต้อง');
    }
    if (expectedMealType != null && expectedFoods.isNotEmpty) {
      final meals = summaryData['meals'];
      final syncedMeal =
          meals is Map ? meals[expectedMealType]?.toString() ?? '' : '';
      final expectedNames = expectedFoods.map((f) => f.name.trim()).where(
            (name) => name.isNotEmpty,
          );
      final hasExpectedNames = expectedNames.every(syncedMeal.contains);
      if (!hasExpectedNames) {
        throw Exception('บันทึกแล้วแต่ฐานข้อมูลยังไม่คืนข้อมูลมื้อนี้ '
            'กรุณาลองใหม่อีกครั้ง');
      }
    }
    ref.read(userDataProvider.notifier).setDailySummaryFromApi(summaryData);
  }

  void _publishLocalDailySummary() {
    final mealsMap = <String, String>{};
    var totalCalories = 0.0;
    var totalProtein = 0.0;
    var totalCarbs = 0.0;
    var totalFat = 0.0;

    for (final meal in _meals) {
      final foods = meal.foods.where((food) => food.name.trim().isNotEmpty);
      if (foods.isEmpty) continue;
      mealsMap[meal.id] = foods.map((food) => food.name.trim()).join(', ');
      totalCalories += foods.fold(0.0, (sum, food) => sum + food.calories);
      totalProtein += foods.fold(0.0, (sum, food) => sum + food.protein);
      totalCarbs += foods.fold(0.0, (sum, food) => sum + food.carbs);
      totalFat += foods.fold(0.0, (sum, food) => sum + food.fat);
    }

    ref.read(userDataProvider.notifier).updateDailyFood(
          cal: totalCalories.round(),
          protein: totalProtein.round(),
          carbs: totalCarbs.round(),
          fat: totalFat.round(),
          dailyMeals: mealsMap,
        );
  }

  Future<bool> _saveSingleMeal(MealSlot meal) async {
    // ป้องกันการบันทึกซ้ำซ้อน
    if (_isSaving) {
      debugPrint('⚠️ BLOCKED: Already saving, skipping...');
      return false;
    }

    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return false;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    debugPrint('🔵 START SAVE: ${meal.id} with ${meal.foods.length} items');
    for (var f in meal.foods) {
      debugPrint('  - ${f.name}: ${f.calories} kcal');
    }

    try {
      final mealType =
          ['breakfast', 'lunch', 'dinner', 'snack'].contains(meal.id)
              ? meal.id
              : 'snack';
      final nutritionSafetyWarnings = <Map<String, dynamic>>[];

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Backend replaces this meal atomically when items are present.
      // Empty meals still call clear because there is nothing to POST.
      if (meal.foods.isNotEmpty) {
        final items = meal.foods
            .map((f) => {
                  'food_id': f.foodId,
                  'food_name': f.name,
                  'amount': f.amount,
                  'unit_id': f.unitId,
                  'cal_per_unit': f.calories,
                  'protein_per_unit': f.protein,
                  'carbs_per_unit': f.carbs,
                  'fat_per_unit': f.fat,
                })
            .toList();

        debugPrint('💾 POST: ${items.length} items');
        final postRes = await ApiClient().post(
          '/meals/$userId',
          body: {
            'date': dateStr,
            'meal_type': mealType,
            'items': items,
          },
          timeout: _mealWriteTimeout,
        );
        debugPrint('💾 POST Response: ${postRes.statusCode}');
        if (!_isHttpSuccess(postRes.statusCode)) {
          throw Exception('บันทึกอาหารลงฐานข้อมูลไม่สำเร็จ: '
              '${_apiErrorMessage(postRes)}');
        }

        final decoded = jsonDecode(utf8.decode(postRes.bodyBytes));
        final safety = decoded is Map<String, dynamic>
            ? decoded['nutrition_safety']
            : null;
        if (safety is List) {
          nutritionSafetyWarnings.addAll(
            safety.whereType<Map>().map((item) {
              return item.map(
                (key, value) => MapEntry(key.toString(), value),
              );
            }),
          );
        }
      } else {
        debugPrint(
            '🗑️ DELETE: /meals/clear/$userId?date_record=$dateStr&meal_type=$mealType');
        final delRes = await ApiClient().delete(
          '/meals/clear/$userId?date_record=$dateStr&meal_type=$mealType',
          timeout: _mealWriteTimeout,
        );
        debugPrint('🗑️ DELETE Response: ${delRes.statusCode}');
        if (!_isHttpSuccess(delRes.statusCode)) {
          throw Exception(
              'ลบข้อมูลมื้อเดิมไม่สำเร็จ: ${_apiErrorMessage(delRes)}');
        }
      }
      debugPrint('✅ SAVE COMPLETE');

      // ── Sync provider ทันทีหลัง save เพื่อให้ home screen อัปเดตเลย ──────
      if (mounted) {
        var syncedFromServer = true;
        try {
          await _syncProviderFromServerSummary(
            userId: userId,
            dateStr: dateStr,
            expectedMealType: mealType,
            expectedFoods: meal.foods,
          );
        } on TimeoutException catch (e) {
          syncedFromServer = false;
          debugPrint('⚠️ Summary sync timed out after save: $e');
          _publishLocalDailySummary();
        } catch (e) {
          syncedFromServer = false;
          debugPrint('⚠️ Summary sync failed after save: $e');
          _publishLocalDailySummary();
        }
        ref.read(homeViewDateProvider.notifier).state = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        ref.read(dailyFoodRevisionProvider.notifier).state++;
        messenger.showSnackBar(SnackBar(
          content: Text(syncedFromServer
              ? 'บันทึกอาหารและซิงค์หน้าหลักแล้ว'
              : 'บันทึกอาหารแล้ว แต่โหลดข้อมูลจากฐานข้อมูลช้า '
                  'หน้าหลักจะแสดงข้อมูลล่าสุดชั่วคราว'),
          backgroundColor: _green,
          duration: const Duration(seconds: 3),
        ));
      }

      // ── Calorie notification trigger ──────────────────────
      final targetCalDouble = ref.read(userDataProvider).targetCalories;
      final targetCal = targetCalDouble.toInt();
      final currentCal = _totalCalIn.toInt();
      if (targetCal > 0) {
        if (currentCal >= targetCal) {
          NotificationHelper.showCalorieAlert(currentCal, targetCal);
        } else if (currentCal >= (targetCalDouble * 0.85).toInt()) {
          NotificationHelper.showCalorieWarning(currentCal, targetCal);
        }
      }

      if (mounted && nutritionSafetyWarnings.isNotEmpty) {
        final warning = nutritionSafetyWarnings.firstWhere(
          (item) => item['severity'] == 'danger',
          orElse: () => nutritionSafetyWarnings.first,
        );
        final title =
            warning['title']?.toString() ?? 'แคลอรี่วันนี้เสี่ยงเกินไป';
        final message = warning['message']?.toString() ??
            'ระบบพบความเสี่ยงจากแคลอรี่ที่บันทึกวันนี้';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title\n$message'),
          backgroundColor: warning['severity'] == 'danger'
              ? Colors.redAccent
              : const Color(0xFFB7791F),
          duration: const Duration(seconds: 6),
        ));
        NotificationHelper.showNutritionSafetyWarning(title, message);
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error saving meal: $e');
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('บันทึกอาหารไม่สำเร็จ\n$e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatDateTh(DateTime d) {
    final months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year + 543}';
  }
}

// ═══════════════════════════════════════════════════════════
//  _AddFoodSheet — Bottom sheet สำหรับเพิ่มอาหาร
//  มี 2 tab: เลือกจาก DB | บันทึกด่วน
// ═══════════════════════════════════════════════════════════
class _AddFoodSheet extends ConsumerStatefulWidget {
  final MealSlot meal;
  final Future<bool> Function(LoggedFood) onFoodAdded;
  const _AddFoodSheet({required this.meal, required this.onFoodAdded});

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF628141);
  static const _greenL = Color(0xFFE8EFCF);

  List<Map<String, dynamic>> _dbResults = [];
  bool _dbLoading = false;
  bool _showQuickAdd = false; // แสดง quick-add เมื่อค้นหาไม่เจอและกดปุ่ม
  bool _isAddingFood = false;
  final _searchCtrl = TextEditingController();

  final _qNameCtrl = TextEditingController();
  final _qCalCtrl = TextEditingController();
  final _qProtCtrl = TextEditingController();
  final _qCarbCtrl = TextEditingController();
  final _qFatCtrl = TextEditingController();
  bool _qSending = false;

  @override
  void initState() {
    super.initState();
    _loadAllFoods();
    _loadUnits();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qNameCtrl.dispose();
    _qCalCtrl.dispose();
    _qProtCtrl.dispose();
    _qCarbCtrl.dispose();
    _qFatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      await ApiClient().get('/units');
      // units data no longer stored (field removed)
    } catch (e, st) {
      ErrorReporter.report('record.load_units', e, st);
    }
  }

  void _showFoodDetail(Map<String, dynamic> food) {
    final foodName = _foodDisplayName(food);
    final allergic = _isAllergic(food);
    final cal = (food['calories'] as num? ?? 0).toDouble();
    final protein = (food['protein'] as num? ?? 0).toDouble();
    final carbs = (food['carbs'] as num? ?? 0).toDouble();
    final fat = (food['fat'] as num? ?? 0).toDouble();
    final servingQty = (food['serving_quantity'] as num? ?? 100).toDouble();
    final servingUnit = food['serving_unit'] as String? ?? 'g';
    final imageUrl = food['image_url'] as String? ?? '';
    final isBeverage = food['food_type']?.toString() == 'beverage';
    // สำหรับเครื่องดื่ม: serving_quantity (g ≈ ml) คือปริมาณน้ำต่อ 1 serving
    final waterMlPerServing = isBeverage ? servingQty : 0.0;
    int amount = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            // รูปอาหาร
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            const SizedBox(height: 14),
            // ชื่ออาหาร + badge แพ้
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(foodName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              if (allergic)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(99)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 13, color: Color(0xFFE67E22)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text('มีส่วนผสมหรือวัตถุดิบที่คุณแพ้',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE67E22),
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('ต่อ ${servingQty.toInt()} $servingUnit',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            const SizedBox(height: 16),
            // ตารางโภชนาการ (ปรับตาม amount)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF7FBF2),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                _nutriCol('พลังงาน', '${(cal * amount).toInt()}', 'kcal',
                    const Color(0xFF628141)),
                _divider(),
                _nutriCol('โปรตีน', (protein * amount).toStringAsFixed(1), 'g',
                    const Color(0xFF2563EB)),
                _divider(),
                _nutriCol('คาร์บ', (carbs * amount).toStringAsFixed(1), 'g',
                    const Color(0xFFD97706)),
                _divider(),
                _nutriCol('ไขมัน', (fat * amount).toStringAsFixed(1), 'g',
                    const Color(0xFFDC2626)),
              ]),
            ),
            // แสดง water info เมื่อเป็นเครื่องดื่ม
            if (isBeverage) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Text('💧', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เครื่องดื่มนี้จะนับเป็นน้ำ '
                      '${(waterMlPerServing * amount).toInt()} ml '
                      '(≈ ${(waterMlPerServing * amount / 250).toStringAsFixed(1)} แก้ว)',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            // ── ปุ่ม - จำนวน + และปุ่มเพิ่ม ──
            Row(children: [
              // ปุ่ม -
              _qtyBtn(Icons.remove, () {
                if (amount > 1) setS(() => amount--);
              }),
              const SizedBox(width: 12),
              // จำนวน + หน่วย
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7FBF2),
                      borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$amount',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Inter')),
                      Text(servingUnit,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ปุ่ม +
              _qtyBtn(Icons.add, () => setS(() => amount++)),
              const SizedBox(width: 16),
              // ปุ่มเพิ่มในมื้ออาหาร
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          allergic ? const Color(0xFFE67E22) : _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isAddingFood
                        ? null
                        : () async {
                            setState(() => _isAddingFood = true);
                            final saved = await widget.onFoodAdded(LoggedFood(
                              name: foodName,
                              calories: cal,
                              protein: protein,
                              carbs: carbs,
                              fat: fat,
                              amount: amount.toDouble(),
                              unitName: 'serving',
                              foodId: food['food_id'] as int?,
                              waterMl: waterMlPerServing,
                            ));
                            if (!mounted) return;
                            setState(() => _isAddingFood = false);
                            if (!saved) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: _isAddingFood
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('เพิ่ม',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: const Color(0xFFE8EFCF),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _green, size: 22),
        ),
      );

  Widget _nutriCol(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter')),
        Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Future<void> _loadAllFoods() async {
    setState(() => _dbLoading = true);
    try {
      final userId = ref.read(userDataProvider).userId;
      final res = await ApiClient().get(
        '/foods',
        queryParams: userId > 0 ? {'user_id': '$userId'} : null,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() => _dbResults = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถโหลดรายการอาหารได้ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _dbLoading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchCtrl.text.isEmpty) return _dbResults;
    final q = _searchCtrl.text.toLowerCase();
    return _dbResults
        .where((f) =>
            (f['food_name']?.toString().toLowerCase() ?? '').contains(q) ||
            (f['display_name']?.toString().toLowerCase() ?? '').contains(q) ||
            (f['regional_name']?.toString().toLowerCase() ?? '').contains(q))
        .toList();
  }

  /// เช็คว่า food นี้มี allergen ที่ user แพ้หรือไม่
  bool _isAllergic(Map<String, dynamic> food) {
    final userAllergies = ref.read(userDataProvider).allergyFlagIds;
    if (userAllergies.isEmpty) return false;
    final foodFlags =
        (food['allergy_flag_ids'] as List?)?.map((e) => e as int).toList() ??
            [];
    return foodFlags.any((id) => userAllergies.contains(id));
  }

  /// แสดง dialog เตือนก่อน → ถ้ายืนยันค่อยเปิด amount/unit dialog
  void _handleFoodTap(Map<String, dynamic> food) {
    if (_isAllergic(food)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE67E22), size: 26),
            SizedBox(width: 8),
            Text('ที่ส่วนผสมหรือวัตถุดิบที่คุณแพ้!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '"${_foodDisplayName(food)}" มีส่วนประกอบที่คุณแจ้งว่าแพ้',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'การรับประทานอาหารนี้อาจทำให้เกิดอาการแพ้ได้',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFE67E22)),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showFoodDetail(food);
              },
              child: const Text('เพิ่มต่อไป',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _showFoodDetail(food);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Column(children: [
        const SizedBox(height: 8),
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('เพิ่มอาหาร — ${widget.meal.name}',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: _showQuickAdd ? _buildQuickAddTab() : _buildDBTab(scroll),
        ),
      ]),
    );
  }

  Widget _buildDBTab(ScrollController scroll) {
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    final isEmpty = _filtered.isEmpty;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {
                _showQuickAdd = false;
              }),
              decoration: InputDecoration(
                hintText: 'ค้นหาเมนูอาหาร...',
                prefixIcon: const Icon(Icons.search, color: _green),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _showQuickAdd = false;
                          });
                        })
                    : null,
                filled: true,
                fillColor: _greenL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Always-visible shortcut to the quick-add form, so users can
          // create a new meal entry without having to type a bogus search first.
          Tooltip(
            message: 'สร้างเมนูใหม่',
            child: InkWell(
              onTap: () {
                _qNameCtrl.text = _searchCtrl.text.trim();
                setState(() => _showQuickAdd = true);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _dbLoading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : (isEmpty && hasQuery)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่พบ "${_searchCtrl.text.trim()}" ในฐานข้อมูล',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _qNameCtrl.text = _searchCtrl.text.trim();
                              setState(() => _showQuickAdd = true);
                            },
                            icon:
                                const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('เพิ่มเมนูอาหารด่วน',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  )
                : isEmpty
                    ? const Center(
                        child: Text('ยังไม่มีรายการอาหาร',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final f = _filtered[i];
                          final allergic = _isAllergic(f);
                          return ListTile(
                            onTap: () => _showFoodDetail(f),
                            contentPadding: EdgeInsets.zero,
                            leading: Stack(clipBehavior: Clip.none, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: (f['image_url'] != null &&
                                            (f['image_url'] as String)
                                                .isNotEmpty)
                                        ? Image.network(f['image_url'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(
                                                        Icons.restaurant,
                                                        size: 24)))
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.restaurant,
                                                size: 24))),
                              ),
                              if (allergic)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFE67E22),
                                        shape: BoxShape.circle),
                                    child: const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 12,
                                        color: Colors.white),
                                  ),
                                ),
                            ]),
                            title: Row(children: [
                              Expanded(
                                child: Text(_foodDisplayName(f),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              // badge ภาษาท้องถิ่น
                              if ((f['regional_name'] as String?)?.isNotEmpty ==
                                  true)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(99)),
                                  child: const Text('ท้องถิ่น',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF388E3C),
                                          fontWeight: FontWeight.w700)),
                                ),
                              // badge เครื่องดื่ม
                              if (f['food_type']?.toString() == 'beverage')
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(99)),
                                  child: const Text('💧 เครื่องดื่ม',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.w700)),
                                ),
                              if (allergic)
                                Flexible(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius:
                                            BorderRadius.circular(99)),
                                    child: const Text(
                                        'มีส่วนผสมหรือวัตถุดิบที่คุณแพ้',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFFE67E22),
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                            ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    '${f['calories']?.toStringAsFixed(0) ?? 0} kcal  •  '
                                    'P:${f['protein']?.toStringAsFixed(0) ?? 0}g  '
                                    'C:${f['carbs']?.toStringAsFixed(0) ?? 0}g  '
                                    'F:${f['fat']?.toStringAsFixed(0) ?? 0}g',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                                // แสดงชื่อท้องถิ่นเป็น hint เมื่อ display_name ต่างจาก food_name
                                if ((f['regional_name'] as String?)
                                            ?.isNotEmpty ==
                                        true &&
                                    f['regional_name'] != f['food_name'])
                                  Text(
                                    'ชื่อสามัญ: ${f['food_name'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                        fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () => _handleFoodTap(f),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: allergic
                                        ? const Color(0xFFE67E22)
                                        : _green,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    ]);
  }

  Widget _buildQuickAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ปุ่มย้อนกลับ
        GestureDetector(
          onTap: () => setState(() => _showQuickAdd = false),
          child: const Row(children: [
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: Color(0xFF628141)),
            SizedBox(width: 4),
            Text('กลับไปค้นหา',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF628141),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Text('ℹ️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    'กรอกข้อมูลเมนูที่ไม่มีในระบบ จะถูกส่งให้ Admin ตรวจสอบ '
                    'และเพิ่มลงฐานข้อมูลในภายหลัง',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),
        _qLabel('ชื่อเมนู *'),
        _qField(_qNameCtrl, 'เช่น ข้าวผัดปู, ลาบหมู'),
        const SizedBox(height: 12),
        _qLabel('แคลอรี่ (kcal)'),
        _qField(_qCalCtrl, '0 (ไม่บังคับ)', isNumber: true),
        const SizedBox(height: 12),
        _qLabel('ข้อมูลโภชนาการ (กรัม) — ไม่บังคับ'),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _qLabel('โปรตีน'),
                _qField(_qProtCtrl, '0', isNumber: true)
              ])),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _qLabel('คาร์โบไฮเดรต'),
                _qField(_qCarbCtrl, '0', isNumber: true)
              ])),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _qLabel('ไขมัน'),
                _qField(_qFatCtrl, '0', isNumber: true)
              ])),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _qSending ? null : _quickAddAndSubmit,
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _qSending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('เพิ่ม + ส่งให้ Admin',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  Widget _qLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)));

  Widget _qField(TextEditingController ctrl, String hint,
      {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : [],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: _greenL,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  bool _validateQuick() {
    if (_qNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อเมนู')));
      return false;
    }
    return true;
  }

  Future<void> _quickAddAndSubmit() async {
    if (!_validateQuick()) return;
    setState(() => _qSending = true);

    final food = LoggedFood(
      name: _qNameCtrl.text.trim(),
      calories: double.tryParse(_qCalCtrl.text) ?? 0,
      protein: double.tryParse(_qProtCtrl.text) ?? 0,
      carbs: double.tryParse(_qCarbCtrl.text) ?? 0,
      fat: double.tryParse(_qFatCtrl.text) ?? 0,
      isPending: true,
    );

    try {
      final userData = ref.read(userDataProvider);
      final userId = userData.userId;

      final res = await ApiClient().post(
        '/foods/auto-add',
        body: {
          'user_id': userId,
          'food_name': food.name,
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
        },
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to submit: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
      setState(() => _qSending = false);
      return;
    }

    final saved = await widget.onFoodAdded(food);
    setState(() => _qSending = false);
    if (mounted && saved) Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════════
//  _AddActivitySheet — Bottom sheet สำหรับเพิ่มกิจกรรม
// ═══════════════════════════════════════════════════════════
class _AddActivitySheet extends StatefulWidget {
  final void Function(Activity) onActivityAdded;
  const _AddActivitySheet({required this.onActivityAdded});

  @override
  State<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<_AddActivitySheet> {
  static const _orange = Color(0xFFD76A3C);
  static const _orangeL = Color(0xFFFFF3E0);
  static const _green = Color(0xFF628141);
  static const _greenL = Color(0xFFE8EFCF);

  static const _presets = [
    {'name': 'เดิน', 'emoji': '🚶', 'met': 3.5},
    {'name': 'วิ่ง', 'emoji': '🏃', 'met': 9.8},
    {'name': 'ปั่นจักรยาน', 'emoji': '🚴', 'met': 7.5},
    {'name': 'ว่ายน้ำ', 'emoji': '🏊', 'met': 8.0},
    {'name': 'เต้น Zumba', 'emoji': '💃', 'met': 6.0},
    {'name': 'โยคะ', 'emoji': '🧘', 'met': 3.0},
    {'name': 'ยกน้ำหนัก', 'emoji': '🏋️', 'met': 5.0},
    {'name': 'ฟุตบอล', 'emoji': '⚽', 'met': 7.0},
    {'name': 'บาสเกตบอล', 'emoji': '🏀', 'met': 6.5},
    {'name': 'กระโดดเชือก', 'emoji': '🪢', 'met': 11.0},
    {'name': 'HIIT', 'emoji': '🔥', 'met': 12.0},
    {'name': 'เดินขึ้นบันได', 'emoji': '🪜', 'met': 4.0},
  ];

  Map<String, dynamic>? _selectedPreset;
  int _duration = 30;
  double _userWeight = 65;
  final _customNameCtrl = TextEditingController();
  bool _isCustom = false;
  double _customMET = 4.0;

  double get _caloriesBurned {
    final met =
        _isCustom ? _customMET : (_selectedPreset?['met'] as double? ?? 4.0);
    return met * _userWeight * (_duration / 60);
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 16),
          Row(children: [
            const Text('🏃 เพิ่มกิจกรรม',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFD76A3C), Color(0xFFE85D04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('คาดว่าจะเผาผลาญ',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('${_caloriesBurned.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('น้ำหนัก $_userWeight kg',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('$_duration นาที',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('เลือกกิจกรรม',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presets.map((p) {
                final isSelected =
                    !_isCustom && _selectedPreset?['name'] == p['name'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedPreset = p;
                    _isCustom = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: isSelected ? _orange : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isSelected ? _orange : Colors.grey.shade300)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(p['emoji'] as String,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(p['name'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.black87)),
                    ]),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => setState(() => _isCustom = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: _isCustom ? _green : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _isCustom ? _green : Colors.grey.shade300)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('✏️',
                        style: TextStyle(
                            fontSize: 16,
                            color: _isCustom ? Colors.white : Colors.black)),
                    const SizedBox(width: 6),
                    Text('กำหนดเอง',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isCustom ? Colors.white : Colors.black87)),
                  ]),
                ),
              ),
            ],
          ),
          if (_isCustom) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customNameCtrl,
              decoration: InputDecoration(
                hintText: 'ชื่อกิจกรรม',
                filled: true,
                fillColor: _greenL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('MET Value:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                  child: Slider(
                      value: _customMET,
                      min: 1,
                      max: 15,
                      divisions: 28,
                      activeColor: _green,
                      onChanged: (v) => setState(() => _customMET = v))),
              Text(_customMET.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            Text(
                'MET ต่ำ = เบา (เดิน~3.5), กลาง = ปานกลาง, สูง = หนัก (วิ่ง~10)',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            const Text('ระยะเวลา',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _orangeL, borderRadius: BorderRadius.circular(99)),
              child: Text('$_duration นาที',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                      fontFamily: 'Inter')),
            ),
          ]),
          Slider(
              value: _duration.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              activeColor: _orange,
              onChanged: (v) => setState(() => _duration = v.round())),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('5 นาที',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            Text('180 นาที',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('น้ำหนัก (สำหรับคำนวณ)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$_userWeight kg',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          Slider(
              value: _userWeight,
              min: 30,
              max: 150,
              divisions: 120,
              activeColor: _green,
              onChanged: (v) => setState(() => _userWeight = v)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_selectedPreset == null && !_isCustom)
                  ? null
                  : () {
                      final name = _isCustom
                          ? _customNameCtrl.text.trim().isEmpty
                              ? 'กิจกรรมที่กำหนดเอง'
                              : _customNameCtrl.text.trim()
                          : _selectedPreset!['name'] as String;
                      final emoji = _isCustom
                          ? '🏋️'
                          : _selectedPreset!['emoji'] as String;

                      widget.onActivityAdded(Activity(
                        name: name,
                        emoji: emoji,
                        durationMin: _duration,
                        caloriesBurned: _caloriesBurned,
                      ));
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: Text(
                  'บันทึกกิจกรรม (${_caloriesBurned.toStringAsFixed(0)} kcal)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
