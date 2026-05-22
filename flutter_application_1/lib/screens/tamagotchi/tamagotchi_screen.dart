import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';
import '/screens/tamagotchi/reward_shop_screen.dart';
import '/services/api_client.dart';
import '/services/health_service.dart';
import '/services/tamagotchi_action_logger.dart';
import '/screens/weight/weight_chart_screen.dart';
import '/screens/community/friends_screen.dart';

// ─────────────────────────────────────────────────────────
//  Tier System — 5 levels (Octalysis: Development & Accomplishment)
//  Based on research: tier thresholds designed to be achievable
//  but challenging (British Journal of Educational Technology, 2024)
// ─────────────────────────────────────────────────────────
class _Tier {
  final String name;
  final String emoji;
  final int minXp;
  final double xpBonus; // additive XP bonus (0.0 = +0%, 1.0 = +100%)
  final double gemsBonus; // additive Gems bonus per mission
  final Color color;
  final String perks;
  const _Tier({
    required this.name,
    required this.emoji,
    required this.minXp,
    required this.xpBonus,
    required this.gemsBonus,
    required this.color,
    required this.perks,
  });
}

const _tiers = [
  _Tier(
      name: 'เมล็ดพันธุ์',
      emoji: '🌱',
      minXp: 0,
      xpBonus: 0.00,
      gemsBonus: 0.00,
      color: Color(0xFF78909C),
      perks: 'เริ่มต้น'),
  _Tier(
      name: 'ต้นกล้า',
      emoji: '🌿',
      minXp: 1000,
      xpBonus: 0.10,
      gemsBonus: 0.10,
      color: Color(0xFF43A047),
      perks: '+10% XP & 🌾'),
  _Tier(
      name: 'ออกรวง',
      emoji: '🌾',
      minXp: 5000,
      xpBonus: 0.25,
      gemsBonus: 0.25,
      color: Color(0xFF26A69A),
      perks: '+25% XP & 🌾'),
  _Tier(
      name: 'ข้าวสุก',
      emoji: '🍚',
      minXp: 15000,
      xpBonus: 0.50,
      gemsBonus: 0.50,
      color: Color(0xFFFFB300),
      perks: '+50% XP & 🌾'),
  _Tier(
      name: 'ข้าวทอง',
      emoji: '✨',
      minXp: 50000,
      xpBonus: 1.00,
      gemsBonus: 1.00,
      color: Color(0xFFAB47BC),
      perks: '+100% XP & 🌾'),
];

// ─────────────────────────────────────────────────────────
//  Streak Multiplier — Loss Aversion mechanic (Octalysis CD#8)
//  Locke & Latham (2002): challenging-but-achievable goals
// ─────────────────────────────────────────────────────────
double _streakMult(int streak) {
  if (streak >= 30) return 3.0;
  if (streak >= 14) return 2.5;
  if (streak >= 7) return 2.0;
  if (streak >= 3) return 1.5;
  return 1.0;
}

// ─────────────────────────────────────────────────────────
//  Mission Model — dual reward (XP + Gems)
//  XP = permanent, determines tier
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

class _TamagotchiScreenState extends ConsumerState<TamagotchiScreen> {
  int _xp = 0;
  int _gems = 0;
  int _tierIdx = 0;
  Set<String> _claimedToday = {};
  Set<String> _claimedBadges = {};
  int _waterGlasses = 0;
  int _steps = 0;
  bool _loggedWeightToday = false;
  bool _weightChanged1kg = false;
  int _todayMealCount = 0;
  int _cycleDay = 0;
  int _cycleNum = 0;
  int _suggestCountToday = 0;
  bool _reviewedToday = false;
  int _pendingInviteRewards = 0;
  int _currentInviteeCount = 0;

  bool _isStreakMission(String id) =>
      id == 'streak_3' || id == 'streak_5' || id == 'streak_7';

  bool _isMissionClaimed(String id) {
    if (_isStreakMission(id)) {
      return _claimedBadges.contains('${id}_c$_cycleNum');
    }
    return _claimedToday.contains(id);
  }

