import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';
import '/screens/tamagotchi/achievements_screen.dart';
import '/screens/tamagotchi/reward_shop_screen.dart';
import '/services/api_client.dart';
import '/services/error_reporter.dart';
import '/services/health_service.dart';
import '/services/streak_service.dart';
import '/services/tamagotchi_action_logger.dart';
import '/screens/weight/weight_chart_screen.dart';
import '/screens/tamagotchi/referral_screen.dart';

// ─────────────────────────────────────────────────────────
//  Tier System — 5 levels, WEEKLY (rotates every Monday)
//  XP rolls over every Monday; tier resets to 🌱 each week.
//  Daily max XP ≈ 135 → weekly max ≈ 945 → thresholds tuned
//  so reaching ✨ requires ~5 active days.
// ─────────────────────────────────────────────────────────
class _Tier {
  final String name;
  final String emoji;
  final int minXp;
  final int
      weeklyReward; // gems awarded at end of week if finishing at this tier
  final int
      firstTimeReward; // one-time lifetime bonus when first reaching this tier
  final Color color;
  final String perks;
  const _Tier({
    required this.name,
    required this.emoji,
    required this.minXp,
    required this.weeklyReward,
    required this.firstTimeReward,
    required this.color,
    required this.perks,
  });
}

const _tiers = [
  _Tier(
      name: 'เมล็ดพันธุ์',
      emoji: '🌱',
      minXp: 0,
      weeklyReward: 0,
      firstTimeReward: 0,
      color: Color(0xFF78909C),
      perks: 'เริ่มต้นใหม่ทุกสัปดาห์'),
  _Tier(
      name: 'ต้นกล้า',
      emoji: '🌿',
      minXp: 100,
      weeklyReward: 15,
      firstTimeReward: 30,
      color: Color(0xFF43A047),
      perks: 'จบสัปดาห์ +15 🌾'),
  _Tier(
      name: 'ออกรวง',
      emoji: '🌾',
      minXp: 300,
      weeklyReward: 50,
      firstTimeReward: 50,
      color: Color(0xFF26A69A),
      perks: 'จบสัปดาห์ +50 🌾'),
  _Tier(
      name: 'ข้าวสุก',
      emoji: '🍚',
      minXp: 500,
      weeklyReward: 100,
      firstTimeReward: 150,
      color: Color(0xFFFFB300),
      perks: 'จบสัปดาห์ +100 🌾'),
  _Tier(
      name: 'ข้าวทอง',
      emoji: '✨',
      minXp: 700,
      weeklyReward: 200,
      firstTimeReward: 300,
      color: Color(0xFFAB47BC),
      perks: 'จบสัปดาห์ +200 🌾'),
];

// ─────────────────────────────────────────────────────────
//  Mission Model — dual reward (XP + Gems), flat (Duolingo style)
//  XP = weekly only (rolls over Monday), determines tier
//  Gems = spendable currency, expire 30 days
// ─────────────────────────────────────────────────────────
class _Mission {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final int baseXp;
  final int baseGems;
  final bool Function(UserData u) autoCheck;
  const _Mission({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.baseXp,
    required this.baseGems,
    required this.autoCheck,
  });
}

// ─────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────
class TamagotchiScreen extends ConsumerStatefulWidget {
  const TamagotchiScreen({super.key});
  @override
  ConsumerState<TamagotchiScreen> createState() => _TamagotchiScreenState();
}

