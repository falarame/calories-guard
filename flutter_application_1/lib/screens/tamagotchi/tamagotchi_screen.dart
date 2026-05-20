import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';
import '/screens/tamagotchi/reward_shop_screen.dart';
import '/services/api_client.dart';
import '/services/health_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Tier System â€” 5 levels (Octalysis: Development & Accomplishment)
//  Based on research: tier thresholds designed to be achievable
//  but challenging (British Journal of Educational Technology, 2024)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      name: 'à¹€à¸¡à¸¥à¹‡à¸”à¸žà¸±à¸™à¸˜à¸¸à¹Œ',
      emoji: 'ðŸŒ±',
      minXp: 0,
      xpBonus: 0.00,
      gemsBonus: 0.00,
      color: Color(0xFF78909C),
      perks: 'à¹€à¸£à¸´à¹ˆà¸¡à¸•à¹‰à¸™'),
  _Tier(
      name: 'à¸•à¹‰à¸™à¸à¸¥à¹‰à¸²',
      emoji: 'ðŸŒ¿',
      minXp: 1000,
      xpBonus: 0.10,
      gemsBonus: 0.10,
      color: Color(0xFF43A047),
      perks: '+10% XP & ðŸŒ¾'),
  _Tier(
      name: 'à¸­à¸­à¸à¸£à¸§à¸‡',
      emoji: 'ðŸŒ¾',
      minXp: 5000,
      xpBonus: 0.25,
      gemsBonus: 0.25,
      color: Color(0xFF26A69A),
      perks: '+25% XP & ðŸŒ¾'),
  _Tier(
      name: 'à¸‚à¹‰à¸²à¸§à¸ªà¸¸à¸',
      emoji: 'ðŸš',
      minXp: 15000,
      xpBonus: 0.50,
      gemsBonus: 0.50,
      color: Color(0xFFFFB300),
      perks: '+50% XP & ðŸŒ¾'),
  _Tier(
      name: 'à¸‚à¹‰à¸²à¸§à¸—à¸­à¸‡',
      emoji: 'âœ¨',
      minXp: 50000,
      xpBonus: 1.00,
      gemsBonus: 1.00,
      color: Color(0xFFAB47BC),
      perks: '+100% XP & ðŸŒ¾'),
];

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Streak Multiplier â€” Loss Aversion mechanic (Octalysis CD#8)
//  Locke & Latham (2002): challenging-but-achievable goals
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
double _streakMult(int streak) {
  if (streak >= 30) return 3.0;
  if (streak >= 14) return 2.5;
  if (streak >= 7) return 2.0;
  if (streak >= 3) return 1.5;
  return 1.0;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Mission Model â€” dual reward (XP + Gems)
//  XP = permanent, determines tier
//  Gems = spendable currency, expire 30 days
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Screen
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  List<_Mission> get _missions => [
        _Mission(
            id: 'check_in',
            emoji: 'ðŸŒ±',
            title: 'à¹€à¸Šà¹‡à¸à¸­à¸´à¸™à¸§à¸±à¸™à¸™à¸µà¹‰',
            desc: 'à¹€à¸›à¸´à¸”à¹à¸­à¸›à¹€à¸žà¸·à¹ˆà¸­à¸£à¸±à¸š XP à¸›à¸£à¸°à¸ˆà¸³à¸§à¸±à¸™',
            baseXp: 10,
            baseGems: 1,
            autoCheck: (_) => true),
        _Mission(
            id: 'log_meal',
            emoji: 'ðŸ±',
            title: 'à¸šà¸±à¸™à¸—à¸¶à¸à¸¡à¸·à¹‰à¸­à¸­à¸²à¸«à¸²à¸£',
            desc: 'à¸šà¸±à¸™à¸—à¸¶à¸à¸­à¸²à¸«à¸²à¸£à¸­à¸¢à¹ˆà¸²à¸‡à¸™à¹‰à¸­à¸¢ 1 à¸¡à¸·à¹‰à¸­à¸§à¸±à¸™à¸™à¸µà¹‰',
            baseXp: 25,
            baseGems: 3,
            autoCheck: (u) => u.consumedCalories > 0),
        _Mission(
            id: 'drink_water',
            emoji: 'ðŸ’§',
            title: 'à¸”à¸·à¹ˆà¸¡à¸™à¹‰à¸³à¸„à¸£à¸š 6 à¹à¸à¹‰à¸§',
            desc: 'à¸”à¸·à¹ˆà¸¡à¸™à¹‰à¸³à¸­à¸¢à¹ˆà¸²à¸‡à¸™à¹‰à¸­à¸¢ 6 à¹à¸à¹‰à¸§ (1,500 ml) à¸•à¹ˆà¸­à¸§à¸±à¸™',
            baseXp: 30,
            baseGems: 3,
            autoCheck: (_) => _waterGlasses >= 6),
        _Mission(
            id: 'log_exercise',
            emoji: 'ðŸƒ',
            title: 'à¸šà¸±à¸™à¸—à¸¶à¸à¸­à¸­à¸à¸à¸³à¸¥à¸±à¸‡à¸à¸²à¸¢',
            desc: 'à¸šà¸±à¸™à¸—à¸¶à¸ exercise à¸­à¸¢à¹ˆà¸²à¸‡à¸™à¹‰à¸­à¸¢ 1 à¸„à¸£à¸±à¹‰à¸‡à¸§à¸±à¸™à¸™à¸µà¹‰',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (u) => u.dailyCaloriesBurned > 0),
        _Mission(
            id: 'walk_3k',
            emoji: 'ðŸ‘Ÿ',
            title: 'à¹€à¸”à¸´à¸™ 3,000 à¸à¹‰à¸²à¸§',
            desc: 'à¸ªà¸°à¸ªà¸¡à¸à¹‰à¸²à¸§à¹€à¸”à¸´à¸™à¸ˆà¸²à¸ IMU/Health Connect à¸„à¸£à¸š 3,000 à¸à¹‰à¸²à¸§à¸•à¹ˆà¸­à¸§à¸±à¸™',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (_) => _steps >= 3000),
        _Mission(
            id: 'walk_8k',
            emoji: 'ðŸš¶',
            title: 'à¹€à¸”à¸´à¸™ 8,000 à¸à¹‰à¸²à¸§',
            desc: 'à¸ªà¸°à¸ªà¸¡à¸à¹‰à¸²à¸§à¹€à¸”à¸´à¸™à¸ˆà¸²à¸ IMU/Health Connect à¸„à¸£à¸š 8,000 à¸à¹‰à¸²à¸§à¸•à¹ˆà¸­à¸§à¸±à¸™',
            baseXp: 80,
            baseGems: 8,
            autoCheck: (_) => _steps >= 8000),
        _Mission(
            id: 'hit_calories',
            emoji: 'ðŸŽ¯',
            title: 'à¹à¸„à¸¥à¸­à¸£à¸µà¹ˆà¸•à¸²à¸¡à¹€à¸›à¹‰à¸²',
            desc: 'à¹à¸„à¸¥à¸­à¸£à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¹ƒà¸™à¸Šà¹ˆà¸§à¸‡ 80â€“110% à¸‚à¸­à¸‡à¹€à¸›à¹‰à¸²',
            baseXp: 75,
            baseGems: 8,
            autoCheck: (u) {
              if (u.targetCalories <= 0) return false;
              final r = u.consumedCalories / u.targetCalories;
              return r >= 0.8 && r <= 1.1;
            }),
        _Mission(
            id: 'hit_all_macros',
            emoji: 'ðŸŒ¿',
            title: 'à¸„à¸£à¸šà¸•à¸²à¸¡à¹‚à¸ à¸Šà¸™à¸²à¸à¸²à¸£',
            desc: 'à¹‚à¸›à¸£à¸•à¸µà¸™ à¸„à¸²à¸£à¹Œà¸š à¹„à¸‚à¸¡à¸±à¸™ à¸„à¸£à¸šà¸•à¸²à¸¡à¹€à¸›à¹‰à¸²à¸—à¸±à¹‰à¸‡à¸«à¸¡à¸”',
            baseXp: 100,
            baseGems: 10,
            autoCheck: (u) =>
                u.targetProtein > 0 &&
                u.consumedProtein >= u.targetProtein &&
                u.targetCarbs > 0 &&
                u.consumedCarbs >= u.targetCarbs &&
                u.targetFat > 0 &&
                u.consumedFat >= u.targetFat),
        _Mission(
            id: 'log_weight',
            emoji: 'âš–ï¸',
            title: 'à¸Šà¸±à¹ˆà¸‡à¸™à¹‰à¸³à¸«à¸™à¸±à¸à¸§à¸±à¸™à¸™à¸µà¹‰',
            desc: 'à¸šà¸±à¸™à¸—à¸¶à¸à¸™à¹‰à¸³à¸«à¸™à¸±à¸à¹€à¸žà¸·à¹ˆà¸­à¸•à¸´à¸”à¸•à¸²à¸¡à¸„à¸§à¸²à¸¡à¸„à¸·à¸šà¸«à¸™à¹‰à¸²à¸‚à¸­à¸‡à¸•à¸±à¸§à¹€à¸­à¸‡',
            baseXp: 40,
            baseGems: 4,
            autoCheck: (_) => _loggedWeightToday),
        _Mission(
            id: 'streak_3',
            emoji: 'ðŸ”¥',
            title: 'à¹ƒà¸Šà¹‰à¹à¸­à¸›à¸•à¹ˆà¸­à¹€à¸™à¸·à¹ˆà¸­à¸‡ 3 à¸§à¸±à¸™',
            desc: 'à¸šà¸±à¸™à¸—à¸¶à¸à¸ªà¸¸à¸‚à¸ à¸²à¸žà¸•à¹ˆà¸­à¹€à¸™à¸·à¹ˆà¸­à¸‡à¸­à¸¢à¹ˆà¸²à¸‡à¸™à¹‰à¸­à¸¢ 3 à¸§à¸±à¸™',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (u) => u.currentStreak >= 3),
      ];

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF1565C0);

  int get _activeTierIdx => _tierIdx.clamp(0, _tiers.length - 1);

  // XP earned = baseXp Ã— (1 + tierBonus) Ã— streakMultiplier
  int _calcXp(_Mission m, int streak) {
    final bonus = 1.0 + _tiers[_activeTierIdx].xpBonus;
    return (m.baseXp * bonus * _streakMult(streak)).round();
  }

  // Gems earned = baseGems Ã— (1 + tierGemsBonus) Ã— streakMultiplier Ã— weekendBonus
  // Weekend Harvest: Sat/Sun â†’ Ã—1.5 gems
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
        final wlogRes = await ApiClient().get('/users/$uid/weight_logs');
        if (wlogRes.statusCode == 200) {
          final wList = jsonDecode(wlogRes.body) as List;
          if (mounted) {
            setState(() =>
                _loggedWeightToday = wList.any((e) => e['date'] == today));
          }
        }
      } catch (_) {}
      try {
        final summary =
            await HealthService.fetchActivitySummary(DateTime.now());
        if (mounted) setState(() => _steps = summary.steps);
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
      setState(() {
        _xp = xp;
        _gems = gems;
        _tierIdx = tier;
        _claimedToday = claimed;
        _claimedBadges = updatedBadges;
      });
    }
  }

  // Variable reward: 20% chance of Ã—2 Gems (Octalysis CD#7 Unpredictability / dopamine loop)
  Future<void> _claimMission(_Mission m, int streak) async {
    if (_claimedToday.contains(m.id)) return;
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();

    final earnedXp = _calcXp(m, streak);
    final isBonus = math.Random().nextDouble() < 0.20;
    final baseEarnedGems = _calcGems(m, streak);
    final earnedGems = isBonus ? baseEarnedGems * 2 : baseEarnedGems;

    final newXp = _xp + earnedXp;
    int newGems = _gems + earnedGems;
    final newClaimed = {..._claimedToday, m.id};
    final newTier = (_tiers.lastIndexWhere((t) => newXp >= t.minXp))
        .clamp(0, _tiers.length - 1);
    final oldTierIdx = _tierIdx;
    final newMaxTier = newTier > _tierIdx ? newTier : _tierIdx;

    // Perfect Day: all missions done â†’ +15 ðŸ’Ž bonus
    final allDone = _missions.every((ms) => newClaimed.contains(ms.id));
    if (allDone) newGems += 15;

    // Exercise Combo: log_exercise + any walk mission done same day â†’ +5 ðŸ’Ž
    final hasExercise = newClaimed.contains('log_exercise');
    final hasWalk =
        newClaimed.contains('walk_3k') || newClaimed.contains('walk_8k');
    final comboJustCompleted = (m.id == 'log_exercise' && hasWalk) ||
        ((m.id == 'walk_3k' || m.id == 'walk_8k') && hasExercise);
    if (comboJustCompleted) newGems += 5;

    await prefs.setInt(_xpKey(uid), newXp);
    await prefs.setInt(_gemsKey(uid), newGems);
    await prefs.setStringList(_claimedKey(uid), newClaimed.toList());
    if (newMaxTier > _tierIdx) await prefs.setInt(_tierKey(uid), newMaxTier);

    setState(() {
      _xp = newXp;
      _gems = newGems;
      _tierIdx = newMaxTier;
      _claimedToday = newClaimed;
    });

    _syncToBackend(newXp, newGems, newMaxTier);

    if (mounted) {
      final extra = isBonus ? '  ðŸŽ‰ à¹‚à¸Šà¸„à¸”à¸µ! ðŸŒ¾Ã—2' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +$earnedXp XP  +$earnedGems ðŸŒ¾$extra'),
        backgroundColor: _tiers[newMaxTier].color,
        duration: const Duration(seconds: 2),
      ));

      // Exercise Combo notification
      if (comboJustCompleted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('ðŸŒ¾ Exercise Combo! à¸­à¸­à¸à¸à¸³à¸¥à¸±à¸‡à¸à¸²à¸¢ + à¹€à¸”à¸´à¸™ â†’ +5 ðŸŒ¾ à¹‚à¸šà¸™à¸±à¸ª!'),
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
            content: Text('ðŸŒŸ Perfect Day! à¸—à¸³à¸„à¸£à¸šà¸—à¸¸à¸à¸ à¸²à¸£à¸à¸´à¸ˆ â†’ +15 ðŸŒ± à¹‚à¸šà¸™à¸±à¸ª!'),
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
        title: const Text('à¹„à¸£à¹ˆà¸‚à¹‰à¸²à¸§à¸‚à¸­à¸‡à¸‰à¸±à¸™',
            style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'à¹à¸¥à¸à¸£à¸²à¸‡à¸§à¸±à¸¥',
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

  // â”€â”€ Hero Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              Text('${tier.perks} â€¢ CaloriesGuard',
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
                'à¸­à¸µà¸ ${nextTier.minXp - _xp} XP â†’ ${nextTier.emoji} ${nextTier.name}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontFamily: 'Inter')),
          ]),
        ] else ...[
          const SizedBox(height: 16),
          const Text('âšœï¸ Legend â€” à¸£à¸°à¸”à¸±à¸šà¸ªà¸¹à¸‡à¸ªà¸¸à¸”!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // â”€â”€ Currency Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCurrencyRow(int streak) {
    final mult = _streakMult(streak);
    return Row(children: [
      Expanded(
          child: _currencyCard(
              label: 'XP à¸ªà¸°à¸ªà¸¡',
              value: '$_xp',
              sub: 'à¹ƒà¸Šà¹‰à¸‚à¸¶à¹‰à¸™ Tier',
              color: _primary)),
      const SizedBox(width: 10),
      Expanded(
          child: _currencyCard(
              label: 'à¹€à¸¡à¸¥à¹‡à¸”à¸‚à¹‰à¸²à¸§ ðŸŒ¾',
              value: '$_gems',
              sub: 'à¹ƒà¸Šà¹‰à¹à¸¥à¸à¸£à¸²à¸‡à¸§à¸±à¸¥',
              color: const Color(0xFF2E7D32),
              warn: _gems > 0 ? 'à¸«à¸¡à¸”à¸­à¸²à¸¢à¸¸ 30 à¸§à¸±à¸™' : null)),
      const SizedBox(width: 10),
      Expanded(
          child: _currencyCard(
        label: 'Streak ðŸ”¥',
        value: '$streak à¸§à¸±à¸™',
        sub: mult > 1.0 ? 'XP Ã—${mult.toStringAsFixed(1)}' : 'à¸—à¸³à¸•à¹ˆà¸­ 3 à¸§à¸±à¸™',
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

  // â”€â”€ Tier Roadmap â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        const Text('à¸‚à¸±à¹‰à¸™à¸à¸²à¸£à¹€à¸•à¸´à¸šà¹‚à¸•à¸‚à¸­à¸‡à¹„à¸£à¹ˆà¸‚à¹‰à¸²à¸§',
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
                Text(
                    t.minXp >= 1000 ? '${t.minXp ~/ 1000}k' : '${t.minXp}',
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

  // â”€â”€ Missions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMissionsSection(UserData userData, int streak) {
    final mult = _streakMult(streak);
    final tierBonus = _tiers[_activeTierIdx].xpBonus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('à¸ à¸²à¸£à¸à¸´à¸ˆà¸›à¸£à¸°à¸ˆà¸³à¸§à¸±à¸™',
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
                if (mult > 1.0) 'ðŸ”¥ Ã—${mult.toStringAsFixed(1)}',
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
      Text('ðŸ’¡ 20% à¹‚à¸­à¸à¸²à¸ªà¹„à¸”à¹‰à¹€à¸¡à¸¥à¹‡à¸”à¸‚à¹‰à¸²à¸§ à¹‚à¸šà¸™à¸±à¸ª Ã—2  (Octalysis Variable Reward)',
          style: TextStyle(
              color: Colors.grey.shade400, fontSize: 10, fontFamily: 'Inter')),
      const SizedBox(height: 12),
      ..._missions.map((m) => _buildMissionCard(m, userData, streak)),
    ]);
  }

  Widget _buildMissionCard(_Mission m, UserData userData, int streak) {
    final claimed = _claimedToday.contains(m.id);
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
              Text('âœ… +$xp XP',
                  style: const TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600)),
              Text('+$gems ðŸŒ¾',
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
                Text('+$gems ðŸŒ¾',
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
              Text('+$gems ðŸŒ¾',
                  style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 10,
                      fontFamily: 'Inter')),
            ]),
          ),
      ]),
    );
  }

  // â”€â”€ Badges â€” 4 types (Achievement / Streak / Skill / Social) â”€â”€
  static const _badgeInfo = {
    'badge_newbie': ('ðŸ”°', 'à¸¡à¸·à¸­à¹ƒà¸«à¸¡à¹ˆ', 'Achievement'),
    'badge_grower': ('ðŸ…', 'à¸œà¸¹à¹‰à¸¡à¸¸à¹ˆà¸‡à¸¡à¸±à¹ˆà¸™', 'Achievement'),
    'badge_champion': ('âœ¨', 'Champion', 'Achievement'),
  };

  Widget _buildBadgesSection() {
    final earned = _badgeInfo.entries
        .where((e) => _claimedBadges.contains(e.key))
        .toList();
    if (earned.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ðŸ† à¹à¸šà¸”à¸ˆà¹Œà¸—à¸µà¹ˆà¹„à¸”à¹‰à¸£à¸±à¸š',
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
