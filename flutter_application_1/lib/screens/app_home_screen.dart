import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import 'dart:convert';
import '/screens/profile/subprofile_screen/progress_screen.dart';
import '/screens/profile/subprofile_screen/tdee_formula_screen.dart';
import '../../services/api_client.dart';
import '../../services/daily_summary_enrichment.dart';
import '../../services/notification_helper.dart';
import '../../services/lifecycle_service.dart';
import '../../services/streak_service.dart';
import '../../services/fcm_service.dart';
import '../../services/error_reporter.dart';
import '../../utils/bmi_utils.dart';
import '../../constants/constants.dart';
import '../../utils/nutrition_approx.dart';
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
  int _streak = 0;

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
      ref.listenManual(homeViewDateProvider, (prev, next) {
        if (next != null && mounted) {
          ref.read(homeViewDateProvider.notifier).state = null;
          setState(() => _viewDate = DateTime(next.year, next.month, next.day));
          _fetchDailyData(_viewDate);
        }
      });
      ref.listenManual(dailyFoodRevisionProvider, (prev, next) {
        if (mounted && next != prev) {
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
      // P1: reset re-engagement timer ทุกครั้งที่ user เปิดแอป
      NotificationHelper.scheduleReEngagementGuard();
      // P4: upload FCM token ถ้ายังไม่เคย หรือ token refresh
      FcmService.uploadToken(userId);
      // P3: schedule streak warning ถ้ายังไม่ได้บันทึกวันนี้ + โหลด streak
      StreakService.scheduleWarningIfNeeded();
      final streak = await StreakService.getStreak();
      if (mounted) setState(() => _streak = streak);
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
        var summaryData =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        summaryData = await ensureDailySummaryMealItems(
          userId: userId,
          dateStr: dateStr,
          summaryData: summaryData,
        );
        ref.read(userDataProvider.notifier).setDailySummaryFromApi(summaryData);
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

  String _getAdvice(int ringCal, int targetCal, bool isOver) {
    if (ringCal == 0) return "เริ่มบันทึกมื้อแรกของวันกันเลย!";
    if (isOver) return "พลังงานเกินเป้าหมาย ลองเดินย่อยดูนะ";
    final pct = ringCal / targetCal;
    if (pct >= 0.9) return "ใกล้ถึงเป้าแล้ว มื้อหน้าเลือกทานเบาๆ นะ";
    if (pct >= 0.5) return "กำลังดี! รักษาวินัยต่อไปได้เลย";
    return "วันนี้ยังเหลืออีกเยอะ ทานให้ครบนะ";
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    final int targetCal = userData.targetCalories.toInt() > 0
        ? userData.targetCalories.toInt()
        : 1500;
    final int grossIntake = userData.consumedCalories;
    final int burned = userData.dailyCaloriesBurned;
    final int ringCal = userData.netCaloriesIntake;
    final double progress =
        (targetCal > 0) ? (ringCal / targetCal).clamp(0.0, 1.0) : 0.0;
    final bool isOver = ringCal > targetCal;

    if (isOver && !_hasWarnedCalories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ แจ้งเตือน: แคลอรีเกินเป้าหมายแล้ว!'),
            backgroundColor: Colors.redAccent));
        NotificationHelper.showCalorieAlert(ringCal, targetCal);
        setState(() => _hasWarnedCalories = true);
      });
    }

    final double bmi = userData.bmi;
    final String bmiStatus = getBMIStatus(bmi);

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
                            ringCal,
                            grossIntake,
                            burned,
                            targetCal,
                            progress,
                            isOver,
                            userData),
                        const SizedBox(height: 12),
                        _buildMacroRow(userData),
                        const SizedBox(height: 12),
                        _buildWeightBMIRow(userData, bmi, bmiStatus),
                        const SizedBox(height: 16),
                        _buildRestaurantButton(targetCal - ringCal),
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
        // Streak badge
        if (_streak >= 2) ...[
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$_streak วัน',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ),
        ],
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

  Widget _buildCalorieCard(
      int ringCal,
      int grossIntake,
      int burned,
      int targetCal,
      double progress,
      bool isOver,
      dynamic userData) {
    final ringColor = isOver ? Colors.red : _green;
    final advice = _getAdvice(ringCal, targetCal, isOver);

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
            const Text('แคลอรี่ที่ได้รับในวันนี้',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Spacer(),
            _actionChipButton(
              label: 'สูตรคำนวณ',
              icon: Icons.calculate_outlined,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TdeeFormulaScreen())),
            ),
            const SizedBox(width: 8),
            _actionChipButton(
              label: 'กราฟ',
              icon: Icons.bar_chart_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProgressScreen())),
            ),
          ]),

          if (burned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'กิน ${NutritionApprox.kcalExact(grossIntake.toDouble())} · เผา ${NutritionApprox.kcalExact(burned.toDouble())}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

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
                    '${ringCal.round()}',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isOver ? Colors.red : Colors.black87,
                        height: 1),
                  ),
                  Text('kcal สุทธิ',
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
                        'เป้าหมาย',
                        NutritionApprox.kcalExact(targetCal.toDouble()),
                        _green,
                        Icons.flag_outlined,
                        helperText: userData.targetCaloriesSourceLabel),
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

  Widget _actionChipButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: _greenLight, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: _green),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
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
    final gramCurrent =
        isEstimated ? NutritionApprox.tildeRound(current.toDouble()) : '${current.round()}';
    final gramTarget = isEstimated
        ? '${NutritionApprox.tildeRound(target.toDouble())} g'
        : '${target.round()} g';
    final isOver = target > 0 && current > target;
    final displayColor = isOver ? const Color(0xFFD32F2F) : color;
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () {
        ref.read(macroFilterProvider.notifier).state = macroType;
        ref.read(navIndexProvider.notifier).state = 2;
      },
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
            Text('$gramCurrent g',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOver ? const Color(0xFFD32F2F) : Colors.black87)),
            Text('/ $gramTarget${isEstimated ? ' ประมาณ' : ''}',
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

  Widget _buildMealsSection(UserData userData) {
    final meals = userData.dailyMeals;

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
              final richItems = userData.dailyMealItems[key];
              return _buildMealCard(
                key,
                _formatMealLabel(key),
                meals[key] ?? '-',
                richItems,
              );
            }).toList(),
          ),
      ]),
    );
  }

  String _resolvedFoodImageUrl(String? url) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    final path = u.startsWith('/') ? u : '/$u';
    return '$base$path';
  }

  Widget _buildMealCard(
    String mealType,
    String mealLabel,
    String menuText,
    List<HomeLoggedFoodItem>? richItems,
  ) {
    final bool hasRich = richItems != null && richItems.isNotEmpty;
    final bool hasMenu = hasRich ||
        (menuText.isNotEmpty && menuText != '-' && menuText != '');
    final List<String> items = !hasRich && hasMenu
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
            hasMenu
                ? '${hasRich ? richItems.length : items.length} รายการ'
                : 'ยังไม่มีรายการ',
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
          children: [
            if (hasRich)
              ...richItems.map((food) {
                final imgUrl = _resolvedFoodImageUrl(food.imageUrl);
                final cal = food.totalCal.round();
                final p = food.totalProtein.round();
                final c = food.totalCarbs.round();
                final fVal = food.totalFat.round();
                final macroLine = NutritionApprox.mealMacroLineHome(
                    cal.toDouble(),
                    p.toDouble(),
                    c.toDouble(),
                    fVal.toDouble());
                return InkWell(
                  onTap: () =>
                      ref.read(navIndexProvider.notifier).state = 1,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: imgUrl.isNotEmpty
                                ? Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: _greenLight,
                                      child: Icon(Icons.restaurant,
                                          color: _green.withValues(alpha: 0.6),
                                          size: 26),
                                    ),
                                  )
                                : Container(
                                    color: _greenLight,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.restaurant_outlined,
                                        color:
                                            _green.withValues(alpha: 0.65),
                                        size: 26),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.foodName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                macroLine,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400, size: 18),
                      ],
                    ),
                  ),
                );
              })
            else if (items.isNotEmpty)
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
