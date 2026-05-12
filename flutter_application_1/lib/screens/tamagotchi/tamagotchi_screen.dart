import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';
import '/screens/tamagotchi/reward_shop_screen.dart';
import '/services/api_client.dart';

// ─────────────────────────────────────────────────────────
//  Tier data
// ─────────────────────────────────────────────────────────
class _Tier {
  final String name;
  final int minPts;
  final Color color;
  final Color glow;
  final String emoji;
  const _Tier({
    required this.name,
    required this.minPts,
    required this.color,
    required this.glow,
    required this.emoji,
  });
}

/// Multiplier per tier index — ระดับสูงขึ้น ได้เมล็ดข้าวมากขึ้น
const _tierMultipliers = [1.0, 1.2, 1.5, 1.8, 2.0, 2.5];

const _tiers = [
  _Tier(
      name: 'ติ๊ด',
      minPts: 0,
      color: Color(0xFF8D6E63),
      glow: Color(0xFFEFEBE9),
      emoji: '🌰'),
  _Tier(
      name: 'ต้อย',
      minPts: 100,
      color: Color(0xFF66BB6A),
      glow: Color(0xFFE8F5E9),
      emoji: '🌱'),
  _Tier(
      name: 'แต้ว',
      minPts: 300,
      color: Color(0xFF43A047),
      glow: Color(0xFFF1F8E9),
      emoji: '🪴'),
  _Tier(
      name: 'โต้ง',
      minPts: 600,
      color: Color(0xFF2E7D32),
      glow: Color(0xFFE8F5E9),
      emoji: '🌿'),
  _Tier(
      name: 'พราว',
      minPts: 1000,
      color: Color(0xFF8BC34A),
      glow: Color(0xFFF9FBE7),
      emoji: '🌾'),
  _Tier(
      name: 'วิ้งค์',
      minPts: 2000,
      color: Color(0xFFFFD600),
      glow: Color(0xFFFFFDE7),
      emoji: '✨'),
];

// ─────────────────────────────────────────────────────────
//  Mission model
// ─────────────────────────────────────────────────────────
class _Mission {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final int points;
  final bool Function(UserData u) autoCheck;
  const _Mission({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.points,
    required this.autoCheck,
  });
}

