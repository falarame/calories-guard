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
  final Color color;
  final String perks;
  const _Tier({
    required this.name,
    required this.emoji,
    required this.minXp,
    required this.xpBonus,
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
      color: Color(0xFF78909C),
      perks: 'เริ่มต้น'),
  _Tier(
      name: 'Crystal',
      emoji: '🔷',
      minXp: 1000,
      xpBonus: 0.10,
      color: Color(0xFF42A5F5),
      perks: '+10% XP'),
  _Tier(
      name: 'Emerald',
      emoji: '💎',
      minXp: 5000,
      xpBonus: 0.25,
      color: Color(0xFF26A69A),
      perks: '+25% XP'),
  _Tier(
      name: 'Gold',
      emoji: '👑',
      minXp: 15000,
      xpBonus: 0.50,
      color: Color(0xFFFFB300),
      perks: '+50% XP'),
  _Tier(
      name: 'Legend',
      emoji: '⚜️',
      minXp: 50000,
      xpBonus: 1.00,
      color: Color(0xFFAB47BC),
      perks: '+100% XP'),
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

final _missions = [
  _Mission(
    id: 'check_in',
    emoji: '☀️',
    title: 'เช็กอินวันนี้',
    desc: 'เปิดแอปเพื่อรับ XP ประจำวัน',
    baseXp: 10,
    baseGems: 1,
    autoCheck: (_) => true,
  ),
  _Mission(
    id: 'log_meal',
    emoji: '🍱',
    title: 'บันทึกมื้ออาหาร',
    desc: 'บันทึกอาหารอย่างน้อย 1 มื้อวันนี้',
    baseXp: 25,
    baseGems: 3,
    autoCheck: (u) => u.consumedCalories > 0,
  ),
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
        u.consumedFat >= u.targetFat,
  ),
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
    },
  ),
  _Mission(
    id: 'streak_3',
    emoji: '🔥',
    title: 'ใช้แอปต่อเนื่อง 3 วัน',
    desc: 'บันทึกสุขภาพต่อเนื่องอย่างน้อย 3 วัน',
    baseXp: 50,
    baseGems: 5,
    autoCheck: (u) => u.currentStreak >= 3,
  ),
];

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

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF1565C0);

  int get _activeTierIdx => _tierIdx.clamp(0, _tiers.length - 1);

  // XP earned = baseXp × (1 + tierBonus) × streakMultiplier
  int _calcXp(_Mission m, int streak) {
    final bonus = 1.0 + _tiers[_activeTierIdx].xpBonus;
    return (m.baseXp * bonus * _streakMult(streak)).round();
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
    final earnedGems = isBonus ? m.baseGems * 2 : m.baseGems;

    final newXp = _xp + earnedXp;
    final newGems = _gems + earnedGems;
    final newClaimed = {..._claimedToday, m.id};
    final newTier = (_tiers.lastIndexWhere((t) => newXp >= t.minXp))
        .clamp(0, _tiers.length - 1);
    final newMaxTier = newTier > _tierIdx ? newTier : _tierIdx;

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
      final extra = isBonus ? '  🎉 โชคดี! 💎×2' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +$earnedXp XP  +$earnedGems 💎$extra'),
        backgroundColor: _tiers[newMaxTier].color,
        duration: const Duration(seconds: 2),
      ));
    }
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
                    '${t.minXp >= 1000 ? '${t.minXp ~/ 1000}k' : '${t.minXp}'}',
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
    'badge_newbie': ('🌱', 'มือใหม่', 'Achievement'),
    'badge_grower': ('🌾', 'รวงทอง', 'Achievement'),
    'badge_champion': ('✨', 'วิ้งค์', 'Achievement'),
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

// _RicePainter removed — UI redesigned to reward system
class _RicePainter extends CustomPainter {
  final Color color;
  final int stage;
  _RicePainter(this.color, this.stage);

  static const _soilA = Color(0xFF4E342E);
  static const _soilB = Color(0xFF6D4C41);
  static const _soilC = Color(0xFFA1887F);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final h = size.height;