  VoidCallback? _missionGoAction(String id) {
    void goRecord() {
      Navigator.pop(context);
      ref.read(navIndexProvider.notifier).state = 1;
    }
    void goRecommend() {
      Navigator.pop(context);
      ref.read(navIndexProvider.notifier).state = 2;
    }
    if (id.startsWith('log_meal_') ||
        id.startsWith('drink_water_') ||
        id == 'hit_calories' ||
        id == 'hit_protein' ||
        id == 'log_exercise') return goRecord;
    if (id.startsWith('suggest_food_') || id == 'review_food') return goRecommend;
    if (id == 'weight_change') {
      return () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const WeightChartScreen()));
    }
    if (id == 'invite_friend') {
      return () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const FriendsScreen()));
    }
    return null;
  }

  List<_Mission> get _missions => [
        _Mission(
            id: 'check_in',
            emoji: '🌱',
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
            baseXp: 10,
            baseGems: 5,
            autoCheck: (_) => _todayMealCount >= 1),
        _Mission(
            id: 'log_meal_2',
            emoji: '🍽️',
            title: 'บันทึกอาหาร 2 มื้อ',
            desc: 'บันทึกอาหารวันนี้อย่างน้อย 2 มื้อ',
            baseXp: 20,
            baseGems: 10,
            autoCheck: (_) => _todayMealCount >= 2),
        _Mission(
            id: 'log_meal_3',
            emoji: '🥢',
            title: 'บันทึกอาหาร 3 มื้อ',
            desc: 'บันทึกอาหารวันนี้อย่างน้อย 3 มื้อ',
            baseXp: 30,
            baseGems: 15,
            autoCheck: (_) => _todayMealCount >= 3),
        _Mission(
            id: 'log_meal_4',
            emoji: '🌟',
            title: 'บันทึกอาหารครบ 4 มื้อ',
            desc: 'บันทึกอาหารครบทุกมื้อในวันนี้',
            baseXp: 40,
            baseGems: 20,
            autoCheck: (_) => _todayMealCount >= 4),
        _Mission(
            id: 'drink_water_2',
            emoji: '',
            title: 'ดื่มน้ำ 2 แก้ว',
            desc: 'ดื่มน้ำอย่างน้อย 2 แก้ว (500 ml) วันนี้',
            baseXp: 8,
            baseGems: 5,
            autoCheck: (_) => _waterGlasses >= 2),
        _Mission(
            id: 'drink_water_4',
            emoji: '',
            title: 'ดื่มน้ำ 4 แก้ว',
            desc: 'ดื่มน้ำอย่างน้อย 4 แก้ว (1,000 ml) วันนี้',
            baseXp: 15,
            baseGems: 10,
            autoCheck: (_) => _waterGlasses >= 4),
        _Mission(
            id: 'drink_water_6',
            emoji: '',
            title: 'ดื่มน้ำ 6 แก้ว',
            desc: 'ดื่มน้ำอย่างน้อย 6 แก้ว (1,500 ml) วันนี้',
            baseXp: 22,
            baseGems: 15,
            autoCheck: (_) => _waterGlasses >= 6),
        _Mission(
            id: 'drink_water_8',
            emoji: '',
            title: 'ดื่มน้ำครบ 8 แก้ว',
            desc: 'ดื่มน้ำครบ 8 แก้ว (2,000 ml) เป้าหมายวัน!',
            baseXp: 30,
            baseGems: 20,
            autoCheck: (_) => _waterGlasses >= 8),
        _Mission(
            id: 'hit_calories',
            emoji: '🎯',
            title: 'แคลอรี่ไม่เกินเป้า',
            desc: 'รับประทานแคลอรี่ไม่เกินเป้าหมายที่ตั้งไว้',
            baseXp: 75,
            baseGems: 30,
            autoCheck: (u) {
              if (u.targetCalories <= 0) return false;
              return u.consumedCalories > 0 &&
                  u.consumedCalories <= u.targetCalories;
            }),
        _Mission(
            id: 'hit_protein',
            emoji: '💪',
            title: 'โปรตีนครบตามเป้า',
            desc: 'รับโปรตีนครบตามเป้าหมายของวันนี้',
            baseXp: 40,
            baseGems: 15,
            autoCheck: (u) =>
                u.targetProtein > 0 && u.consumedProtein >= u.targetProtein),
        _Mission(
            id: 'log_exercise',
            emoji: '🏃',
            title: 'บันทึกออกกำลังกาย',
            desc: 'บันทึก exercise อย่างน้อย 1 ครั้งวันนี้',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (u) => u.dailyCaloriesBurned > 0),
        _Mission(
            id: 'walk_3k',
            emoji: '👟',
            title: 'เดิน 3,000 ก้าว',
            desc: 'สะสมก้าวเดินจาก IMU/Health Connect ครบ 3,000 ก้าวต่อวัน',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (_) => _steps >= 3000),
        _Mission(
            id: 'walk_8k',
            emoji: '🚶',
            title: 'เดิน 8,000 ก้าว',
            desc: 'สะสมก้าวเดินจาก IMU/Health Connect ครบ 8,000 ก้าวต่อวัน',
            baseXp: 80,
            baseGems: 8,
            autoCheck: (_) => _steps >= 8000),
        _Mission(
            id: 'weight_change',
            emoji: '⚖️',
            title: 'น้ำหนักเปลี่ยนแปลง 1 กก.',
            desc: 'บันทึกน้ำหนักวันนี้ และน้ำหนักลด/เพิ่ม ≥ 1 กก. จากครั้งก่อน',
            baseXp: 40,
            baseGems: 20,
            autoCheck: (_) => _loggedWeightToday && _weightChanged1kg),
        _Mission(
            id: 'suggest_food_1',
            emoji: '🍜',
            title: 'เพิ่มเมนูอาหารใหม่ 1 เมนู',
            desc: 'เสนอเมนูอาหารที่ยังไม่มีในระบบผ่านหน้าค้นหาอาหาร',
            baseXp: 20,
            baseGems: 10,
            autoCheck: (_) => _suggestCountToday >= 1),
        _Mission(
            id: 'suggest_food_2',
            emoji: '🍜🍜',
            title: 'เพิ่มเมนูอาหารใหม่ 2 เมนู',
            desc: 'เสนอเมนูอาหารใหม่ 2 เมนูในวันเดียวกัน',
            baseXp: 40,
            baseGems: 20,
            autoCheck: (_) => _suggestCountToday >= 2),
        _Mission(
            id: 'review_food',
            emoji: '⭐',
            title: 'รีวิวอาหาร',
            desc: 'ให้คะแนนและรีวิวเมนูอาหารวันนี้',
            baseXp: 10,
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
        _Mission(
            id: 'streak_3',
            emoji: '🔥',
            title: 'Login ต่อเนื่อง 3 วัน',
            desc: 'เข้าใช้แอปต่อเนื่อง 3 วันในรอบสัปดาห์นี้',
            baseXp: 50,
            baseGems: 10,
            autoCheck: (_) => _cycleDay >= 3),
        _Mission(
            id: 'streak_5',
            emoji: '🔥🔥',
            title: 'Login ต่อเนื่อง 5 วัน',
            desc: 'เข้าใช้แอปต่อเนื่อง 5 วันในรอบสัปดาห์นี้',
            baseXp: 75,
            baseGems: 15,
            autoCheck: (_) => _cycleDay >= 5),
        _Mission(
            id: 'streak_7',
            emoji: '⭐',
            title: 'Login ต่อเนื่อง 7 วัน',
            desc: 'ครบ 7 วันแล้ว — รีเซ็ตรอบใหม่!',
            baseXp: 100,
            baseGems: 20,
            autoCheck: (_) => _cycleDay == 7),
      ];

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF1565C0);

  int get _activeTierIdx => _tierIdx.clamp(0, _tiers.length - 1);

  // XP earned = baseXp × (1 + tierBonus) × streakMultiplier
  int _calcXp(_Mission m, int streak) {
    final bonus = 1.0 + _tiers[_activeTierIdx].xpBonus;
    return (m.baseXp * bonus * _streakMult(streak)).round();
  }

  // Gems earned = baseGems × (1 + tierGemsBonus) × streakMultiplier × weekendBonus
  // Weekend Harvest: Sat/Sun → ×1.5 gems
  int _calcGems(_Mission m, int streak) {
    final bonus = 1.0 + _tiers[_activeTierIdx].gemsBonus;
    final isWeekend =
        [DateTime.saturday, DateTime.sunday].contains(DateTime.now().weekday);
    final weekendMult = isWeekend ? 1.5 : 1.0;
    return (m.baseGems * bonus * _streakMult(streak) * weekendMult).round();
  }

  String _xpKey(int uid) =>
      'tama_points_$uid'; // keep old key for backward compat
  String _gemsKey(int uid) => 'tama_gems_$uid';
  String _tierKey(int uid) => 'tama_max_tier_$uid'; // keep old key
  String _badgesKey(int uid) => 'tama_rewards_claimed_$uid';
  String _claimedKey(int uid) {
    final n = DateTime.now();
    return 'tama_claimed_${uid}_${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();

    int xp = prefs.getInt(_xpKey(uid)) ?? 0;
    int gems = prefs.getInt(_gemsKey(uid)) ?? 0;
    int tier = prefs.getInt(_tierKey(uid)) ?? 0;
    final claimed = (prefs.getStringList(_claimedKey(uid)) ?? []).toSet();

    if (uid > 0) {
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      try {
        final waterRes = await ApiClient().get('/water_logs/$uid?date=$today');
        if (waterRes.statusCode == 200) {
          final wData = jsonDecode(waterRes.body);
          final ml = (wData['amount_ml'] as num?)?.toInt() ?? 0;
          if (mounted) {
            setState(() => _waterGlasses = (ml / 250).round().clamp(0, 20));
          }
        }
      } catch (_) {}
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
      } catch (_) {}
      try {
        final wlogRes = await ApiClient().get('/users/$uid/weight_logs');
        if (wlogRes.statusCode == 200) {
          final wList = jsonDecode(wlogRes.body) as List;
          final loggedToday = wList.any((e) => e['date'] == today);
          bool changed1kg = false;
          if (wList.length >= 2) {
            final latest = (wList.last['weight'] as num?)?.toDouble() ?? 0;
            final prev =
                (wList[wList.length - 2]['weight'] as num?)?.toDouble() ?? 0;
            changed1kg = (latest - prev).abs() >= 1.0;
          }
          if (mounted) {
            setState(() {
              _loggedWeightToday = loggedToday;
              _weightChanged1kg = changed1kg;
            });
          }
        }
      } catch (_) {}
      try {
        final summary =
            await HealthService.fetchActivitySummary(DateTime.now());
        if (mounted) setState(() => _steps = summary.steps);
      } catch (_) {}
      final sc = await TamagotchiActionLogger.getFoodSuggestionCount(uid);
      final rd = await TamagotchiActionLogger.getFoodReviewDone(uid);
      if (mounted) {
        setState(() {
          _suggestCountToday = sc;
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
      } catch (_) {}
      try {
        final res = await ApiClient().get('/users/$uid/tama-points');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final bXp = (data['tama_points'] as num?)?.toInt() ?? 0;
          final bTier = (data['tier_level'] as num?)?.toInt() ?? 0;
          final bGems = (data['gems'] as num?)?.toInt() ?? 0;
          final bBadges = (data['claimed_badges'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (bXp > xp) {
            xp = bXp;
            await prefs.setInt(_xpKey(uid), xp);
          }
          if (bTier > tier) {
            tier = bTier;
            await prefs.setInt(_tierKey(uid), tier);
          }
          if (bGems > gems) {
            gems = bGems;
            await prefs.setInt(_gemsKey(uid), gems);
          }
          if (bBadges.isNotEmpty) {
            await prefs.setStringList(_badgesKey(uid), bBadges);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      final updatedBadges =
          (prefs.getStringList(_badgesKey(uid)) ?? []).toSet();
      final streak = ref.read(userDataProvider).currentStreak;
      setState(() {
        _xp = xp;
        _gems = gems;
        _tierIdx = tier;
        _claimedToday = claimed;
        _claimedBadges = updatedBadges;
        _cycleDay = streak == 0 ? 0 : ((streak - 1) % 7) + 1;
        _cycleNum = streak == 0 ? 0 : (streak - 1) ~/ 7;
      });
    }
  }

  // Variable reward: 20% chance of ×2 Gems (Octalysis CD#7 Unpredictability / dopamine loop)
  Future<void> _claimMission(_Mission m, int streak) async {
    if (_isMissionClaimed(m.id)) return;
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();

    final int earnedXp;
    final bool isBonus;
    final int earnedGems;
    if (m.id == 'invite_friend') {
      earnedXp = 50 * _pendingInviteRewards;
      isBonus = false;
      earnedGems = 100 * _pendingInviteRewards;
    } else {
      earnedXp = _calcXp(m, streak);
      isBonus = math.Random().nextDouble() < 0.20;
      final baseEarnedGems = _calcGems(m, streak);
      earnedGems = isBonus ? baseEarnedGems * 2 : baseEarnedGems;
    }

    final newXp = _xp + earnedXp;
    int newGems = _gems + earnedGems;
    final newTier = (_tiers.lastIndexWhere((t) => newXp >= t.minXp))
        .clamp(0, _tiers.length - 1);
    final oldTierIdx = _tierIdx;
    final newMaxTier = newTier > _tierIdx ? newTier : _tierIdx;

    Set<String> newClaimed = {..._claimedToday};
    Set<String> newBadges = {..._claimedBadges};

    if (_isStreakMission(m.id)) {
      newBadges.add('${m.id}_c$_cycleNum');
      await prefs.setStringList(_badgesKey(uid), newBadges.toList());
    } else {
      newClaimed.add(m.id);
      await prefs.setStringList(_claimedKey(uid), newClaimed.toList());
    }

    // Perfect Day: all non-streak missions done → +15 💎 bonus
    final allDone = _missions
        .where((ms) => !_isStreakMission(ms.id))
        .every((ms) => newClaimed.contains(ms.id));
    if (allDone) newGems += 15;

    // Exercise Combo: log_exercise + any walk mission done same day → +5 💎
    final hasExercise = newClaimed.contains('log_exercise');
    final hasWalk =
        newClaimed.contains('walk_3k') || newClaimed.contains('walk_8k');
    final comboJustCompleted = (m.id == 'log_exercise' && hasWalk) ||
        ((m.id == 'walk_3k' || m.id == 'walk_8k') && hasExercise);
    if (comboJustCompleted) newGems += 5;

    await prefs.setInt(_xpKey(uid), newXp);
    await prefs.setInt(_gemsKey(uid), newGems);
    if (newMaxTier > _tierIdx) await prefs.setInt(_tierKey(uid), newMaxTier);
    if (m.id == 'invite_friend') {
      await prefs.setInt('tama_invitee_count_$uid', _currentInviteeCount);
    }

    setState(() {
      _xp = newXp;
      _gems = newGems;
      _tierIdx = newMaxTier;
      _claimedToday = newClaimed;
      _claimedBadges = newBadges;
    });

    _syncToBackend(newXp, newGems, newMaxTier);

    if (mounted) {
      final extra = isBonus ? '  🎉 โชคดี! 🌾×2' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +$earnedXp XP  +$earnedGems 🌾$extra'),
        backgroundColor: _tiers[newMaxTier].color,
        duration: const Duration(seconds: 2),
      ));

      // Exercise Combo notification
      if (comboJustCompleted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('🌾 Exercise Combo! ออกกำลังกาย + เดิน → +5 🌾 โบนัส!'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ));
        }
      }

      // Perfect Day notification
      if (allDone) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🌟 Perfect Day! ทำครบทุกภารกิจ → +15 🌱 โบนัส!'),
            backgroundColor: Color(0xFFE65100),
            duration: Duration(seconds: 3),
          ));
        }
      }

      // Tier-Up celebration
      if (newMaxTier > oldTierIdx) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _showTierUpDialog(newMaxTier);
      }
    }
  }

  void _showTierUpDialog(int tierIdx) {
    final t = _tiers[tierIdx];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.color, Color.lerp(t.color, Colors.black, 0.35)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text('\ud83c\udf89 TIER UP!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(t.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter')),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                    '\ud83d\ude80 \u0e2a\u0e38\u0e14\u0e22\u0e2d\u0e14!',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Inter')),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _syncToBackend(int xp, int gems, int tier) {
    if (!mounted) return;
    final uid = ref.read(userDataProvider).userId;
    if (uid <= 0) return;
    ApiClient().patch('/users/$uid/tama-points',
        body: {'tama_points': xp, 'gems': gems, 'tier_level': tier}).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final streak = userData.currentStreak;
    final tier = _tiers[_activeTierIdx];
    final nextTier =
        _activeTierIdx < _tiers.length - 1 ? _tiers[_activeTierIdx + 1] : null;
    final progress = nextTier != null
        ? ((_xp - tier.minXp) / (nextTier.minXp - tier.minXp)).clamp(0.0, 1.0)
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
            tooltip: 'แลกรางวัล',
            icon: const Icon(Icons.card_giftcard_rounded,
                color: _primary, size: 26),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RewardShopScreen(
                      userId: ref.read(userDataProvider).userId,
                      currentGems: _gems,
                      tierIdx: _tierIdx,
                      onGemsUpdated: (g) => setState(() => _gems = g),
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
          const SizedBox(height: 20),
          _buildTierRoadmap(),
          const SizedBox(height: 24),
          _buildMissionsSection(userData, streak),
          if (_claimedBadges.isNotEmpty) ...[
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
              Text('$_xp',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
              const Text('XP',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
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
                'อีก ${nextTier.minXp - _xp} XP → ${nextTier.emoji} ${nextTier.name}',
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
    final mult = _streakMult(streak);
    return Row(children: [
      Expanded(
          child: _currencyCard(
              label: 'XP สะสม',
              value: '$_xp',
              sub: 'ใช้ขึ้น Tier',
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
        sub: mult > 1.0 ? 'XP ×${mult.toStringAsFixed(1)}' : 'ทำต่อ 3 วัน',
        color: mult > 1.0 ? const Color(0xFFE65100) : Colors.grey.shade500,
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
            final isUnlocked = i <= _tierIdx;
            final isCurrent = i == _tierIdx;
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
  Widget _buildMissionsSection(UserData userData, int streak) {
    final mult = _streakMult(streak);
    final tierBonus = _tiers[_activeTierIdx].xpBonus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('ภารกิจประจำวัน',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Inter')),
        const Spacer(),
        if (mult > 1.0 || tierBonus > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              [
                if (mult > 1.0) '🔥 ×${mult.toStringAsFixed(1)}',
                if (tierBonus > 0) '+${(tierBonus * 100).toInt()}%'
              ].join(' '),
              style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text('💡 20% โอกาสได้เมล็ดข้าว โบนัส ×2  (Octalysis Variable Reward)',
          style: TextStyle(
              color: Colors.grey.shade400, fontSize: 10, fontFamily: 'Inter')),
      const SizedBox(height: 12),
      _buildProgressGroupCard(
        groupId: 'meal',
        onGo: () { Navigator.pop(context); ref.read(navIndexProvider.notifier).state = 1; },
        title: 'บันทึกมื้ออาหาร',
        current: _todayMealCount,
        total: 4,
        unit: 'มื้อ',
        milestones: _missions.where((m) => m.id.startsWith('log_meal_')).toList(),
        userData: userData,
        streak: streak,
        color: _primary,
      ),
      _buildProgressGroupCard(
        groupId: 'water',
        onGo: () { Navigator.pop(context); ref.read(navIndexProvider.notifier).state = 1; },
        title: 'ดื่มน้ำวันนี้',
        current: _waterGlasses,
        total: 8,
        unit: 'แก้ว',
        milestones: _missions.where((m) => m.id.startsWith('drink_water_')).toList(),
        userData: userData,
        streak: streak,
        color: const Color(0xFF0277BD),
      ),
      _buildProgressGroupCard(
        groupId: 'suggest',
        onGo: () { Navigator.pop(context); ref.read(navIndexProvider.notifier).state = 2; },
        title: 'เพิ่มเมนูอาหารใหม่',
        current: _suggestCountToday,
        total: 2,
        unit: 'เมนู',
        milestones: _missions.where((m) => m.id.startsWith('suggest_food_')).toList(),
        userData: userData,
        streak: streak,
        color: const Color(0xFF2E7D32),
      ),
      _buildProgressGroupCard(
        groupId: 'streak',
        title: 'Login ต่อเนื่อง',
        current: _cycleDay,
        total: 7,
        unit: 'วัน',
        milestones: _missions.where((m) => m.id.startsWith('streak_')).toList(),
        userData: userData,
        streak: streak,
        color: const Color(0xFFE65100),
      ),
      ..._missions
          .where((m) =>
              !m.id.startsWith('log_meal_') &&
              !m.id.startsWith('drink_water_') &&
              !m.id.startsWith('suggest_food_') &&
              !m.id.startsWith('streak_'))
          .map((m) => _buildMissionCard(m, userData, streak, onGo: _missionGoAction(m.id))),
    ]);
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
    required int streak,
    required Color color,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$current / $total $unit',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color),
                  ]),
                ),
              ),
            ]
            else
              Text('$current / $total $unit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
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
          const SizedBox(height: 10),
          ...milestones.map((m) {
            final claimed = _isMissionClaimed(m.id);
            final canDo = m.autoCheck(userData);
            final xp = _calcXp(m, streak);
            final gems = _calcGems(m, streak);
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
                          decoration: claimed ? TextDecoration.lineThrough : null)),
                ),
                if (claimed)
                  Text('+$gems 🌾',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Inter'))
                else if (canDo)
                  GestureDetector(
                    onTap: () => _claimMission(m, streak),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 6)],
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
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade300, fontFamily: 'Inter')),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMissionCard(_Mission m, UserData userData, int streak, {VoidCallback? onGo}) {
    final claimed = _isMissionClaimed(m.id);
    final canDo = m.autoCheck(userData);
    final xp = _calcXp(m, streak);
    final gems = _calcGems(m, streak);

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
            onTap: () => _claimMission(m, streak),
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
        .where((e) => _claimedBadges.contains(e.key))
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
