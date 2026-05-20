import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import 'dart:convert';
import 'dart:async';
import '/screens/profile/subprofile_screen/progress_screen.dart';
import '/screens/profile/subprofile_screen/tdee_formula_screen.dart';
import '../../services/api_client.dart';
import '../../services/daily_summary_enrichment.dart';
import '../../services/notification_helper.dart';
import '../../services/lifecycle_service.dart';
import '../../services/streak_service.dart';
import '../../services/fcm_service.dart';
import '../../services/error_reporter.dart';
import '../../services/notification_prefs_service.dart';
import '../../utils/bmi_utils.dart';
import '../../constants/constants.dart';
import '../../utils/nutrition_approx.dart';
import '/screens/restaurant_map_screen.dart';
import '/screens/bmi/bmi_detail_screen.dart';
import '/screens/tamagotchi/tamagotchi_screen.dart';
import '/screens/weight/weight_chart_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/step_provider.dart';
import '../../services/pedometer_service.dart';

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
  bool _permissionDenied = false;
  late DateTime _viewDate;
  int _streak = 0;

  // Feature 2: copy-yesterday notification action listener
  VoidCallback? _payloadListener;

  @override
  void initState() {
    super.initState();
    _viewDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncViewDateFromProvider();
      _fetchAllData();
      unawaited(PedometerService.instance.start());
      // Feature 2: listen for copy_yesterday notification action
      _payloadListener = () {
        final payload = NotificationHelper.pendingPayload.value;
        if (payload != null && payload.startsWith('copy_yesterday:')) {
          final mealType = payload.substring('copy_yesterday:'.length);
          NotificationHelper.pendingPayload.value = null;
          _handleCopyYesterday(mealType);
        }
      };
      NotificationHelper.pendingPayload.addListener(_payloadListener!);
      // Handle payload that arrived before listener was set (app launched from notification)
      final initialPayload = NotificationHelper.pendingPayload.value;
      if (initialPayload != null && initialPayload.startsWith('copy_yesterday:')) {
        final mealType = initialPayload.substring('copy_yesterday:'.length);
        NotificationHelper.pendingPayload.value = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleCopyYesterday(mealType));
      }
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

  @override
  void dispose() {
    if (_payloadListener != null) {
      NotificationHelper.pendingPayload.removeListener(_payloadListener!);
    }
    super.dispose();
  }

  // Feature 2: copy yesterday's meal via API then refresh home
  Future<void> _handleCopyYesterday(String mealType) async {
    if (!mounted) return;
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    try {
      final res = await ApiClient().post(
        '/meals/$userId/copy-yesterday',
        body: {'meal_type': mealType},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final copied = data['copied'] as int? ?? 0;
        if (copied > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ คัดลอก $copied รายการจากเมื่อวานแล้ว'),
            backgroundColor: const Color(0xFF628141),
            duration: const Duration(seconds: 3),
          ));
          ref.read(dailyFoodRevisionProvider.notifier).state++;
          await _fetchDailyData(_viewDate);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่มีข้อมูลมื้ออาหารเมื่อวาน'),
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      debugPrint('[copy_yesterday] error: $e');
    }
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
      // Tier 3.4: pull notification prefs from backend → sync to SharedPrefs
      NotificationPrefsService.pull(userId);
      // P3: schedule streak warning ถ้ายังไม่ได้บันทึกวันนี้ + โหลด streak
      StreakService.scheduleWarningIfNeeded();
      final streak = await StreakService.getStreak();
      // Celebration: notify on streak milestones (3, 7, 14, 30 days)
      unawaited(NotificationHelper.showStreakCelebration(streak));
      // Tier 2.5: check permission denied flag
      final permDenied = await NotificationHelper.isPermissionDenied();
      if (mounted) {
        setState(() {
          _streak = streak;
          _permissionDenied = permDenied;
        });
      }
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
        var summaryData = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        summaryData = await ensureDailySummaryMealItems(
          userId: userId,
          dateStr: dateStr,
          summaryData: summaryData,
        );
        ref.read(userDataProvider.notifier).setDailySummaryFromApi(summaryData);

        // Feature 1: cache today's macro data for personalised notification copy
        if (_isToday(forDate)) {
          final userData = ref.read(userDataProvider);
          unawaited(NotificationHelper.cacheHomeMacros(
            proteinEaten: userData.consumedProtein,
            proteinTarget: userData.targetProtein,
            caloriesEaten: userData.consumedCalories,
            caloriesTarget: userData.targetCalories.toInt(),
          ));
          // Re-schedule meals once per day with personalised copy
          unawaited(NotificationHelper.reschedulePersonalizedMeals());
        }

        // Tier 2.4 + Gap Filling: manage meal reminders based on today's log state
        if (_isToday(forDate)) {
          final mealItems =
              summaryData['meal_items'] as Map<String, dynamic>? ?? {};
          for (final mealType in ['breakfast', 'lunch', 'dinner']) {
            final items = mealItems[mealType];
            final hasItems = items is List && items.isNotEmpty;
            if (hasItems) {
              // Already logged → cancel recurring + gap-fill reminders
              NotificationHelper.suppressTodayMealReminder(mealType);
            } else {
              // Not logged yet → schedule gap-fill urgent notification at deadline
              unawaited(NotificationHelper.scheduleGapFillIfNeeded(mealType));
            }
          }

          // Celebration: check if daily calorie goal achieved (within ±10%)
          final userData = ref.read(userDataProvider);
          final target = userData.targetCalories.toInt();
          final eaten = userData.consumedCalories;
          if (target > 0 && eaten >= (target * 0.9).toInt() && eaten <= (target * 1.1).toInt()) {
            unawaited(NotificationHelper.showGoalAchievedNotification(eaten));
          }
        }
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
                  color: isMe ? r.color.withOpacity(0.12) : Colors.grey.shade50,
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
                        // Tier 2.5: Permission denied banner
                        if (_permissionDenied) _buildPermissionBanner(),
                        _buildDateHeader(),
                        const SizedBox(height: 16),
                        _buildCalorieCard(ringCal, grossIntake, burned,
                            targetCal, progress, isOver, userData),
                        const SizedBox(height: 12),
                        _buildMacroRow(userData),
                        const SizedBox(height: 12),
                        _buildStepCard(),
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

  // ─── Permission Banner (Tier 2.5) ────────────────────────────────────────

  Widget _buildPermissionBanner() {
    return Container(
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.notifications_off_outlined,
            size: 18, color: Color(0xFF856404)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'เปิดการแจ้งเตือนเพื่อใช้งานเต็มประสิทธิภาพ',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF856404),
                fontWeight: FontWeight.w500),
          ),
        ),
        GestureDetector(
          onTap: () async {
            await openAppSettings();
            // Re-check after returning from settings
            final denied = await NotificationHelper.isPermissionDenied();
            if (mounted) setState(() => _permissionDenied = denied);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF856404),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('ตั้งค่า',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() => _permissionDenied = false),
          child: const Icon(Icons.close, size: 16, color: Color(0xFF856404)),
        ),
      ]),
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
                    fontSize: 13, color: Colors.white.withOpacity(0.75)),
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
              color: Colors.orange.withOpacity(0.25),
              borderRadius: BorderRadius.circular(50),
              border:
                  Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
              border:
                  Border.all(color: Colors.white.withOpacity(0.4), width: 1),
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

  Widget _buildCalorieCard(int ringCal, int grossIntake, int burned,
      int targetCal, double progress, bool isOver, dynamic userData) {
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
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                color: _green, size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('แคลอรี่ที่ได้รับวันนี้',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            const Spacer(),
            Tooltip(
              message: 'สูตรคำนวณ TDEE',
              child: Material(
                color: _greenLight,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TdeeFormulaScreen())),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child:
                        Icon(Icons.calculate_outlined, size: 18, color: _green),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'กราฟความคืบหน้า',
              child: Material(
                color: _greenLight,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProgressScreen())),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child:
                        Icon(Icons.bar_chart_rounded, size: 18, color: _green),
                  ),
                ),
              ),
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
          color: color.withOpacity(0.1),
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
    final gramCurrent = isEstimated
        ? NutritionApprox.tildeRound(current.toDouble())
        : '${current.round()}';
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
                  color: const Color(0xFFD32F2F).withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                color: displayColor.withOpacity(0.12),
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
                  color: _green.withOpacity(0.3),
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

  // ─── Step Card ───────────────────────────────────────────────────────────

  Widget _buildStepCard() {
    final stepAsync = ref.watch(stepCountProvider);
    final statusAsync = ref.watch(pedestrianStatusProvider);
    final userData = ref.watch(userDataProvider);
    const goal = 10000;

    final statusBadge = statusAsync.whenOrNull(
      data: (status) {
        final isWalking = status == 'walking';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isWalking
                ? _green.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isWalking
                  ? Icons.directions_walk_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 13,
              color: isWalking ? _green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              isWalking ? 'กำลังเดิน' : 'หยุด',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isWalking ? _green : Colors.grey,
              ),
            ),
          ]),
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_walk_rounded,
                  size: 20, color: _green),
            ),
            const SizedBox(width: 10),
            const Text(
              'ก้าวเดินวันนี้',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const Spacer(),
            if (statusBadge != null) statusBadge,
          ]),
          const SizedBox(height: 14),
          stepAsync.when(
            data: (steps) {
              final pct = (steps / goal).clamp(0.0, 1.0);
              final reachGoal = steps >= goal;

              // Research-backed calorie calculation
              // Ref: Ludlow & Weyand (2004), Med Sci Sports Exerc 36(12):2128-2134
              //      https://pubmed.ncbi.nlm.nih.gov/15570150/
              // Ref: McArdle, Katch & Katch — Exercise Physiology (8th ed.)
              //      Coefficient: 0.8 kcal/kg/km
              final calc = PedometerService.calculateCaloriesBurned(
                steps: steps,
                weightKg: userData.weight,
                heightCm: userData.height,
                gender: userData.gender,
              );
              final distanceLabel = calc.distanceKm >= 1.0
                  ? '${calc.distanceKm.toStringAsFixed(2)} กม.'
                  : '${(calc.distanceKm * 1000).toStringAsFixed(0)} ม.';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step count + goal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$steps',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: reachGoal ? _green : Colors.black87,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ $goal ก้าว',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ),
                      if (reachGoal) ...[
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('🎉', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: _greenLight,
                      valueColor: const AlwaysStoppedAnimation(_green),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(pct * 100).toInt()}% ของเป้าหมาย',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500),
                  ),

                  // Distance + Calories row (แสดงเมื่อมีข้อมูล weight/height)
                  if (calc.distanceKm > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      // Distance
                      Expanded(
                        child: Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.route_rounded,
                                size: 15, color: Colors.blue.shade400),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ระยะทาง',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                              Text(distanceLabel,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                            ],
                          ),
                        ]),
                      ),
                      // Calories burned
                      Expanded(
                        child: Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.local_fire_department_rounded,
                                size: 15, color: Colors.orange.shade600),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('เผาผลาญ',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                              Text(
                                '${calc.calories.toStringAsFixed(1)} kcal',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ]),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _green),
                ),
              ),
            ),
            error: (_, __) => Text(
              'ไม่สามารถอ่านข้อมูลก้าวเดินได้',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ]),
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
                      color: Colors.black.withOpacity(0.05),
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
                            color: _green.withOpacity(0.1),
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
                      color: Colors.black.withOpacity(0.05),
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
                            color: bmiColor.withOpacity(0.1),
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
                        color: bmiColor.withOpacity(0.1),
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
                    color: Colors.black.withOpacity(0.04),
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
    final bool hasMenu =
        hasRich || (menuText.isNotEmpty && menuText != '-' && menuText != '');
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
              color: Colors.black.withOpacity(0.04),
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
                  onTap: () => ref.read(navIndexProvider.notifier).state = 1,
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
                                          color: _green.withOpacity(0.6),
                                          size: 26),
                                    ),
                                  )
                                : Container(
                                    color: _greenLight,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.restaurant_outlined,
                                        color: _green.withOpacity(0.65),
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
                  onTap: () => ref.read(navIndexProvider.notifier).state = 1,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.35),
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
              Text('ออกกำลังกาย เดิน กินครบ — เก็บเมล็ดขึ้น Tier รับรางวัล',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF66BB6A).withOpacity(0.5)),
            ),
            child: const Text('เข้าร่วม →',
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