class _TamagotchiScreenState extends ConsumerState<TamagotchiScreen>
    with WidgetsBindingObserver {
  // Weekly XP (resets every Monday). Tier is derived from this.
  int _weeklyXp = 0;
  String _weeklyXpWeek = '';
  int _gems = 0;
  int _gemBuffMultiplier = 1;
  // Daily-expiring claim flags
  Set<String> _claimedToday = {};
  // Lifetime achievements: 'first_tier_N', 'streak_N'
  Set<String> _claimedAchievements = {};
  // Daily progress
  int _waterGlasses = 0;
  int _steps = 0;
  bool _loggedWeightToday = false;
  int _todayMealCount = 0;
  bool _reviewedToday = false;
  int _pendingInviteRewards = 0;
  int _currentInviteeCount = 0;
  bool _isClaiming = false;
  // weekly weight progress (for weekly goal card)
  double? _weekStartWeight;
  double? _weekLatestWeight;
  // Streak grace: 0 = ok, 1/2 = days missed (grace), -1 = expired
  int _streakGrace = 0;
  // ป้องกัน load ซ้ำถี่เกิน (throttle 30 วินาที)
  DateTime? _lastLoadTime;

  static const _streakMilestones = [3, 7, 15, 30, 60, 90, 365];

  bool _isStreakMission(String id) => id.startsWith('streak_');

  bool _isMissionClaimed(String id) {
    if (_isStreakMission(id)) {
      return _claimedAchievements.contains(id);
    }
    return _claimedToday.contains(id);
  }

  VoidCallback? _missionGoAction(String id) {
    void goRecord() {
      _lastLoadTime = null;
      Navigator.pop(context);
      ref.read(navIndexProvider.notifier).state = 1;
    }

    void goRecommend() {
      Navigator.pop(context);
      ref.read(navIndexProvider.notifier).state = 2;
    }

    if (id.startsWith('log_meal_') ||
        id == 'drink_water_8' ||
        id == 'nutrition_complete' ||
        id == 'log_exercise') {
      return goRecord;
    }
    if (id == 'review_food' || id == 'add_menu') {
      return goRecommend;
    }
    if (id == 'weight_log') {
      return () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WeightChartScreen(openRecordOnStart: true),
          ),
        );
        if (mounted) await _load();
      };
    }
    if (id == 'invite_friend') {
      return () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ReferralScreen()));
        if (mounted) await _load();
      };
    }
    return null;
  }

  List<_Mission> get _missions => [
        _Mission(
            id: 'check_in',
            emoji: '☀️',
            title: 'เช็กอินวันนี้',
            desc: 'เปิดแอปเพื่อรับ XP ประจำวัน',
            baseXp: 10,
            baseGems: 5,
            autoCheck: (_) => true),
        _Mission(
            id: 'log_meal_1',
            emoji: '🍱',
            title: 'บันทึกอาหาร 1 มื้อ',
            desc: 'บันทึกอาหารวันนี้อย่างน้อย 1 มื้อ (ไม่นับย้อนหลัง)',
            baseXp: 5,
            baseGems: 5,
            autoCheck: (_) => _todayMealCount >= 1),
        _Mission(
            id: 'log_meal_2',
            emoji: '🍽️',
            title: 'บันทึกอาหาร 2 มื้อ',
            desc: 'บันทึกอาหารวันนี้อย่างน้อย 2 มื้อ',
            baseXp: 5,
            baseGems: 5,
            autoCheck: (_) => _todayMealCount >= 2),
        _Mission(
            id: 'log_meal_3',
            emoji: '🥢',
            title: 'บันทึกอาหาร 3 มื้อ',
            desc: 'บันทึกอาหารวันนี้อย่างน้อย 3 มื้อ',
            baseXp: 5,
            baseGems: 5,
            autoCheck: (_) => _todayMealCount >= 3),
        _Mission(
            id: 'drink_water_8',
            emoji: '💧',
            title: 'ดื่มน้ำครบ 8 แก้ว',
            desc: 'ดื่มน้ำครบ 8 แก้ว (2,000 ml) เป้าหมายวัน! — โบนัส +5 XP',
            baseXp: 5,
            baseGems: 5,
            autoCheck: (_) => _waterGlasses >= 8),
        _Mission(
            id: 'nutrition_complete',
            emoji: '🌿',
            title: 'โภชนาการครบ',
            desc: 'แคลอรี่ โปรตีน คาร์บ ไขมัน ทุกตัวอยู่ในช่วง 80–110% ของเป้า',
            baseXp: 20,
            baseGems: 15,
            autoCheck: (u) {
              if (u.targetCalories <= 0 ||
                  u.targetProtein <= 0 ||
                  u.targetCarbs <= 0 ||
                  u.targetFat <= 0) return false;
              bool inRange(num consumed, num target) {
                final r = consumed / target;
                return r >= 0.8 && r <= 1.1;
              }

              return inRange(u.consumedCalories, u.targetCalories) &&
                  inRange(u.consumedProtein, u.targetProtein) &&
                  inRange(u.consumedCarbs, u.targetCarbs) &&
                  inRange(u.consumedFat, u.targetFat);
            }),
        _Mission(
            id: 'log_exercise',
            emoji: '🏃',
            title: 'บันทึกออกกำลังกาย',
            desc: 'บันทึก exercise อย่างน้อย 1 ครั้งวันนี้',
            baseXp: 10,
            baseGems: 5,
            autoCheck: (u) => u.dailyCaloriesBurned > 0),
        _Mission(
            id: 'walk_3k',
            emoji: '👟',
            title: 'เดิน 3,000 ก้าว',
            desc: 'สะสมก้าวเดินจาก IMU/Health Connect ครบ 3,000 ก้าวต่อวัน',
            baseXp: 10,
            baseGems: 5,
            autoCheck: (_) => _steps >= 3000),
        _Mission(
            id: 'walk_8k',
            emoji: '🚶',
            title: 'เดิน 8,000 ก้าว',
            desc: 'สะสมก้าวเดินจาก IMU/Health Connect ครบ 8,000 ก้าวต่อวัน',
            baseXp: 15,
            baseGems: 10,
            autoCheck: (_) => _steps >= 8000),
        _Mission(
            id: 'weight_log',
            emoji: '⚖️',
            title: 'บันทึกน้ำหนัก',
            desc: 'บันทึกน้ำหนักของวันนี้',
            baseXp: 15,
            baseGems: 10,
            autoCheck: (_) => _loggedWeightToday),
        _Mission(
            id: 'review_food',
            emoji: '⭐',
            title: 'รีวิวอาหาร',
            desc: 'ให้คะแนนและรีวิวเมนูอาหารวันนี้',
            baseXp: 5,
            baseGems: 5,
            autoCheck: (_) => _reviewedToday),
        _Mission(
            id: 'invite_friend',
            emoji: '👥',
            title: 'ชวนเพื่อนมาใช้แอป',
            desc: 'เพื่อนกรอกโค้ดเชิญของเราตอนสมัคร — 100 เมล็ด/คน',
            baseXp: 50,
            baseGems: 100,
            autoCheck: (_) => _pendingInviteRewards > 0),
        // Lifetime streak milestones (one-time per user) — reward only 🌾, no XP
        _Mission(
            id: 'streak_3',
            emoji: '🔥',
            title: 'บันทึกต่อเนื่อง 3 วัน',
            desc: 'รางวัลถาวร — ได้รับครั้งเดียวตลอดชีพ',
            baseXp: 0,
            baseGems: 10,
            autoCheck: (u) => u.currentStreak >= 3),
        _Mission(
            id: 'streak_7',
            emoji: '🔥',
            title: 'บันทึกต่อเนื่อง 7 วัน',
            desc: 'รางวัลถาวร — ครบ 1 สัปดาห์เต็ม',
            baseXp: 0,
            baseGems: 25,
            autoCheck: (u) => u.currentStreak >= 7),
        _Mission(
            id: 'streak_15',
            emoji: '🌟',
            title: 'บันทึกต่อเนื่อง 15 วัน',
            desc: 'รางวัลถาวร — ครึ่งเดือนแล้ว!',
            baseXp: 0,
            baseGems: 50,
            autoCheck: (u) => u.currentStreak >= 15),
        _Mission(
            id: 'streak_30',
            emoji: '🌟🌟',
            title: 'บันทึกต่อเนื่อง 30 วัน',
            desc: 'รางวัลถาวร — 1 เดือนเต็ม!',
            baseXp: 0,
            baseGems: 100,
            autoCheck: (u) => u.currentStreak >= 30),
        _Mission(
            id: 'streak_60',
            emoji: '⭐',
            title: 'บันทึกต่อเนื่อง 60 วัน',
            desc: 'รางวัลถาวร — 2 เดือน!',
            baseXp: 0,
            baseGems: 200,
            autoCheck: (u) => u.currentStreak >= 60),
        _Mission(
            id: 'streak_90',
            emoji: '⭐⭐',
            title: 'บันทึกต่อเนื่อง 90 วัน',
            desc: 'รางวัลถาวร — 3 เดือน!',
            baseXp: 0,
            baseGems: 400,
            autoCheck: (u) => u.currentStreak >= 90),
        _Mission(
            id: 'streak_365',
            emoji: '👑',
            title: 'บันทึกต่อเนื่อง 1 ปี',
            desc: 'รางวัลถาวร — ตำนาน 365 วัน!',
            baseXp: 0,
            baseGems: 1000,
            autoCheck: (u) => u.currentStreak >= 365),
      ];

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF1565C0);

  // Tier derived from current weekly XP (resets every Monday)
  int get _activeTierIdx => _tiers
      .lastIndexWhere((t) => _weeklyXp >= t.minXp)
      .clamp(0, _tiers.length - 1);

  // Flat scoring (no tier multiplier) — baseXp/baseGems used directly
  String _gemsKey(int uid) => 'tama_gems_$uid';
  String _weeklyXpKey(int uid) => 'tama_weekly_xp_$uid';
  String _weeklyXpWeekKey(int uid) => 'tama_weekly_week_$uid';
  String _achievementsKey(int uid) => 'tama_achievements_$uid';
  String _lastWeeklyRewardKey(int uid) => 'tama_last_reward_week_$uid';

  // ISO 8601 week key (Asia/Bangkok local time, Monday = day 1)
  static String _weekKey(DateTime localDate) {
    final jan4 = DateTime(localDate.year, 1, 4);
    final week1Start = jan4.subtract(Duration(days: jan4.weekday - 1));
    final daysSinceWeek1 =
        DateTime(localDate.year, localDate.month, localDate.day)
            .difference(week1Start)
            .inDays;
    if (daysSinceWeek1 < 0) {
      // Date falls in previous year's last week
      final prevJan4 = DateTime(localDate.year - 1, 1, 4);
      final prevWeek1 = prevJan4.subtract(Duration(days: prevJan4.weekday - 1));
      final prevDays = DateTime(localDate.year, localDate.month, localDate.day)
          .difference(prevWeek1)
          .inDays;
      final week = (prevDays ~/ 7) + 1;
      return '${localDate.year - 1}-W${week.toString().padLeft(2, '0')}';
    }
    final weekNum = (daysSinceWeek1 ~/ 7) + 1;
    return '${localDate.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  String _claimedKey(int uid) {
    final n = DateTime.now();
    return 'tama_claimed_${uid}_${n.year}-${n.month}-${n.day}';
  }

  String _perfectDayKey(int uid) {
    final n = DateTime.now();
    return 'tama_perfect_day_${uid}_${n.year}-${n.month}-${n.day}';
  }

  String _localWeightLoggedKey(int uid) {
    final n = DateTime.now();
    return 'tama_weight_logged_${uid}_${n.year}-${n.month}-${n.day}';
  }

  String _localWater8Key(int uid) {
    final n = DateTime.now();
    return 'tama_water_8_${uid}_${n.year}-${n.month}-${n.day}';
  }

  String _localWaterGlassesKey(int uid) {
    final n = DateTime.now();
    return 'tama_water_glasses_${uid}_${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh ข้อมูลเมื่อ app กลับมา foreground (เช่น user ออกไปบันทึกใน Health app)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfStale();
  }

  // Refresh เมื่อหน้า TamagotchiScreen กลับมาเป็น active route (pop จากหน้าอื่น)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.isCurrent จะ true เมื่อหน้านี้อยู่บนสุด stack
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) _refreshIfStale();
  }

  void _refreshIfStale() {
    final now = DateTime.now();
    if (_lastLoadTime == null ||
        now.difference(_lastLoadTime!) > const Duration(seconds: 30)) {
      _load();
    }
  }

  Future<void> _load() async {
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();

    // Migrate / clean up old (V1) keys if present
    if (prefs.containsKey('tama_points_$uid')) {
      await prefs.remove('tama_points_$uid');
    }
    if (prefs.containsKey('tama_max_tier_$uid')) {
      await prefs.remove('tama_max_tier_$uid');
    }

    final currentWeek = _weekKey(DateTime.now());
    int weeklyXp = prefs.getInt(_weeklyXpKey(uid)) ?? 0;
    String weeklyWeek = prefs.getString(_weeklyXpWeekKey(uid)) ?? currentWeek;
    int gems = prefs.getInt(_gemsKey(uid)) ?? 0;
    final claimed = (prefs.getStringList(_claimedKey(uid)) ?? []).toSet();
    final achievements =
        (prefs.getStringList(_achievementsKey(uid)) ?? []).toSet();
    final grace = await StreakService.getGraceStatus();

    // Detect weekly rollover BEFORE other state is set
    final isRollover = weeklyWeek != currentWeek && weeklyWeek.isNotEmpty;
    int? prevWeekXp;
    String? prevWeekKey;
    if (isRollover) {
      prevWeekXp = weeklyXp;
      prevWeekKey = weeklyWeek;
      weeklyXp = 0;
      weeklyWeek = currentWeek;
      await prefs.setInt(_weeklyXpKey(uid), 0);
      await prefs.setString(_weeklyXpWeekKey(uid), currentWeek);
    } else if (weeklyWeek.isEmpty) {
      weeklyWeek = currentWeek;
      await prefs.setString(_weeklyXpWeekKey(uid), currentWeek);
    }

    int gemBuffMultiplier = 1;

    if (uid > 0) {
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      try {
        final waterRes = await ApiClient().get(
          '/water_logs/$uid',
          queryParams: {'date_record': today},
        );
        if (waterRes.statusCode == 200) {
          final wData = jsonDecode(waterRes.body);
          final ml = (wData['amount_ml'] as num?)?.toInt() ?? 0;
          if (mounted) {
            final backendGlasses = (ml / 250).round().clamp(0, 20).toInt();
            final localGlasses = prefs.getInt(_localWaterGlassesKey(uid)) ?? 0;
            final waterDone = prefs.getBool(_localWater8Key(uid)) == true;
            final glasses = waterDone
                ? backendGlasses.clamp(8, 20)
                : (backendGlasses > 0 ? backendGlasses : localGlasses);
            setState(() => _waterGlasses = glasses.toInt());
          }
        }
      } catch (e, st) {
        ErrorReporter.report('tama.load.water', e, st);
      }
      try {
        final mealRes = await ApiClient().get(
          '/daily_logs/$uid',
          queryParams: {'date_query': today},
        );
        if (mealRes.statusCode == 200) {
          final mData = jsonDecode(mealRes.body);
          final meals = (mData['meals'] as Map<String, dynamic>?) ?? {};
          int count = 0;
          for (final mt in ['breakfast', 'lunch', 'dinner', 'snack']) {
            final items = meals[mt];
            if (items is List && items.isNotEmpty) count++;
          }
          if (mounted) setState(() => _todayMealCount = count);
        }
      } catch (e, st) {
        ErrorReporter.report('tama.load.meals', e, st);
      }
      try {
        final wlogRes = await ApiClient().get('/users/$uid/weight_logs');
        if (wlogRes.statusCode == 200) {
          final wList = jsonDecode(wlogRes.body) as List;
          final loggedToday = wList.any((e) => e['date'] == today) ||
              prefs.getBool(_localWeightLoggedKey(uid)) == true;
          // Compute this week's weight range (Mon → today)
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekStartStr =
              '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
          final weekEntries = wList.where((e) {
            final d = e['date']?.toString() ?? '';
            return d.compareTo(weekStartStr) >= 0 && d.compareTo(today) <= 0;
          }).toList()
            ..sort(
                (a, b) => (a['date'] as String).compareTo(b['date'] as String));
          double? weightOf(dynamic entry) {
            if (entry is! Map) return null;
            return ((entry['weight_kg'] ?? entry['weight']) as num?)
                ?.toDouble();
          }

          final wStart =
              weekEntries.isNotEmpty ? weightOf(weekEntries.first) : null;
          final wLatest =
              weekEntries.isNotEmpty ? weightOf(weekEntries.last) : null;
          if (mounted) {
            setState(() {
              _loggedWeightToday = loggedToday;
              _weekStartWeight = wStart;
              _weekLatestWeight = wLatest;
            });
          }
        }
      } catch (e, st) {
        ErrorReporter.report('tama.load.weight_logs', e, st);
      }
      try {
        final summary =
            await HealthService.fetchActivitySummary(DateTime.now());
        if (mounted) setState(() => _steps = summary.steps);
      } catch (e, st) {
        ErrorReporter.report('tama.load.steps', e, st);
      }
      final rd = await TamagotchiActionLogger.getFoodReviewDone(uid);
      if (mounted) {
        setState(() {
          _reviewedToday = rd;
        });
      }
      try {
        final invRes = await ApiClient().get('/referral/invitees');
        if (invRes.statusCode == 200) {
          final invList = jsonDecode(invRes.body) as List;
          final currentCount = invList.length;
          final lastCount = prefs.getInt('tama_invitee_count_$uid') ?? 0;
          if (mounted) {
            setState(() {
              _currentInviteeCount = currentCount;
              _pendingInviteRewards = (currentCount - lastCount).clamp(0, 9999);
            });
          }
        }
      } catch (e, st) {
        ErrorReporter.report('tama.load.invitees', e, st);
      }
      try {
        final res = await ApiClient().get('/users/$uid/tama-points');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final bWeeklyXp = (data['weekly_xp'] as num?)?.toInt() ?? 0;
          final bWeeklyWeek = data['weekly_xp_week']?.toString() ?? currentWeek;
          final bGems = (data['gems'] as num?)?.toInt() ?? 0;
          final bAchievements = (data['claimed_achievements'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          // Use backend value only if it's for the same week AND no rollover just happened
          if (!isRollover &&
              bWeeklyWeek == currentWeek &&
              bWeeklyXp > weeklyXp) {
            weeklyXp = bWeeklyXp;
            await prefs.setInt(_weeklyXpKey(uid), weeklyXp);
          }
          if (bGems > gems) {
            gems = bGems;
            await prefs.setInt(_gemsKey(uid), gems);
          }
          if (bAchievements.isNotEmpty) {
            achievements.addAll(bAchievements);
            await prefs.setStringList(
                _achievementsKey(uid), achievements.toList());
          }
        }
      } catch (e, st) {
        ErrorReporter.report('tama.load.tama_points', e, st);
      }

      // Weekly rollover: claim previous-week reward (idempotent on backend)
      if (isRollover && prevWeekKey != null && prevWeekXp != null) {
        await _claimWeeklyReward(uid, prevWeekKey, prevWeekXp);
      }

      // Load active gem buff from referral status
      try {
        final buffRes = await ApiClient().get('/referral/status');
        if (buffRes.statusCode == 200) {
          final buffData = jsonDecode(buffRes.body) as Map<String, dynamic>;
          if (buffData['buff_active'] == true) {
            gemBuffMultiplier =
                (buffData['gem_buff_multiplier'] as num?)?.toInt() ?? 1;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _weeklyXp = weeklyXp;
        _weeklyXpWeek = weeklyWeek;
        _gems = gems;
        _claimedToday = claimed;
        _claimedAchievements = achievements;
        _streakGrace = grace;
        _gemBuffMultiplier = gemBuffMultiplier;
        _lastLoadTime = DateTime.now();
      });
    }
  }

  /// Calls backend to claim the previous week's tier + rank rewards.
  /// Idempotent: backend checks `last_weekly_reward_week` and ignores duplicates.
  Future<void> _claimWeeklyReward(int uid, String week, int weeklyXp) async {
    try {
      final res = await ApiClient().post(
        '/users/$uid/weekly-reset-claim',
        body: {'week': week, 'weekly_xp': weeklyXp},
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['claimed'] != true) return;
      final totalReward = (data['total_reward_gems'] as num?)?.toInt() ?? 0;
      final newGems = (data['new_gems'] as num?)?.toInt() ?? _gems;
      final tierIdx = (data['tier_idx'] as num?)?.toInt() ?? 0;
      final rank = (data['rank'] as num?)?.toInt();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_gemsKey(uid), newGems);
      await prefs.setString(_lastWeeklyRewardKey(uid), week);
      if (mounted) {
        setState(() => _gems = newGems);
        _showWeeklyRewardDialog(tierIdx, rank, totalReward);
      }
    } catch (e, st) {
      ErrorReporter.report('tama.weekly_reset_claim', e, st);
    }
  }

  // Duolingo-style: flat scoring, no tier multiplier or combo bonus
  Future<void> _claimMission(_Mission m) async {
    if (_isClaiming || _isMissionClaimed(m.id)) return;
    setState(() => _isClaiming = true);
    try {
      final uid = ref.read(userDataProvider).userId;
      final prefs = await SharedPreferences.getInstance();

      final int earnedXp;
      int earnedGems;
      if (m.id == 'invite_friend') {
        // Cap invite rewards at 10 per claim to prevent abuse
        final safeCount = _pendingInviteRewards.clamp(0, 10);
        earnedXp = 50 * safeCount;
        earnedGems = 100 * safeCount;
      } else {
        earnedXp = m.baseXp;
        earnedGems = m.baseGems;
      }

      // Apply active gem buff (e.g. ×2 from referral) for mission gems only
      if (earnedGems > 0 && _gemBuffMultiplier > 1) {
        earnedGems = (earnedGems * _gemBuffMultiplier).clamp(0, 99999).toInt();
      }

      int newWeeklyXp = (_weeklyXp + earnedXp).clamp(0, 9999999);
      int newGems = (_gems + earnedGems).clamp(0, 999999);
      final oldTierIdx = _activeTierIdx;

      Set<String> newClaimed = {..._claimedToday};
      Set<String> newAchievements = {..._claimedAchievements};

      if (_isStreakMission(m.id)) {
        // Lifetime achievement
        newAchievements.add(m.id);
      } else {
        newClaimed.add(m.id);
        await prefs.setStringList(_claimedKey(uid), newClaimed.toList());
      }

      // Perfect Day: all non-streak/non-invite missions done → +15 XP, +25 🌾 bonus
      // Guard with daily-scoped key so it can't double-fire when later claims arrive.
      final perfectDayAlreadyAwarded =
          prefs.getBool(_perfectDayKey(uid)) ?? false;
      final allDone = _missions
          .where((ms) => !_isStreakMission(ms.id) && ms.id != 'invite_friend')
          .every((ms) => newClaimed.contains(ms.id));
      final perfectDayAwarded = allDone && !perfectDayAlreadyAwarded;
      if (perfectDayAwarded) {
        newWeeklyXp = (newWeeklyXp + 15).clamp(0, 9999999);
        newGems = (newGems + 25).clamp(0, 999999);
        await prefs.setBool(_perfectDayKey(uid), true);
      }

      final newTierIdx = (_tiers.lastIndexWhere((t) => newWeeklyXp >= t.minXp))
          .clamp(0, _tiers.length - 1);

      // First-time tier achievement (lifetime, one-time per tier)
      int firstTimeBonus = 0;
      int? firstTimeTierIdx;
      if (newTierIdx > oldTierIdx) {
        for (int tierIdx = oldTierIdx + 1; tierIdx <= newTierIdx; tierIdx++) {
          final achKey = 'first_tier_$tierIdx';
          if (!newAchievements.contains(achKey)) {
            newAchievements.add(achKey);
            firstTimeBonus += _tiers[tierIdx].firstTimeReward;
            firstTimeTierIdx ??= tierIdx;
          }
        }
        newGems += firstTimeBonus;
      }

      // Persist
      await prefs.setInt(_weeklyXpKey(uid), newWeeklyXp);
      await prefs.setString(_weeklyXpWeekKey(uid), _weeklyXpWeek);
      await prefs.setInt(_gemsKey(uid), newGems);
      await prefs.setStringList(
          _achievementsKey(uid), newAchievements.toList());
      if (m.id == 'invite_friend') {
        await prefs.setInt('tama_invitee_count_$uid', _currentInviteeCount);
      }

      setState(() {
        _weeklyXp = newWeeklyXp;
        _gems = newGems;
        _claimedToday = newClaimed;
        _claimedAchievements = newAchievements;
      });

      _syncToBackend(newWeeklyXp, newGems, newTierIdx, newAchievements);

      if (mounted) {
        final earnedSummary = earnedXp > 0
            ? '${m.emoji} +$earnedXp XP  +$earnedGems 🌾'
            : '${m.emoji} +$earnedGems 🌾';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(earnedSummary),
          backgroundColor: _tiers[newTierIdx].color,
          duration: const Duration(seconds: 2),
        ));

        // Perfect Day notification
        if (perfectDayAwarded) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  '🌟 Perfect Day! ทำครบทุกภารกิจ → +15 XP, +25 🌾 โบนัส!'),
              backgroundColor: Color(0xFFE65100),
              duration: Duration(seconds: 3),
            ));
          }
        }

        // Weekly tier-up animation
        if (newTierIdx > oldTierIdx) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) _showTierUpDialog(newTierIdx);
          // First-time lifetime bonus popup
          if (firstTimeTierIdx != null && firstTimeBonus > 0) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              _showFirstTimeBadgeDialog(firstTimeTierIdx, firstTimeBonus);
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showTierUpDialog(int tierIdx) {
    final t = _tiers[tierIdx];
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _TierUpDialog(tier: t),
    );
  }

  void _showFirstTimeBadgeDialog(int tierIdx, int rewardGems) {
    final t = _tiers[tierIdx];
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _FirstTimeBadgeDialog(tier: t, rewardGems: rewardGems),
    );
  }

  void _showWeeklyRewardDialog(int tierIdx, int? rank, int totalReward) {
    final t = _tiers[tierIdx.clamp(0, _tiers.length - 1)];
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _WeeklyRewardDialog(
        tier: t,
        rank: rank,
        totalReward: totalReward,
      ),
    );
  }

  void _syncToBackend(
      int weeklyXp, int gems, int tierIdx, Set<String> achievements) {
    if (!mounted) return;
    final uid = ref.read(userDataProvider).userId;
    if (uid <= 0) return;
    ApiClient().patch('/users/$uid/tama-points', body: {
      'tama_points': weeklyXp,
      'weekly_xp': weeklyXp,
      'weekly_xp_week': _weeklyXpWeek,
      'gems': gems,
      'tier_level': tierIdx,
      'claimed_achievements': achievements.toList(),
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final streak = userData.currentStreak;
    final tier = _tiers[_activeTierIdx];
    final nextTier =
        _activeTierIdx < _tiers.length - 1 ? _tiers[_activeTierIdx + 1] : null;
    final progress = nextTier != null
        ? ((_weeklyXp - tier.minXp) / (nextTier.minXp - tier.minXp))
            .clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ไร่ข้าวของฉัน',
            style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Trophy Room',
            icon: const Icon(Icons.emoji_events_rounded,
                color: _primary, size: 24),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen())),
          ),
          IconButton(
            tooltip: 'แลกรางวัล',
            icon: const Icon(Icons.card_giftcard_rounded,
                color: _primary, size: 24),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RewardShopScreen(
                      userId: ref.read(userDataProvider).userId,
                      currentGems: _gems,
                      tierIdx: _activeTierIdx,
                      streakGrace: _streakGrace,
                      onGemsUpdated: (g) => setState(() => _gems = g),
                      onStreakRepaired: () async {
                        await StreakService.repairStreak();
                        if (mounted) setState(() => _streakGrace = 0);
                      },
                    ),
                  ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeroCard(tier, nextTier, progress),
          const SizedBox(height: 16),
          _buildCurrencyRow(streak),
          const SizedBox(height: 16),
          _buildWeeklyGoalCard(userData),
          const SizedBox(height: 20),
          _buildTierRoadmap(),
          const SizedBox(height: 24),
          _buildMissionsSection(userData),
          if (_claimedAchievements.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildBadgesSection(),
          ],
        ]),
      ),
    );
  }

  // ── Hero Card ──────────────────────────────────────────────
  Widget _buildHeroCard(_Tier tier, _Tier? nextTier, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tier.color, Color.lerp(tier.color, Colors.black, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: tier.color.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tier.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
              Text('${tier.perks} • CaloriesGuard',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontFamily: 'Inter')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$_weeklyXp',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
              const Text('XP สัปดาห์',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'Inter')),
            ]),
          ),
        ]),
        if (nextTier != null) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${tier.emoji} ${tier.name}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontFamily: 'Inter')),
            const Spacer(),
            Text(
                'อีก ${nextTier.minXp - _weeklyXp} XP → ${nextTier.emoji} ${nextTier.name}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontFamily: 'Inter')),
          ]),
        ] else ...[
          const SizedBox(height: 16),
          const Text('⚜️ Legend — ระดับสูงสุด!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ── Currency Row ─────────────────────────────────────────
  Widget _buildCurrencyRow(int streak) {
    return Row(children: [
      Expanded(
          child: _currencyCard(
              label: 'XP สัปดาห์',
              value: '$_weeklyXp',
              sub: 'รีเซ็ตทุกจันทร์',
              color: _primary)),
      const SizedBox(width: 10),
      Expanded(
          child: _currencyCard(
              label: 'เมล็ดข้าว 🌾',
              value: '$_gems',
              sub: 'ใช้แลกรางวัล',
              color: const Color(0xFF2E7D32),
              warn: _gems > 0 ? 'หมดอายุ 30 วัน' : null)),
      const SizedBox(width: 10),
      Expanded(
          child: _currencyCard(
        label: 'Streak 🔥',
        value: '$streak วัน',
        sub: streak >= 3 ? 'บันทึกต่อเนื่อง' : 'ทำต่อ 3 วัน',
        color: streak >= 3 ? const Color(0xFFE65100) : Colors.grey.shade500,
      )),
    ]);
  }

  Widget _currencyCard(
      {required String label,
      required String value,
      required String sub,
      required Color color,
      String? warn}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(sub,
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 9, fontFamily: 'Inter')),
        if (warn != null)
          Text(warn,
              style: const TextStyle(
                  color: Color(0xFFE65100), fontSize: 9, fontFamily: 'Inter')),
      ]),
    );
  }

  // ── Weekly Goal Card ──────────────────────────────────────
  Widget _buildWeeklyGoalCard(UserData userData) {
    final goal = userData.goal;
    if (goal == null) return const SizedBox.shrink();

    // Safe targets per program (WHO / ACSM guidelines)
    final String programLabel;
    final String safeTarget;
    final double safeMin; // kg change/week (negative = loss)
    final double safeMax;
    final bool isLoss;

    switch (goal) {
      case GoalOption.loseWeight:
        programLabel = '🏃 ลดน้ำหนัก';
        safeTarget = 'ลด 0.25–0.5 กก./สัปดาห์ (สูงสุด 1 กก.)';
        safeMin = -1.0;
        safeMax = -0.25;
        isLoss = true;
      case GoalOption.buildMuscle:
        programLabel = '💪 เพิ่มกล้ามเนื้อ';
        safeTarget = 'เพิ่ม 0.1–0.25 กก./สัปดาห์';
        safeMin = 0.1;
        safeMax = 0.5;
        isLoss = false;
      case GoalOption.maintainWeight:
        programLabel = '⚖️ รักษาน้ำหนัก';
        safeTarget = 'คงน้ำหนัก ±0.2 กก./สัปดาห์';
        safeMin = -0.2;
        safeMax = 0.2;
        isLoss = false;
    }

    final hasBothWeights =
        _weekStartWeight != null && _weekLatestWeight != null;
    final delta =
        hasBothWeights ? (_weekLatestWeight! - _weekStartWeight!) : null;

    // Status color logic
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (delta == null) {
      statusColor = const Color(0xFF78909C);
      statusText = 'บันทึกน้ำหนักเพื่อดูความคืบหน้า';
      statusIcon = Icons.monitor_weight_outlined;
    } else if (goal == GoalOption.loseWeight) {
      if (delta <= safeMin) {
        // Lost more than 1 kg — too fast
        statusColor = Colors.orange.shade700;
        statusText = 'ลดเร็วเกินไป — อาจเสียกล้ามเนื้อ';
        statusIcon = Icons.warning_amber_rounded;
      } else if (delta <= safeMax) {
        // -0.5 to -0.25 → on track
        statusColor = const Color(0xFF2E7D32);
        statusText = 'อยู่ในเกณฑ์ปลอดภัย ✅';
        statusIcon = Icons.check_circle_outline_rounded;
      } else if (delta < 0) {
        // -0.25 to 0 → losing but slow
        statusColor = Colors.blue.shade700;
        statusText = 'กำลังลดช้า — ปรับการกินหรือออกกำลังกาย';
        statusIcon = Icons.trending_down_rounded;
      } else {
        // Gained weight
        statusColor = Colors.red.shade600;
        statusText = 'น้ำหนักเพิ่มสัปดาห์นี้ — ทบทวนแผน';
        statusIcon = Icons.trending_up_rounded;
      }
    } else if (goal == GoalOption.buildMuscle) {
      if (delta >= safeMin && delta <= safeMax) {
        statusColor = const Color(0xFF2E7D32);
        statusText = 'อยู่ในเกณฑ์การเพิ่มกล้ามเนื้อที่ดี ✅';
        statusIcon = Icons.check_circle_outline_rounded;
      } else if (delta > safeMax) {
        statusColor = Colors.orange.shade700;
        statusText = 'เพิ่มเร็วเกินไป — อาจมีไขมันเกิน';
        statusIcon = Icons.warning_amber_rounded;
      } else {
        statusColor = Colors.blue.shade700;
        statusText = 'เพิ่มช้า — อาจต้องกินโปรตีนเพิ่ม';
        statusIcon = Icons.info_outline_rounded;
      }
    } else {
      // maintainWeight
      if (delta.abs() <= 0.2) {
        statusColor = const Color(0xFF2E7D32);
        statusText = 'รักษาน้ำหนักได้ดี ✅';
        statusIcon = Icons.check_circle_outline_rounded;
      } else {
        statusColor = Colors.orange.shade700;
        statusText = delta > 0 ? 'น้ำหนักขึ้นเล็กน้อย' : 'น้ำหนักลดเล็กน้อย';
        statusIcon = Icons.swap_vert_rounded;
      }
    }

    final String deltaText = delta == null
        ? '—'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} กก.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(programLabel,
                style: TextStyle(
                    color: statusColor,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          const Spacer(),
          Text('เป้าสัปดาห์',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 10),
        Text(safeTarget,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600)),
        if (isLoss) ...[
          const SizedBox(height: 4),
          Text(
              'มาตรฐาน WHO: การลดน้ำหนักเกิน 1 กก./สัปดาห์อาจสูญเสียกล้ามเนื้อ',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontFamily: 'Inter')),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600)),
                    if (delta != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          'สัปดาห์นี้: ${_weekStartWeight!.toStringAsFixed(1)} → '
                          '${_weekLatestWeight!.toStringAsFixed(1)} กก. ($deltaText)',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                              fontFamily: 'Inter')),
                    ],
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const WeightChartScreen(openRecordOnStart: true)),
            ).then((_) => _load()),
            icon: const Icon(Icons.monitor_weight_outlined, size: 18),
            label: const Text('บันทึกน้ำหนักเพื่อดูความคืบหน้า'),
            style: OutlinedButton.styleFrom(
              foregroundColor: statusColor,
              side: BorderSide(color: statusColor.withOpacity(0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tier Roadmap ──────────────────────────────────────────
  Widget _buildTierRoadmap() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ขั้นการเติบโตของไร่ข้าว',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Inter')),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_tiers.length, (i) {
            final t = _tiers[i];
            final isUnlocked = i <= _activeTierIdx;
            final isCurrent = i == _activeTierIdx;
            return Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isCurrent ? 44 : 34,
                  height: isCurrent ? 44 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? t.color.withOpacity(isCurrent ? 1.0 : 0.45)
                        : Colors.grey.shade200,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                                color: t.color.withOpacity(0.5), blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: Center(
                      child: Text(t.emoji,
                          style: TextStyle(fontSize: isCurrent ? 22 : 15))),
                ),
                const SizedBox(height: 4),
                Text(t.name,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isUnlocked ? t.color : Colors.grey.shade400,
                        fontFamily: 'Inter')),
                Text(t.minXp >= 1000 ? '${t.minXp ~/ 1000}k' : '${t.minXp}',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade400,
                        fontFamily: 'Inter')),
              ]),
            );
          }),
        ),
      ]),
    );
  }

  // ── Missions ──────────────────────────────────────────────
  Widget _buildMissionsSection(UserData userData) {
    final dailyMissions = _missions
        .where((m) => m.id.startsWith('log_meal_') || m.id == 'drink_water_8')
        .toList();
    // Use lifetime streak progress (UserData.currentStreak)
    final lifetimeStreak = userData.currentStreak;
    final nextMilestone = _streakMilestones
        .firstWhere((m) => m > lifetimeStreak, orElse: () => 365);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ภารกิจประจำวัน',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontFamily: 'Inter')),
      const SizedBox(height: 12),
      _buildStreakBanner(),
      _buildProgressGroupCard(
        groupId: 'daily',
        onGo: () {
          Navigator.pop(context);
          ref.read(navIndexProvider.notifier).state = 1;
        },
        title: 'บันทึกรายวัน',
        current: _todayMealCount,
        total: 3,
        unit: 'มื้อ',
        extraInfo: '💧 ${_waterGlasses.clamp(0, 8)}/8 แก้ว',
        milestones: dailyMissions,
        userData: userData,
        color: _primary,
      ),
      _buildProgressGroupCard(
        groupId: 'streak',
        title: 'บันทึกต่อเนื่อง (สะสมตลอดชีพ)',
        current: lifetimeStreak.clamp(0, nextMilestone),
        total: nextMilestone,
        unit: 'วัน',
        milestones: _missions.where((m) => m.id.startsWith('streak_')).toList(),
        userData: userData,
        color: const Color(0xFFE65100),
      ),
      ..._missions
          .where((m) =>
              !m.id.startsWith('log_meal_') &&
              m.id != 'drink_water_8' &&
              !m.id.startsWith('streak_'))
          .map((m) =>
              _buildMissionCard(m, userData, onGo: _missionGoAction(m.id))),
    ]);
  }

  // Banner shown when streak is in grace period or expired
  Widget _buildStreakBanner() {
    if (_streakGrace == 0) return const SizedBox.shrink();
    final Color bgColor;
    final IconData icon;
    final String text;
    Widget? action;
    if (_streakGrace == 1) {
      bgColor = const Color(0xFFFFF59D);
      icon = Icons.warning_amber_rounded;
      text = '⚠️ คุณรอดตัวไป! บันทึกวันนี้เพื่อรักษา streak';
    } else if (_streakGrace == 2) {
      bgColor = const Color(0xFFFFB74D);
      icon = Icons.error_outline_rounded;
      text = '🚨 วันสุดท้าย! รักษา streak ก่อนจะหาย';
    } else {
      bgColor = const Color(0xFFEF9A9A);
      icon = Icons.healing_rounded;
      text = '💔 Streak ขาดแล้ว — กู้คืนได้ที่ร้านรางวัล';
      action = TextButton(
        onPressed: _openRewardShopForRepair,
        child: const Text('กู้คืน', style: TextStyle(color: Colors.red)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.black87, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ),
        if (action != null) action,
      ]),
    );
  }

  void _openRewardShopForRepair() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RewardShopScreen(
          userId: ref.read(userDataProvider).userId,
          currentGems: _gems,
          tierIdx: _activeTierIdx,
          streakGrace: _streakGrace,
          onGemsUpdated: (g) => setState(() => _gems = g),
          onStreakRepaired: () async {
            await StreakService.repairStreak();
            if (mounted) setState(() => _streakGrace = 0);
          },
        ),
      ),
    );
  }

  Widget _buildProgressGroupCard({
    required String groupId,
    VoidCallback? onGo,
    required String title,
    required int current,
    required int total,
    required String unit,
    required List<_Mission> milestones,
    required UserData userData,
    required Color color,
    String? extraInfo,
  }) {
    final progress = (current / total).clamp(0.0, 1.0);
    final allClaimed = milestones.every((m) => _isMissionClaimed(m.id));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allClaimed
              ? color.withOpacity(0.3)
              : progress > 0
                  ? color.withOpacity(0.4)
                  : Colors.grey.shade200,
          width: progress > 0 && !allClaimed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontFamily: 'Inter')),
            ),
            if (onGo != null && !allClaimed) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onGo,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$current / $total $unit',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontFamily: 'Inter')),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: color),
                  ]),
                ),
              ),
            ] else
              Text('$current / $total $unit',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: 'Inter')),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade100,
              color: color,
              minHeight: 10,
            ),
          ),
          if (extraInfo != null) ...[
            const SizedBox(height: 6),
            Text(extraInfo,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0277BD),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter')),
          ],
          const SizedBox(height: 10),
          ...milestones.map((m) {
            final claimed = _isMissionClaimed(m.id);
            final canDo = m.autoCheck(userData);
            final xp = m.baseXp;
            final gems = m.baseGems;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(
                  claimed
                      ? Icons.check_circle_rounded
                      : canDo
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  size: 17,
                  color: claimed
                      ? color
                      : canDo
                          ? color.withOpacity(0.7)
                          : Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Inter',
                          color: claimed
                              ? Colors.grey.shade400
                              : canDo
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                          decoration:
                              claimed ? TextDecoration.lineThrough : null)),
                ),
                if (claimed)
                  Text('+$gems 🌾',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'Inter'))
                else if (canDo)
                  GestureDetector(
                    onTap: () => _claimMission(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.35), blurRadius: 6)
                        ],
                      ),
                      child: Text('+$xp XP  +$gems 🌾',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  Text('+$gems 🌾',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade300,
                          fontFamily: 'Inter')),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMissionCard(_Mission m, UserData userData,
      {VoidCallback? onGo}) {
    final claimed = _isMissionClaimed(m.id);
    final canDo = m.autoCheck(userData);
    final xp = m.baseXp;
    final gems = m.baseGems;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? _primary.withOpacity(0.25)
              : canDo
                  ? _primary.withOpacity(0.5)
                  : Colors.grey.shade200,
          width: canDo && !claimed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: claimed
                ? _primary.withOpacity(0.08)
                : canDo
                    ? _primary.withOpacity(0.1)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Text(m.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title,
                style: TextStyle(
                    color: claimed ? Colors.grey.shade500 : Colors.black87,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    decoration: claimed ? TextDecoration.lineThrough : null)),
            Text(m.desc,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            if (onGo != null && !claimed) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onGo,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('ไปทำเลย',
                      style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter')),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: Color(0xFF1565C0)),
                ]),
              ),
            ]
          ]),
        ),
        const SizedBox(width: 10),
        if (claimed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('✅ +$xp XP',
                  style: const TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600)),
              Text('+$gems 🌾',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontFamily: 'Inter')),
            ]),
          )
        else if (canDo)
          GestureDetector(
            onTap: () => _claimMission(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 8)
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('+$xp XP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        fontSize: 12)),
                Text('+$gems 🌾',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontFamily: 'Inter')),
              ]),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('+$xp XP',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontFamily: 'Inter')),
              Text('+$gems 🌾',
                  style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 10,
                      fontFamily: 'Inter')),
            ]),
          ),
      ]),
    );
  }

  // ── Badges — 4 types (Achievement / Streak / Skill / Social) ──
  static const _badgeInfo = {
    'badge_newbie': ('🔰', 'มือใหม่', 'Achievement'),
    'badge_grower': ('🏅', 'ผู้มุ่งมั่น', 'Achievement'),
    'badge_champion': ('✨', 'Champion', 'Achievement'),
  };

  Widget _buildBadgesSection() {
    final earned = _badgeInfo.entries
        .where((e) => _claimedAchievements.contains(e.key))
        .toList();
    if (earned.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🏆 แบดจ์ที่ได้รับ',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontFamily: 'Inter')),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: earned.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(color: _primary.withOpacity(0.1), blurRadius: 8)
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.value.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value.$2,
                    style: const TextStyle(
                        color: _primary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(e.value.$3,
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                        fontFamily: 'Inter')),
              ]),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Tier-Up Dialog — animated celebration popup
