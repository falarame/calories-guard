import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';
import '/screens/tamagotchi/reward_shop_screen.dart';
import '/services/api_client.dart';

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
      name: 'Stone',
      emoji: '🪨',
      minXp: 0,
      xpBonus: 0.00,
      gemsBonus: 0.00,
      color: Color(0xFF78909C),
      perks: 'เริ่มต้น'),
  _Tier(
      name: 'Crystal',
      emoji: '🔷',
      minXp: 1000,
      xpBonus: 0.10,
      gemsBonus: 0.10,
      color: Color(0xFF42A5F5),
      perks: '+10% XP & 💎'),
  _Tier(
      name: 'Emerald',
      emoji: '💎',
      minXp: 5000,
      xpBonus: 0.25,
      gemsBonus: 0.25,
      color: Color(0xFF26A69A),
      perks: '+25% XP & 💎'),
  _Tier(
      name: 'Gold',
      emoji: '👑',
      minXp: 15000,
      xpBonus: 0.50,
      gemsBonus: 0.50,
      color: Color(0xFFFFB300),
      perks: '+50% XP & 💎'),
  _Tier(
      name: 'Legend',
      emoji: '⚜️',
      minXp: 50000,
      xpBonus: 1.00,
      gemsBonus: 1.00,
      color: Color(0xFFAB47BC),
      perks: '+100% XP & 💎'),
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
  bool _loggedWeightToday = false;

  List<_Mission> get _missions => [
        _Mission(
            id: 'check_in',
            emoji: '☀️',
            title: 'เช็กอินวันนี้',
            desc: 'เปิดแอปเพื่อรับ XP ประจำวัน',
            baseXp: 10,
            baseGems: 1,
            autoCheck: (_) => true),
        _Mission(
            id: 'log_meal',
            emoji: '🍱',
            title: 'บันทึกมื้ออาหาร',
            desc: 'บันทึกอาหารอย่างน้อย 1 มื้อวันนี้',
            baseXp: 25,
            baseGems: 3,
            autoCheck: (u) => u.consumedCalories > 0),
        _Mission(
            id: 'drink_water',
            emoji: '💧',
            title: 'ดื่มน้ำครบ 6 แก้ว',
            desc: 'ดื่มน้ำอย่างน้อย 6 แก้ว (1,500 ml) ต่อวัน',
            baseXp: 30,
            baseGems: 3,
            autoCheck: (_) => _waterGlasses >= 6),
        _Mission(
            id: 'log_exercise',
            emoji: '🏃',
            title: 'บันทึกออกกำลังกาย',
            desc: 'บันทึก exercise อย่างน้อย 1 ครั้งวันนี้',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (u) => u.dailyCaloriesBurned > 0),
        _Mission(
            id: 'hit_calories',
            emoji: '🎯',
            title: 'แคลอรี่ตามเป้า',
            desc: 'แคลอรี่อยู่ในช่วง 80–110% ของเป้า',
            baseXp: 75,
            baseGems: 8,
            autoCheck: (u) {
              if (u.targetCalories <= 0) return false;
              final r = u.consumedCalories / u.targetCalories;
              return r >= 0.8 && r <= 1.1;
            }),
        _Mission(
            id: 'hit_all_macros',
            emoji: '💪',
            title: 'ครบตามโภชนาการ',
            desc: 'โปรตีน คาร์บ ไขมัน ครบตามเป้าทั้งหมด',
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
            emoji: '⚖️',
            title: 'ชั่งน้ำหนักวันนี้',
            desc: 'บันทึกน้ำหนักเพื่อติดตามความคืบหน้าของตัวเอง',
            baseXp: 40,
            baseGems: 4,
            autoCheck: (_) => _loggedWeightToday),
        _Mission(
            id: 'streak_3',
            emoji: '🔥',
            title: 'ใช้แอปต่อเนื่อง 3 วัน',
            desc: 'บันทึกสุขภาพต่อเนื่องอย่างน้อย 3 วัน',
            baseXp: 50,
            baseGems: 5,
            autoCheck: (u) => u.currentStreak >= 3),
      ];

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF1565C0);

  int get _activeTierIdx => _tierIdx.clamp(0, _tiers.length - 1);

  // XP earned = baseXp × (1 + tierBonus) × streakMultiplier
  int _calcXp(_Mission m, int streak) {
    final bonus = 1.0 + _tiers[_activeTierIdx].xpBonus;
    return (m.baseXp * bonus * _streakMult(streak)).round();
  }

  // Gems earned = baseGems × (1 + tierGemsBonus)  [streak affects XP only]
  int _calcGems(_Mission m) {
    final bonus = 1.0 + _tiers[_activeTierIdx].gemsBonus;
    return (m.baseGems * bonus).round();
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

  // Variable reward: 20% chance of ×2 Gems (Octalysis CD#7 Unpredictability / dopamine loop)
  Future<void> _claimMission(_Mission m, int streak) async {
    if (_claimedToday.contains(m.id)) return;
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();

    final earnedXp = _calcXp(m, streak);
    final isBonus = math.Random().nextDouble() < 0.20;
    final baseEarnedGems = _calcGems(m);
    final earnedGems = isBonus ? baseEarnedGems * 2 : baseEarnedGems;

    final newXp = _xp + earnedXp;
    int newGems = _gems + earnedGems;
    final newClaimed = {..._claimedToday, m.id};
    final newTier = (_tiers.lastIndexWhere((t) => newXp >= t.minXp))
        .clamp(0, _tiers.length - 1);
    final oldTierIdx = _tierIdx;
    final newMaxTier = newTier > _tierIdx ? newTier : _tierIdx;

    // Perfect Day: all missions done → +50 XP +10 💎 bonus
    final allDone = _missions.every((ms) => newClaimed.contains(ms.id));
    if (allDone) newGems += 10;

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
      final extra = isBonus
          ? '  \ud83c\udf89 \u0e42\u0e0a\u0e04\u0e14\u0e35! \ud83d\udc8e\xd72'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${m.emoji} +$earnedXp XP  +$earnedGems \ud83d\udc8e$extra'),
        backgroundColor: _tiers[newMaxTier].color,
        duration: const Duration(seconds: 2),
      ));

      // Perfect Day notification
      if (allDone) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '\ud83c\udf1f Perfect Day! \u0e17\u0e33\u0e04\u0e23\u0e1a\u0e17\u0e38\u0e01\u0e20\u0e32\u0e23\u0e01\u0e34\u0e08 \u2192 +10 \ud83d\udc8e \u0e42\u0e1a\u0e19\u0e31\u0e2a!'),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        title: const Text('สะสม XP & เจม',
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
              color: tier.color.withValues(alpha: 0.45),
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
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontFamily: 'Inter')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
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
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${tier.emoji} ${tier.name}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: 'Inter')),
            const Spacer(),
            Text(
                'อีก ${nextTier.minXp - _xp} XP → ${nextTier.emoji} ${nextTier.name}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
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
              label: 'เจม 💎',
              value: '$_gems',
              sub: 'ใช้แลกรางวัล',
              color: const Color(0xFF6A1B9A),
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ระดับ Tier',
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
                        ? t.color.withValues(alpha: isCurrent ? 1.0 : 0.45)
                        : Colors.grey.shade200,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                                color: t.color.withValues(alpha: 0.5),
                                blurRadius: 10)
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
              color: const Color(0xFFE65100).withValues(alpha: 0.1),
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
      Text('💡 20% โอกาสได้ Gem โบนัส ×2  (Octalysis Variable Reward)',
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
    final gems = m.baseGems;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? _primary.withValues(alpha: 0.25)
              : canDo
                  ? _primary.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          width: canDo && !claimed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                ? _primary.withValues(alpha: 0.08)
                : canDo
                    ? _primary.withValues(alpha: 0.1)
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
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('✅ +$xp XP',
                  style: const TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600)),
              Text('+$gems 💎',
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
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.35), blurRadius: 8)
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('+$xp XP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        fontSize: 12)),
                Text('+$gems 💎',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
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
              Text('+$gems 💎',
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
              border: Border.all(color: _primary.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: _primary.withValues(alpha: 0.1), blurRadius: 8)
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