    // background glow
    canvas.drawCircle(
        Offset(cx, cy),
        66,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));

    switch (stage) {
      case 0:
        _stage0(canvas, cx, cy);
        break;
      case 1:
        _stage1(canvas, cx, h);
        break;
      case 2:
        _stage2(canvas, cx, h);
        break;
      case 3:
        _stage3(canvas, cx, h);
        break;
      case 4:
        _stage4(canvas, cx, h, false);
        break;
      default:
        _stage5(canvas, cx, h);
        break;
    }
  }

  // ── Stage 0 : ติ๊ด — cute seed with face ─────────────────
  void _stage0(Canvas c, double cx, double cy) {
    // drop shadow
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 46), width: 52, height: 14),
        Paint()..color = Colors.black.withValues(alpha: 0.12));
    // seed body
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 68, height: 86),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.5)!,
            color,
            Color.lerp(color, Colors.black, 0.18)!
          ],
          stops: const [0.0, 0.55, 1.0],
          center: const Alignment(-0.35, -0.4),
        ).createShader(
            Rect.fromCenter(center: Offset(cx, cy), width: 68, height: 86)),
    );
    // center seam line
    c.drawLine(
        Offset(cx, cy - 38),
        Offset(cx, cy + 38),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14)
          ..strokeWidth = 1.5);
    // tiny horizontal cracks (about to sprout)
    _line(c, cx - 6, cy - 12, cx + 6, cy - 12,
        Colors.black.withValues(alpha: 0.12), 1.2);
    _line(c, cx - 5, cy + 10, cx + 5, cy + 10,
        Colors.black.withValues(alpha: 0.12), 1.2);
    // shine patch
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 17, cy - 20), width: 13, height: 22),
        Paint()..color = Colors.white.withValues(alpha: 0.22));
    // cute eyes
    _eye(c, cx - 13, cy - 5);
    _eye(c, cx + 13, cy - 5);
    // smile
    c.drawPath(
        Path()
          ..moveTo(cx - 9, cy + 14)
          ..quadraticBezierTo(cx, cy + 23, cx + 9, cy + 14),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    // tiny roots
    _rootLine(c, cx, cy + 42, 10, 58);
    _rootLine(c, cx, cy + 44, -9, 56);
  }

  // ── Stage 1 : ต้อย — tiny sprout ──────────────────────────
  void _stage1(Canvas c, double cx, double h) {
    final gy = h - 20.0;
    _soil(c, cx, gy);
    // stem
    c.drawLine(
        Offset(cx, gy - 3),
        Offset(cx, gy - 42),
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    // 2 baby leaves
    _leaf(c, cx, gy - 20, -math.pi * 0.38, 24, 7);
    _leaf(c, cx, gy - 28, math.pi * 0.38, 24, 7);
    // bud
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 46), width: 10, height: 14),
        Paint()..color = Color.lerp(color, Colors.white, 0.5)!);
    // tiny cute face on stem
    _miniface(c, cx, gy - 10);
  }

  // ── Stage 2 : แต้ว — young plant ──────────────────────────
  void _stage2(Canvas c, double cx, double h) {
    final gy = h - 18.0;
    _soil(c, cx, gy);
    c.drawLine(
        Offset(cx, gy - 3),
        Offset(cx, gy - 68),
        Paint()
          ..color = color
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round);
    _leaf(c, cx, gy - 22, -math.pi * 0.42, 30, 8);
    _leaf(c, cx, gy - 34, math.pi * 0.42, 32, 8);
    _leaf(c, cx, gy - 52, -math.pi * 0.36, 28, 7.5);
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 72), width: 11, height: 15),
        Paint()..color = Color.lerp(color, Colors.white, 0.45)!);
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 72), width: 7, height: 10),
        Paint()..color = Color.lerp(color, Colors.white, 0.7)!);
  }

  // ── Stage 3 : โต้ง — tall & strong ────────────────────────
  void _stage3(Canvas c, double cx, double h) {
    final gy = h - 16.0;
    _soil(c, cx, gy);
    c.drawLine(
        Offset(cx, gy - 3),
        Offset(cx, gy - 96),
        Paint()
          ..color = color
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    _leaf(c, cx, gy - 24, -math.pi * 0.44, 36, 9);
    _leaf(c, cx, gy - 38, math.pi * 0.44, 38, 9);
    _leaf(c, cx, gy - 56, -math.pi * 0.40, 34, 8.5);
    _leaf(c, cx, gy - 72, math.pi * 0.38, 32, 8);
    _leaf(c, cx, gy - 86, -math.pi * 0.33, 26, 7);
    // elongated bud
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 101), width: 10, height: 16),
        Paint()..color = Color.lerp(color, Colors.white, 0.4)!);
  }

  // ── Stage 4 : พราว — rice ear ──────────────────────────────
  void _stage4(Canvas c, double cx, double h, bool golden) {
    final gy = h - 16.0;
    _soil(c, cx, gy);
    // curved stem
    c.drawPath(
        Path()
          ..moveTo(cx, gy - 3)
          ..quadraticBezierTo(cx + 4, gy - 52, cx, gy - 106),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    _leaf(c, cx, gy - 26, -math.pi * 0.44, 36, 9);
    _leaf(c, cx, gy - 42, math.pi * 0.44, 38, 9);
    _leaf(c, cx, gy - 60, -math.pi * 0.40, 34, 8.5);
    _leaf(c, cx, gy - 78, math.pi * 0.36, 30, 8);
    _riceEar(c, cx, gy - 106, golden);
  }

  // ── Stage 5 : วิ้งค์ — golden ──────────────────────────────
  void _stage5(Canvas c, double cx, double h) {
    // extra golden glow layer
    c.drawCircle(
        Offset(cx, h / 2),
        72,
        Paint()
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32));
    _stage4(c, cx, h, true);
    // sparkle stars around ear
    final earY = h - 16 - 106.0;
    for (int i = 0; i < 6; i++) {
      final a = (i * math.pi * 2 / 6) - math.pi / 3;
      _sparkle(c, cx + 48 * math.cos(a), earY + 20 + 48 * math.sin(a));
    }
  }

  // ──────────────────── Shared helpers ─────────────────────

  /// Layered soil mound
  void _soil(Canvas c, double cx, double gy) {
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy + 4), width: 90, height: 18),
        Paint()..color = Colors.black.withValues(alpha: 0.1));
    c.drawOval(Rect.fromCenter(center: Offset(cx, gy), width: 86, height: 22),
        Paint()..color = _soilA.withValues(alpha: 0.72));
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 4), width: 72, height: 14),
        Paint()..color = _soilB.withValues(alpha: 0.55));
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 7), width: 50, height: 8),
        Paint()..color = _soilC.withValues(alpha: 0.38));
  }

  /// Filled rice-leaf shape rotated from (x, y)
  void _leaf(
      Canvas c, double x, double y, double angle, double len, double hw) {
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    // filled blade
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(hw * 1.3, -len * 0.12, hw * 1.0, -len * 0.68, 0, -len)
        ..cubicTo(-hw * 1.0, -len * 0.68, -hw * 1.3, -len * 0.12, 0, 0),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    // center vein
    c.drawLine(
        const Offset(0, -2),
        Offset(0, -len * 0.86),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..strokeWidth = 1.2);
    // leaf shine
    c.drawPath(
        Path()
          ..moveTo(-hw * 0.28, -len * 0.14)
          ..quadraticBezierTo(-hw * 0.55, -len * 0.5, -hw * 0.22, -len * 0.72),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    c.restore();
  }

  /// Rice panicle with individual grain ovals
  void _riceEar(Canvas c, double cx, double topY, bool golden) {
    // rachis (the drooping stalk of the ear)
    c.drawPath(
        Path()
          ..moveTo(cx, topY)
          ..cubicTo(cx + 8, topY - 10, cx + 32, topY + 10, cx + 30, topY + 46),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round);

    final grainFill = golden
        ? const Color(0xFFFFF176)
        : Color.lerp(color, Colors.white, 0.4)!;
    final grainBorder = golden ? const Color(0xFFFFCA28) : color;

    for (int i = 0; i < 9; i++) {
      final t = i / 8;
      final rx = cx + 30 * t;
      final ry = topY - 8 + 54 * t;
      final side = (i % 2 == 0) ? -1.0 : 1.0;
      final gx = rx + side * 9;
      final gy = ry + 2;

      c.save();
      c.translate(gx, gy);
      c.rotate(side * 0.28);
      // grain oval
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 7, height: 12),
          Paint()..color = grainFill);
      c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 12),
          Paint()
            ..color = grainBorder.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // tiny shine
      c.drawOval(
          Rect.fromCenter(
              center: const Offset(-1.5, -2.5), width: 2.5, height: 4.5),
          Paint()..color = Colors.white.withValues(alpha: 0.55));
      c.restore();
    }
  }

  void _eye(Canvas c, double x, double y) {
    c.drawCircle(Offset(x, y), 5.5,
        Paint()..color = Colors.black.withValues(alpha: 0.55));
    c.drawCircle(Offset(x + 1.8, y - 1.8), 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.95));
  }

  void _miniface(Canvas c, double cx, double cy) {
    c.drawCircle(Offset(cx - 5, cy), 2.5,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    c.drawCircle(Offset(cx + 5, cy), 2.5,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    c.drawPath(
        Path()
          ..moveTo(cx - 4, cy + 5)
          ..quadraticBezierTo(cx, cy + 8, cx + 4, cy + 5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  void _sparkle(Canvas c, double x, double y) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      c.drawLine(
          Offset(x, y), Offset(x + 6 * math.cos(a), y + 6 * math.sin(a)), p);
    }
    c.drawCircle(Offset(x, y), 2.2, Paint()..color = color);
  }

  void _line(Canvas c, double x1, double y1, double x2, double y2, Color col,
      double w) {
    c.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = col
          ..strokeWidth = w);
  }

  void _rootLine(Canvas c, double sx, double sy, double dx, double dy) {
    c.drawPath(
        Path()
          ..moveTo(sx, sy)
          ..quadraticBezierTo(sx + dx, sy + 8, sx + dx ~/ 2, sy + dy - sy),
        Paint()
          ..color = _soilB
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RicePainter old) =>
      old.color != color || old.stage != stage;
}