final _missions = [
  _Mission(
    id: 'open_app',
    emoji: '☀️',
    title: 'เช็กอินวันนี้',
    desc: 'เปิดแอปเพื่อรับแต้มประจำวัน',
    points: 2,
    autoCheck: (_) => true,
  ),
  _Mission(
    id: 'log_meal',
    emoji: '🍱',
    title: 'บันทึกมื้ออาหาร',
    desc: 'บันทึกอาหารอย่างน้อย 1 มื้อวันนี้',
    points: 5,
    autoCheck: (u) => u.consumedCalories > 0,
  ),
  _Mission(
    id: 'hit_all_macros',
    emoji: '💪',
    title: 'ครบตามโภชนาการ',
    desc: 'โปรตีน คาร์บ ไขมัน ครบตามเป้าทั้งหมด',
    points: 20,
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
    points: 15,
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
    points: 10,
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
  int _totalPoints = 0;
  int _maxTierIdx = 0;
  Set<String> _claimedToday = {};
  Set<String> _claimedRewards = {};

  static const _bg = Color(0xFFF5F8F2);
  static const _primary = Color(0xFF628141);

  int get _activeTierIdx => _maxTierIdx.clamp(0, _tiers.length - 1);

  int _missionPoints(_Mission m) =>
      (m.points * _tierMultipliers[_activeTierIdx]).round();

  String get _multiplierLabel {
    final m = _tierMultipliers[_activeTierIdx];
    return m == 1.0
        ? ''
        : '×${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)}';
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final uid = ref.read(userDataProvider).userId;
      if (!mounted) return;
      setState(() {
        _totalPoints = prefs.getInt(_pointsKey(uid)) ?? 0;
        _maxTierIdx = prefs.getInt(_maxTierKey(uid)) ?? 0;
        _claimedToday = (prefs.getStringList(_claimedKey(uid)) ?? []).toSet();
        _claimedRewards =
            (prefs.getStringList('tama_rewards_claimed_$uid') ?? []).toSet();
      });
    });
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  String _pointsKey(int userId) => 'tama_points_$userId';
  String _claimedKey(int userId) => 'tama_claimed_${userId}_$_todayKey';
  String _maxTierKey(int userId) => 'tama_max_tier_$userId';

  Future<void> _load() async {
    final userId = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();
    final localPts = prefs.getInt(_pointsKey(userId)) ?? 0;
    final localMaxTier = prefs.getInt(_maxTierKey(userId)) ?? 0;
    final claimed = (prefs.getStringList(_claimedKey(userId)) ?? []).toSet();

    int pts = localPts;
    int maxTier = localMaxTier;
    if (userId > 0) {
      try {
        final res = await ApiClient().get('/users/$userId/tama-points');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final backendPts = (data['tama_points'] as num?)?.toInt() ?? 0;
          final backendTier = (data['tier_level'] as num?)?.toInt() ?? 0;
          final backendBadges = (data['claimed_badges'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (backendPts > localPts) {
            pts = backendPts;
            await prefs.setInt(_pointsKey(userId), pts);
          }
          if (backendTier > localMaxTier) {
            maxTier = backendTier;
            await prefs.setInt(_maxTierKey(userId), maxTier);
          }
          if (backendBadges.isNotEmpty) {
            await prefs.setStringList(
                'tama_rewards_claimed_$userId', backendBadges);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      final rewardKey = 'tama_rewards_claimed_$userId';
      final claimedRewards = (prefs.getStringList(rewardKey) ?? []).toSet();
      setState(() {
        _totalPoints = pts;
        _maxTierIdx = maxTier;
        _claimedToday = claimed;
        _claimedRewards = claimedRewards;
      });
    }
  }

  Future<void> _claimMission(_Mission m) async {
    if (_claimedToday.contains(m.id)) return;
    final userId = ref.read(userDataProvider).userId;
    final pts = _missionPoints(m);
    final prefs = await SharedPreferences.getInstance();
    final newPts = _totalPoints + pts;
    final newClaimed = {..._claimedToday, m.id};
    final earnedTier = _tiers
        .lastIndexWhere((t) => newPts >= t.minPts)
        .clamp(0, _tiers.length - 1);
    final newMaxTier = earnedTier > _maxTierIdx ? earnedTier : _maxTierIdx;
    await prefs.setInt(_pointsKey(userId), newPts);
    await prefs.setStringList(_claimedKey(userId), newClaimed.toList());
    if (newMaxTier > _maxTierIdx) {
      await prefs.setInt(_maxTierKey(userId), newMaxTier);
    }
    setState(() {
      _totalPoints = newPts;
      _maxTierIdx = newMaxTier;
      _claimedToday = newClaimed;
    });
    _syncPointsToBackend(newPts);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +$pts แต้ม! "${m.title}"'),
        backgroundColor: _primary,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _syncPointsToBackend(int pts) {
    if (!mounted) return;
    final userId = ref.read(userDataProvider).userId;
    if (userId <= 0) return;
    ApiClient().patch(
      '/users/$userId/tama-points',
      body: {'tama_points': pts, 'tier_level': _maxTierIdx},
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final tier = _tiers[_activeTierIdx];
    final nextTier =
        _activeTierIdx < _tiers.length - 1 ? _tiers[_activeTierIdx + 1] : null;
    final progress = nextTier != null
        ? ((_totalPoints - tier.minPts) / (nextTier.minPts - tier.minPts))
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
        title: const Text('สะสมแต้มสุขภาพ',
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
                      currentPoints: _totalPoints,
                      maxTierIdx: _maxTierIdx,
                      onPointsUpdated: (pts) =>
                          setState(() => _totalPoints = pts),
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
          const SizedBox(height: 20),
          _buildTierRow(),
          const SizedBox(height: 24),
          _buildMissionsSection(userData),
          if (_claimedRewards.isNotEmpty) ...[
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
          colors: [
            tier.color,
            Color.lerp(tier.color, _primary, 0.5)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: tier.color.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ระดับ ${tier.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
              Text('สมาชิกสุขภาพ CaloriesGuard',
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$_totalPoints',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
              Text('แต้ม',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontFamily: 'Inter')),
            ]),
          ),
        ]),
        if (nextTier != null) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('${tier.emoji} ${tier.name}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: 'Inter')),
            const Spacer(),
            Text(
                'อีก ${nextTier.minPts - _totalPoints} แต้ม → ${nextTier.emoji} ${nextTier.name}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontFamily: 'Inter')),
          ]),
        ] else ...[
          const SizedBox(height: 16),
          const Text('🏆 ระดับสูงสุดแล้ว!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ── Tier Row ──────────────────────────────────────────────
  Widget _buildTierRow() {
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
        const Text('ระดับสมาชิก',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Inter')),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_tiers.length, (i) {
            final t = _tiers[i];
            final isUnlocked = i <= _maxTierIdx;
            final isCurrent = i == _maxTierIdx;
            return Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isCurrent ? 44 : 36,
                  height: isCurrent ? 44 : 36,
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
                          style: TextStyle(fontSize: isCurrent ? 22 : 16))),
                ),
                const SizedBox(height: 4),
                Text(t.name,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isUnlocked ? t.color : Colors.grey.shade400,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('กิจกรรมรับแต้มวันนี้',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Inter')),
        const Spacer(),
        if (_multiplierLabel.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withValues(alpha: 0.3)),
            ),
            child: Text('โบนัส $_multiplierLabel',
                style: const TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
      ]),
      const SizedBox(height: 12),
      ..._missions.map((m) => _buildMissionCard(m, userData)),
    ]);
  }

  Widget _buildMissionCard(_Mission m, UserData userData) {
    final claimed = _claimedToday.contains(m.id);
    final canDo = m.autoCheck(userData);
    final pts = _missionPoints(m);

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
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('✅ +$pts',
                style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          )
        else if (canDo)
          GestureDetector(
            onTap: () => _claimMission(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.35), blurRadius: 8)
                ],
              ),
              child: Text('+$pts แต้ม',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      fontSize: 13)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('+$pts แต้ม',
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontFamily: 'Inter')),
          ),
      ]),
    );
  }

  // ── Badges ────────────────────────────────────────────────
  static const _badgeInfo = {
    'badge_newbie': ('🌱', 'มือใหม่'),
    'badge_grower': ('🌾', 'รวงทอง'),
    'badge_champion': ('✨', 'วิ้งค์'),
  };

  Widget _buildBadgesSection() {
    final earned = _badgeInfo.entries
        .where((e) => _claimedRewards.contains(e.key))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🏆  แบดจ์ที่ได้รับ',
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
              Text(e.value.$2,
                  style: const TextStyle(
                      color: _primary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
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
