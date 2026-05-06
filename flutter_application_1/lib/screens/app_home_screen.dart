import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import 'dart:convert';
import '/screens/profile/subprofile_screen/progress_screen.dart';
import '../../services/api_client.dart';
import '../../services/notification_helper.dart';
import '../../services/lifecycle_service.dart';
import '../../services/error_reporter.dart';
import '../../utils/bmi_utils.dart';
import '/screens/macro/macro_detail_screen.dart';
import '/screens/restaurant_map_screen.dart';
import '/screens/bmi/bmi_detail_screen.dart';
import '/screens/tamagotchi/tamagotchi_screen.dart';
import '/screens/weight/weight_chart_screen.dart';

class AppHomeScreen extends ConsumerStatefulWidget {
  const AppHomeScreen({super.key});

  @override
  ConsumerState<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends ConsumerState<AppHomeScreen> {
  static const _green = Color(0xFF628141);
  static const _greenDark = Color(0xFF3D5A27);
  static const _greenLight = Color(0xFFE8EFCF);
  static const _bg = Color(0xFFF5F7F0);

  bool _isLoading = true;
  bool _hasError = false;
  bool _hasWarnedCalories = false;
  late DateTime _viewDate;

  @override
  void initState() {
    super.initState();
    _viewDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncViewDateFromProvider();
      _fetchAllData();
      ref.listenManual(navIndexProvider, (prev, next) {
        if (next == 0 && prev != 0) {
          _syncViewDateFromProvider();
          _fetchDailyData(_viewDate);
        }
      });
    });
  }

  void _syncViewDateFromProvider() {
    final fromProvider = ref.read(homeViewDateProvider);
    if (fromProvider != null) {
      ref.read(homeViewDateProvider.notifier).state = null;
      setState(() => _viewDate =
          DateTime(fromProvider.year, fromProvider.month, fromProvider.day));
    }
  }

  // ─── Data Fetching ────────────────────────────────────────────────────────

  Future<void> _fetchAllData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      await _fetchUserData();
      await _fetchDailyData(_viewDate);
      // Lifecycle checks (2-week weight / birthday / monthly) — silent, ไม่บล็อก UI
      final userId = ref.read(userDataProvider).userId;
      LifecycleService.runChecks(userId);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserData() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;

    try {
      final response = await ApiClient().get('/users/$userId');
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ref.read(userDataProvider.notifier).setUserFromApi(data);
      }
    } catch (e, st) {
      ErrorReporter.report('home.fetch_user_profile', e, st);
    }

    try {
      final res = await ApiClient().get('/users/$userId/allergies');
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        final ids = (d['flag_ids'] as List).cast<int>();
        ref.read(userDataProvider.notifier).setAllergies(ids);
      }
    } catch (e, st) {
      ErrorReporter.report('home.fetch_allergies', e, st);
    }
  }

  Future<void> _fetchDailyData(DateTime forDate) async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;

    final dateStr =
        "${forDate.year}-${forDate.month.toString().padLeft(2, '0')}-${forDate.day.toString().padLeft(2, '0')}";

    try {
      final response = await ApiClient().get(
        '/daily_summary/$userId',
        queryParams: {'date_record': dateStr},
      );
      if (response.statusCode == 200) {
        final summaryData = json.decode(utf8.decode(response.bodyBytes));
        Map<String, String> mealsMap = {};
        if (summaryData['meals'] != null) {
          mealsMap = Map<String, String>.from(summaryData['meals']);
        }
        ref.read(userDataProvider.notifier).updateDailyFood(
              cal: (summaryData['total_calories_intake'] as num?)?.toInt() ?? 0,
              protein: (summaryData['total_protein'] as num?)?.toInt() ?? 0,
              carbs: (summaryData['total_carbs'] as num?)?.toInt() ?? 0,
              fat: (summaryData['total_fat'] as num?)?.toInt() ?? 0,
              dailyMeals: mealsMap,
            );
      }
    } catch (e) {
      debugPrint("Error fetching daily summary: $e");
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _showBmiRangePopup(BuildContext context, double currentBmi) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.speed_rounded, size: 18, color: Color(0xFF628141)),
              SizedBox(width: 8),
              Text('เกณฑ์ BMI (สำหรับชาวเอเชีย)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            ...bmiBands.map((r) {
              final isMe = r.contains(currentBmi);
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isMe
                      ? r.color.withValues(alpha: 0.12)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: isMe ? Border.all(color: r.color, width: 1.5) : null,
                ),
                child: Row(children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: r.color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(r.range,
                      style: TextStyle(
                          fontSize: 12,
                          color: isMe ? r.color : Colors.black87,
                          fontWeight:
                              isMe ? FontWeight.bold : FontWeight.normal)),
                  const Spacer(),
                  Text(r.label,
                      style: TextStyle(
                          fontSize: 11,
                          color: isMe ? r.color : Colors.grey.shade600,
                          fontWeight:
                              isMe ? FontWeight.w600 : FontWeight.normal)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_left_rounded, color: r.color, size: 16)
                  ],
                ]),
              );
            }),
            if (currentBmi > 0) ...[
              const Divider(height: 16),
              Text('BMI ของคุณ: ${currentBmi.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            ],
          ]),
        ),
      ),
    );
  }

  String getBMIStatus(double bmi) => bmiStatusLabel(bmi);

  String _formatMealLabel(String key) {
    switch (key) {
      case 'breakfast':
        return 'มื้อเช้า';
      case 'lunch':
        return 'มื้อเที่ยง';
      case 'dinner':
        return 'มื้อเย็น';
      case 'snack':
        return 'อาหารว่าง';
    }
    if (key.startsWith('meal_')) {
      var num = key.split('_').length > 1 ? key.split('_')[1] : '?';
      return 'มื้อที่ $num';
    }
    return key;
  }

  IconData _mealIcon(String key) {
    switch (key) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.light_mode_outlined;
      case 'dinner':
        return Icons.nightlight_outlined;
      case 'snack':
        return Icons.local_cafe_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  List<String> _getSortedMealKeys(Map<String, String> meals) {
    const order = ['breakfast', 'lunch', 'dinner', 'snack'];
    var keys = meals.keys.toList();
    keys.sort((a, b) {
      int ia = order.indexOf(a);
      int ib = order.indexOf(b);
      if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
      if (ia >= 0) return -1;
      if (ib >= 0) return 1;
      return a.compareTo(b);
    });
    return keys;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _getAdvice(int currentCal, int targetCal, bool isOver) {
    if (currentCal == 0) return "เริ่มบันทึกมื้อแรกของวันกันเลย!";
    if (isOver) return "พลังงานเกินเป้าหมาย ลองเดินย่อยดูนะ";
    final pct = currentCal / targetCal;
    if (pct >= 0.9) return "ใกล้ถึงเป้าแล้ว มื้อหน้าเลือกทานเบาๆ นะ";
    if (pct >= 0.5) return "กำลังดี! รักษาวินัยต่อไปได้เลย";
    return "วันนี้ยังเหลืออีกเยอะ ทานให้ครบนะ";
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    // ✅ FIX: Re-fetch when user navigates back to home tab from record screen
    ref.listen<int>(navIndexProvider, (prev, next) {
      if (next == 0 && prev != 0 && mounted) {
        _fetchDailyData(_viewDate);
      }
    });

    ref.listen<DateTime?>(homeViewDateProvider, (prev, next) {
      if (next != null && mounted) {
        ref.read(homeViewDateProvider.notifier).state = null;
        setState(() => _viewDate = DateTime(next.year, next.month, next.day));
        _fetchDailyData(_viewDate).then((_) {
          if (mounted) setState(() {});
        });
      }
    });

    final int targetCal = userData.targetCalories.toInt() > 0
        ? userData.targetCalories.toInt()
        : 1500;
    final int currentCal = userData.consumedCalories;
    final double progress =
        (targetCal > 0) ? (currentCal / targetCal).clamp(0.0, 1.0) : 0.0;
    final bool isOver = currentCal > targetCal;

    if (isOver && !_hasWarnedCalories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ แจ้งเตือน: แคลอรี่เกินเป้าหมายแล้ว!'),
            backgroundColor: Colors.redAccent));
        NotificationHelper.showCalorieAlert(currentCal, targetCal);
        setState(() => _hasWarnedCalories = true);
      });
    }

    final double bmi = userData.bmi;
    final String bmiStatus = getBMIStatus(bmi);

    // ── Refresh อัตโนมัติเมื่อ user กลับมา Home tab (index 0) ───────────────
    ref.listen<int>(navIndexProvider, (prev, next) {
      if (next == 0 && prev != null && prev != 0) {
        _fetchAllData(); // ดึงข้อมูลใหม่โดยใช้ _viewDate เดิม (ไม่ reset วันที่)
      }
    });

    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _hasError
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 56, color: Color(0xFFBDBDBD)),
                    const SizedBox(height: 12),
                    const Text('ไม่สามารถโหลดข้อมูลได้',
                        style: TextStyle(fontSize: 15, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchAllData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('ลองใหม่'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAllData,
                  color: _green,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(),
                        const SizedBox(height: 16),
                        _buildCalorieCard(
                            currentCal, targetCal, progress, isOver, userData),
                        const SizedBox(height: 12),
                        _buildMacroRow(userData),
                        const SizedBox(height: 12),
                        _buildWeightBMIRow(userData, bmi, bmiStatus),
                        const SizedBox(height: 16),
                        _buildRestaurantButton(targetCal - currentCal),
                        const SizedBox(height: 12),
                        _buildTamagotchiBanner(),
                        const SizedBox(height: 12),
                        _buildMealsSection(userData),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Date Header ──────────────────────────────────────────────────────────

  Widget _buildDateHeader() {
    final isToday = _isToday(_viewDate);
    final thaiMonths = [
      '',
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
    final dateLabel =
        '${_viewDate.day} ${thaiMonths[_viewDate.month]} ${_viewDate.year + 543}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'วันนี้' : 'ดูข้อมูลย้อนหลัง',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
        ),
        // Date picker button
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _viewDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: _green, onPrimary: Colors.white),
                ),
                child: child!,
              ),
            );
            if (picked != null && mounted) {
              setState(() {
                _viewDate = DateTime(picked.year, picked.month, picked.day);
                _isLoading = true;
              });
              await _fetchDailyData(_viewDate);
              if (mounted) setState(() => _isLoading = false);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                isToday ? 'เปลี่ยนวันที่' : 'วันอื่น',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Calorie Card ─────────────────────────────────────────────────────────

  Widget _buildCalorieCard(int currentCal, int targetCal, double progress,
      bool isOver, dynamic userData) {
    final ringColor = isOver ? Colors.red : _green;
    final advice = _getAdvice(currentCal, targetCal, isOver);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                color: _green, size: 20),
            const SizedBox(width: 8),
            const Text('แคลอรี่ที่ทานวันนี้',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showCalcFormulaSheet(userData),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F7E8),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calculate_outlined, size: 13, color: _green),
                  SizedBox(width: 3),
                  Text('สูตรคำนวณ',
                      style: TextStyle(
                          fontSize: 11,
                          color: _green,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProgressScreen())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_rounded, size: 14, color: _green),
                  SizedBox(width: 4),
                  Text('กราฟ',
                      style: TextStyle(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // Ring + Numbers side by side
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Calorie ring
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(alignment: Alignment.center, children: [
                const SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 12,
                    color: Color(0xFFE8EFCF),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    color: ringColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '$currentCal',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isOver ? Colors.red : Colors.black87,
                        height: 1),
                  ),
                  Text('kcal',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),

            const SizedBox(width: 20),

            // Stats
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _calorieStatItem(
                        userData.hasBackendTargetCalories
                            ? 'เป้าหมาย'
                            : 'เป้าหมาย (ประมาณ)',
                        '$targetCal kcal',
                        _green,
                        Icons.flag_outlined,
                        helperText: userData.targetSourceLabel),
                    const SizedBox(height: 12),
                    // Removed extra stat item based on user request
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE8EFCF),
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress * 100).toInt()}% ของเป้าหมาย',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
            ),
          ]),

          const SizedBox(height: 16),

          // Advice chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOver ? Colors.red.shade50 : const Color(0xFFF0F7E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(
                isOver ? Icons.info_outline : Icons.tips_and_updates_outlined,
                size: 16,
                color: isOver ? Colors.red : _green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice,
                  style: TextStyle(
                      fontSize: 13,
                      color: isOver
                          ? Colors.red.shade700
                          : const Color(0xFF3D5A27),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _calorieStatItem(
      String label, String value, Color color, IconData icon,
      {String? helperText}) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500, height: 1.2)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.2)),
        if (helperText != null)
          Text(helperText,
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade500, height: 1.2)),
      ]),
    ]);
  }

  // ─── Formula Sheet ────────────────────────────────────────────────────────

  void _showCalcFormulaSheet(dynamic userData) {
    final String gender = (userData.gender as String?) ?? 'male';
    final int age = (userData.age as int?) ?? 0;
    final double weight = (userData.weight as num).toDouble();
    final double height = (userData.height as num).toDouble();
    final double bmr = (userData.bmr as num).toDouble();
    final double tdee = (userData.tdee as num).toDouble();
    final int targetCal = (userData.targetCalories as num).toInt();

    final activityLabelMap = {
      'sedentary': 'นั่งทำงาน (×1.2)',
      'lightly_active': 'เคลื่อนไหวน้อย (×1.375)',
      'moderately_active': 'ปานกลาง (×1.55)',
      'very_active': 'ออกกำลังกายหนัก (×1.725)',
      'extra_active': 'หนักมาก (×1.9)',
    };
    final actLevel = (userData.activityLevel as String?) ?? 'sedentary';
    final double factor = tdee > 0 && bmr > 0 ? tdee / bmr : 1.2;
    const green = Color(0xFF628141);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(controller: sc, children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('สูตรคำนวณเป้าหมายของคุณ',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('อิงจากสูตร Mifflin–St Jeor Equation',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            const SizedBox(height: 20),

            // BMR Section
            _formulaSection('🔥 BMR (พลังงานขั้นพื้นฐาน)', [
              _formulaRow('เพศ', gender == 'female' ? 'หญิง' : 'ชาย'),
              _formulaRow('น้ำหนัก', '${weight.toStringAsFixed(1)} กก.'),
              _formulaRow('ส่วนสูง', '${height.toStringAsFixed(1)} ซม.'),
              _formulaRow('อายุ', '$age ปี'),
              _formulaRow(
                  'สูตร',
                  gender == 'female'
                      ? '(10×W)+(6.25×H)−(5×A)−161'
                      : '(10×W)+(6.25×H)−(5×A)+5',
                  isFormula: true),
              _formulaRow('BMR', '${bmr.toStringAsFixed(0)} kcal/วัน',
                  highlight: true),
            ]),

            // TDEE Section
            _formulaSection('⚡ TDEE (พลังงานที่ใช้จริง)', [
              _formulaRow(
                  'ระดับกิจกรรม', activityLabelMap[actLevel] ?? actLevel),
              _formulaRow('สูตร', 'BMR × $factor', isFormula: true),
              _formulaRow('TDEE', '${tdee.toStringAsFixed(0)} kcal/วัน',
                  highlight: true),
            ]),

            // Target Section
            _formulaSection('🎯 เป้าหมายที่แอปกำหนด', [
              _formulaRow('เป้าแคลอรี่', '$targetCal kcal/วัน',
                  highlight: true),
              _formulaRow('โปรตีน', '${userData.targetProtein} g'),
              _formulaRow('คาร์โบไฮเดรต', '${userData.targetCarbs} g'),
              _formulaRow('ไขมัน', '${userData.targetFat} g'),
            ]),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F7E8),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ค่าเป้าหมายสามารถปรับได้ที่หน้าแก้ไขโปรไฟล์',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _formulaSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: rows),
        ),
      ]),
    );
  }

  Widget _formulaRow(String label, String value,
      {bool highlight = false, bool isFormula = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                color: highlight
                    ? const Color(0xFF628141)
                    : isFormula
                        ? Colors.blueGrey.shade700
                        : Colors.black87,
                fontFamily: isFormula ? 'monospace' : null)),
      ]),
    );
  }

  // ─── Macro Row ────────────────────────────────────────────────────────────

  Widget _buildMacroRow(dynamic userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
            child: _macroCard('โปรตีน', userData.consumedProtein,
                userData.targetProtein, _green, '🥩', 'protein',
                isEstimated: !userData.hasBackendTargetMacros)),
        const SizedBox(width: 10),
        Expanded(
            child: _macroCard('คาร์บ', userData.consumedCarbs,
                userData.targetCarbs, _greenDark, '\u{1F35A}', 'carbs',
                isEstimated: !userData.hasBackendTargetMacros)),
        const SizedBox(width: 10),
        Expanded(
            child: _macroCard('ไขมัน', userData.consumedFat, userData.targetFat,
                const Color(0xFF4A7A20), '🍟', 'fat',
                isEstimated: !userData.hasBackendTargetMacros)),
      ]),
    );
  }

  Widget _macroCard(String label, int current, int target, Color color,
      String emoji, String macroType,
      {bool isEstimated = false}) {
    final isOver = target > 0 && current > target;
    final displayColor = isOver ? const Color(0xFFD32F2F) : color;
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MacroDetailScreen(macroType: macroType)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOver ? const Color(0xFFFFF0F0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isOver
              ? Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                  width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('$current g',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOver ? const Color(0xFFD32F2F) : Colors.black87)),
            Text('/ $target g${isEstimated ? ' ประมาณ' : ''}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(displayColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Extras ───────────────────────────────────────────────────────────────

  Widget _buildRestaurantButton(int remainingCalories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => RestaurantMapScreen(
                    remainingCalories: remainingCalories.toDouble())),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'ค้นหาร้านอาหารใกล้คุณ',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Weight & BMI Row ─────────────────────────────────────────────────────

  Widget _buildWeightBMIRow(dynamic userData, double bmi, String bmiStatus) {
    final diff = (userData.weight - userData.targetWeight).abs();
    final action =
        (userData.weight > userData.targetWeight) ? 'ลดอีก' : 'เพิ่มอีก';

    final bmiColor = bmiRiskColor(bmi);
    final bmiRisk = bmiBandData(bmi);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Weight card
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeightChartScreen()),
              );
              if (!mounted) return;
              _fetchAllData();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.monitor_weight_outlined,
                            size: 16, color: _green),
                      ),
                      const SizedBox(width: 8),
                      const Text('น้ำหนัก',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ]),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${userData.weight.toInt()}',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const TextSpan(
                            text: ' กก.',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เป้าหมาย: ${userData.targetWeight.toInt()} กก.',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              action == 'ลดอีก'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 14,
                              color: _greenDark),
                          const SizedBox(width: 4),
                          Text(
                            '$action ${diff.toStringAsFixed(1)} กก.',
                            style: const TextStyle(
                                fontSize: 13,
                                color: _greenDark,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ]),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // BMI card
        Expanded(
          child: GestureDetector(
            onTap: bmi > 0
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BmiDetailScreen(
                            currentBmi: bmi,
                            weightKg: userData.weight,
                            heightCm: userData.height)))
                : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: bmiColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: Icon(Icons.speed_rounded,
                            size: 16, color: bmiColor),
                      ),
                      const SizedBox(width: 8),
                      const Text('BMI',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showBmiRangePopup(context, bmi),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle),
                          child: Icon(Icons.info_outline_rounded,
                              size: 15, color: Colors.grey.shade400),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    bmi > 0
                        ? RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: bmi.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: bmiColor),
                                ),
                              ],
                            ),
                          )
                        : const Text('-',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      'ส่วนสูง ${userData.height.toInt()} ซม.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bmiColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        bmiStatus,
                        style: TextStyle(
                            fontSize: 11,
                            color: bmiColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bmiRisk.riskText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          height: 1.25),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Meals Section ────────────────────────────────────────────────────────

  Widget _buildMealsSection(dynamic userData) {
    final meals = userData.dailyMeals as Map<String, String>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
                color: _green, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          const Text(
            'มื้ออาหารวันนี้',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ]),

        const SizedBox(height: 12),

        if (meals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.restaurant_outlined,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('ยังไม่มีรายการอาหาร',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('กดปุ่ม "บันทึก" เพื่อเพิ่มรายการ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          )
        else
          Column(
            children: _getSortedMealKeys(meals).map((key) {
              return _buildMealCard(
                  key, _formatMealLabel(key), meals[key] ?? '-');
            }).toList(),
          ),
      ]),
    );
  }

  Widget _buildMealCard(String mealType, String mealLabel, String menuText) {
    final bool hasMenu =
        menuText.isNotEmpty && menuText != '-' && menuText != '';
    final List<String> items = hasMenu
        ? menuText
            .split(RegExp(r',\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _greenLight,
              shape: BoxShape.circle,
            ),
            child: Icon(_mealIcon(mealType), color: _green, size: 20),
          ),
          title: Text(mealLabel,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          subtitle: Text(
            hasMenu ? '${items.length} รายการ' : 'ยังไม่มีรายการ',
            style: TextStyle(
                fontSize: 12,
                color: hasMenu ? Colors.grey.shade600 : Colors.grey.shade400),
          ),
          trailing: hasMenu
              ? null
              : IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: Colors.grey.shade400, size: 22),
                  onPressed: () =>
                      ref.read(navIndexProvider.notifier).state = 1,
                ),
          children: items.isEmpty
              ? const []
              : [
                  for (final name in items)
                    InkWell(
                      onTap: () =>
                          ref.read(navIndexProvider.notifier).state = 1,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.fiber_manual_record,
                              size: 8, color: _green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey.shade400, size: 18),
                        ]),
                      ),
                    ),
                ],
        ),
      ),
    );
  }

  // ─── Tamagotchi Banner ────────────────────────────────────────────────────
  Widget _buildTamagotchiBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TamagotchiScreen())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2E10), Color(0xFF1B5E20)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          const Text('🌾', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ไร่ข้าวของฉัน',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text('รดน้ำต้นข้าววันนี้ — สะสมเมล็ดข้าว',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.5)),
            ),
            child: const Text('ดูไร่ →',
                style: TextStyle(
                    color: Color(0xFFA5D6A7),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