//  - Scale + fade entrance (elasticOut 600ms)
//  - Pulse animation on tier emoji
//  - Auto-dismiss after 5 seconds
// ─────────────────────────────────────────────────────────
class _TierUpDialog extends StatefulWidget {
  final _Tier tier;
  const _TierUpDialog({required this.tier});

  @override
  State<_TierUpDialog> createState() => _TierUpDialogState();
}

class _TierUpDialogState extends State<_TierUpDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _pulse;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _scale = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward();
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      t.color,
                      Color.lerp(t.color, Colors.black, 0.4)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: t.color.withOpacity(0.55),
                        blurRadius: 30,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🎉 ยินดีด้วย!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  const Text(
                    'คุณเลื่อนขั้นอยู่ในระดับ',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  Text(t.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter')),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(14)),
                    child: Text(t.perks,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: t.color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('🚀 สุดยอด!',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              fontFamily: 'Inter')),
                    ),
                  ),
                ]),
              ),
              Positioned(
                top: -42,
                child: ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: t.color.withOpacity(0.45),
                            blurRadius: 22,
                            spreadRadius: 2),
                      ],
                    ),
                    child: Center(
                        child: Text(t.emoji,
                            style: const TextStyle(fontSize: 52))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  First-Time Tier Badge Dialog — lifetime achievement popup
// ─────────────────────────────────────────────────────────
class _FirstTimeBadgeDialog extends StatelessWidget {
  final _Tier tier;
  final int rewardGems;
  const _FirstTimeBadgeDialog({required this.tier, required this.rewardGems});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: tier.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Text(tier.emoji, style: const TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          const Text('🏆 Achievement ปลดล็อก!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  fontFamily: 'Inter')),
          const SizedBox(height: 6),
          Text('ครั้งแรกที่ถึง ${tier.name}',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontFamily: 'Inter')),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🎁 รางวัล +$rewardGems 🌾',
                style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter')),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: tier.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('เก็บใส่ Trophy Room',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Weekly Reward Dialog — shown on Monday rollover
// ─────────────────────────────────────────────────────────
class _WeeklyRewardDialog extends StatefulWidget {
  final _Tier tier;
  final int? rank;
  final int totalReward;
  const _WeeklyRewardDialog(
      {required this.tier, required this.rank, required this.totalReward});

  @override
  State<_WeeklyRewardDialog> createState() => _WeeklyRewardDialogState();
}

class _WeeklyRewardDialogState extends State<_WeeklyRewardDialog> {
  Timer? _dismissTimer;
  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    final rankText =
        widget.rank != null ? 'อันดับ #${widget.rank}' : 'ยังไม่จัดอันดับ';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆 สรุปสัปดาห์ที่แล้ว',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  fontFamily: 'Inter')),
          const SizedBox(height: 16),
          Text(t.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text('คุณจบสัปดาห์ที่ ${t.name}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(rankText,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontFamily: 'Inter')),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🎁 ได้รับ +${widget.totalReward} 🌾',
                style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter')),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: t.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('เริ่มสัปดาห์ใหม่',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            ),
          ),
        ]),
      ),
    );
  }
}
