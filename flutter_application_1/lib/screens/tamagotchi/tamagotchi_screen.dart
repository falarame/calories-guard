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

_Tier _tierOf(int pts) {
  for (int i = _tiers.length - 1; i >= 0; i--) {
    if (pts >= _tiers[i].minPts) return _tiers[i];
  }
  return _tiers[0];
}

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
    title: 'รับแสงแดดวันนี้',
    desc: 'เปิดแอปเพื่อให้ต้นข้าวได้รับแสง',
    points: 2,
    autoCheck: (_) => true,
  ),
  _Mission(
    id: 'log_meal',
    emoji: '💧',
    title: 'รดน้ำต้นข้าว',
    desc: 'บันทึกอาหารอย่างน้อย 1 มื้อวันนี้',
    points: 5,
    autoCheck: (u) => u.consumedCalories > 0,
  ),
  _Mission(
    id: 'hit_all_macros',
    emoji: '🌿',
    title: 'ใส่ปุ๋ยครบสูตร',
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
    emoji: '�️',
    title: 'ควบคุมปริมาณน้ำ',
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
    emoji: '🌤️',
    title: 'แดดต่อเนื่อง 3 วัน',
    desc: 'ใช้แอปต่อเนื่องอย่างน้อย 3 วัน',
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

class _TamagotchiScreenState extends ConsumerState<TamagotchiScreen>
    with SingleTickerProviderStateMixin {
  int _totalPoints = 0;
  Set<String> _claimedToday = {};
  int? _demoTierIdx; // null = show real tier
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  static const _bg = Color(0xFF0A1A0E);

  /// Tier index used for display (demo-aware)
  int get _activeTierIdx =>
      (_demoTierIdx ?? _tiers.lastIndexWhere((t) => _totalPoints >= t.minPts))
          .clamp(0, _tiers.length - 1);

  /// Real tier index based on actual points (used when claiming)
  int get _realTierIdx => _tiers
      .lastIndexWhere((t) => _totalPoints >= t.minPts)
      .clamp(0, _tiers.length - 1);

  /// Points shown in UI — demo-aware
  int _missionPoints(_Mission m) =>
      (m.points * _tierMultipliers[_activeTierIdx]).round();

  /// Real points actually awarded when claiming
  int _missionPointsReal(_Mission m) =>
      (m.points * _tierMultipliers[_realTierIdx]).round();

  String get _multiplierLabel {
    final m = _tierMultipliers[_activeTierIdx];
    return m == 1.0
        ? ''
        : '×${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)}';
  }

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final pts = prefs.getInt('tama_points') ?? 0;
    final claimed =
        (prefs.getStringList('tama_claimed_$_todayKey') ?? []).toSet();

    // Auto-claim unclaimed missions that are done
    final userData = ref.read(userDataProvider);
    final newClaimed = <String>{...claimed};
    int earned = 0;
    final autoTierIdx = _tiers
        .lastIndexWhere((t) => pts >= t.minPts)
        .clamp(0, _tiers.length - 1);
    for (final m in _missions) {
      if (!claimed.contains(m.id) && m.autoCheck(userData)) {
        newClaimed.add(m.id);
        earned += (m.points * _tierMultipliers[autoTierIdx]).round();
      }
    }
    if (earned > 0) {
      await prefs.setInt('tama_points', pts + earned);
      await prefs.setStringList('tama_claimed_$_todayKey', newClaimed.toList());
    }

    if (mounted) {
      setState(() {
        _totalPoints = pts + earned;
        _claimedToday = newClaimed;
      });
    }
  }

  Future<void> _claimMission(_Mission m) async {
    if (_claimedToday.contains(m.id)) return;
    final pts = _missionPointsReal(m);
    final prefs = await SharedPreferences.getInstance();
    final newPts = _totalPoints + pts;
    final newClaimed = {..._claimedToday, m.id};
    await prefs.setInt('tama_points', newPts);
    await prefs.setStringList('tama_claimed_$_todayKey', newClaimed.toList());
    setState(() {
      _totalPoints = newPts;
      _claimedToday = newClaimed;
    });
    _syncPointsToBackend(newPts);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +$pts เมล็ดข้าว! "${m.title}"'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _syncPointsToBackend(int pts) {
    final userId = ref.read(userDataProvider).userId;
    if (userId <= 0) return;
    final tierIdx = _tierOf(pts);
    ApiClient().patch(
      '/users/$userId/tama-points',
      body: {'tama_points': pts, 'tier_level': tierIdx},
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final realTier = _tierOf(_totalPoints);
    final realTierIdx = _tiers.indexOf(realTier);
    final isDemo = _demoTierIdx != null;
    final tierIdx = _demoTierIdx ?? realTierIdx;
    final tier = _tiers[tierIdx];
    final nextTier = tierIdx < _tiers.length - 1 ? _tiers[tierIdx + 1] : null;
    final demoPoints = isDemo ? tier.minPts : _totalPoints;
    final progress = nextTier != null
        ? ((isDemo ? tier.minPts : _totalPoints) - tier.minPts) /
            (nextTier.minPts - tier.minPts)
        : 1.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ไร่ข้าวของฉัน 🌾',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'ร้านแลกรางวัล',
            icon: Stack(clipBehavior: Clip.none, children: [
              const Text('🏪', style: TextStyle(fontSize: 20)),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0A1A0E), width: 1.2),
                  ),
                ),
              ),
            ]),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RewardShopScreen(
                      currentPoints: _totalPoints,
                      onPointsUpdated: (pts) =>
                          setState(() => _totalPoints = pts),
                    ),
                  ));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(children: [
          // ── Demo badge ──
          if (isDemo)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility_rounded,
                    color: Colors.amber, size: 14),
                const SizedBox(width: 6),
                const Text('โหมดเดโม่ — กดสีใดก็ได้เพื่อดู',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontFamily: 'Inter')),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _demoTierIdx = null),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.amber, size: 16),
                ),
              ]),
            ),

          // ── Pet + tier card ──
          _buildPetCard(tier, tierIdx, progress, nextTier, demoPoints, isDemo),
          const SizedBox(height: 20),

          // ── Tier ladder (tappable) ──
          _buildTierLadder(tierIdx, realTierIdx),
          const SizedBox(height: 24),

          // ── Missions ──
          Align(
            alignment: Alignment.centerLeft,
            child: Row(children: [
              const Text('กิจวัตรต้นข้าว',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter')),
              const Spacer(),
              if (_multiplierLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8BC34A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF8BC34A).withOpacity(0.5)),
                  ),
                  child: Text('โบนัส $_multiplierLabel',
                      style: const TextStyle(
                          color: Color(0xFFAED581),
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          ..._missions.map((m) => _buildMissionCard(m, userData)),
        ]),
      ),
    );
  }

  // ─── Pet Card ───────────────────────────────────────────
  Widget _buildPetCard(_Tier tier, int tierIdx, double progress,
      _Tier? nextTier, int displayPoints, bool isDemo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tier.color.withOpacity(0.25), tier.glow.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tier.color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(children: [
        // Pet
        AnimatedBuilder(
          animation: _bounceAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _bounceAnim.value),
            child: _buildPetBody(tier),
          ),
        ),
        const SizedBox(height: 20),

        // Tier badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: tier.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tier.color.withOpacity(0.6)),
          ),
          child: Text(
            '${tier.emoji} ${tier.name}',
            style: TextStyle(
                color: tier.color,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Points
        Text(
          '${isDemo ? '${tier.minPts}+' : displayPoints} เมล็ดข้าว 🌾${isDemo ? ' (เดโม่)' : ''}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter'),
        ),

        if (nextTier != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(tier.color),
                  minHeight: 8,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'อีก ${isDemo ? nextTier.minPts - tier.minPts : nextTier.minPts - _totalPoints} เมล็ดข้าว → ${nextTier.emoji} ${nextTier.name}',
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontFamily: 'Inter'),
          ),
        ] else
          Text('🏆 ถึงระดับสูงสุดแล้ว!',
              style: TextStyle(
                  color: tier.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ─── Pet Body Painter ───────────────────────────────────
  Widget _buildPetBody(_Tier tier) {
    final stage = _tiers.indexOf(tier);
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(painter: _RicePainter(tier.color, stage)),
    );
  }

  // ─── Tier Ladder ───────────────────────────────────────
  Widget _buildTierLadder(int currentIdx, int realTierIdx) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_tiers.length, (i) {
          final t = _tiers[i];
          final isUnlocked = i <= realTierIdx;
          final isSelected = i == currentIdx;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _demoTierIdx = (_demoTierIdx == i) ? null : i),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isSelected ? 42 : 36,
                  height: isSelected ? 42 : 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? t.color
                        : isUnlocked
                            ? t.color.withOpacity(0.4)
                            : Colors.white.withOpacity(0.07),
                    border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : t.color.withOpacity(isUnlocked ? 0.7 : 0.2),
                        width: isSelected ? 2.5 : 1.5),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: t.color.withOpacity(0.6),
                                blurRadius: 14,
                                spreadRadius: 1)
                          ]
                        : [],
                  ),
                  child: Center(
                      child: Text(t.emoji,
                          style: TextStyle(fontSize: isSelected ? 20 : 14))),
                ),
                const SizedBox(height: 5),
                Text(t.name,
                    style: TextStyle(
                        fontSize: 9,
                        color: isSelected
                            ? t.color
                            : isUnlocked
                                ? t.color.withOpacity(0.7)
                                : Colors.white.withOpacity(0.25),
                        fontFamily: 'Inter',
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          );
        }),
      ),
      const SizedBox(height: 6),
      Text('กดที่ขั้นเพื่อดูตัวอย่างต้นข้าว',
          style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
              fontFamily: 'Inter')),
    ]);
  }

  // ─── Mission Card ───────────────────────────────────────
  Widget _buildMissionCard(_Mission m, UserData userData) {
    final claimed = _claimedToday.contains(m.id);
    final canDo = m.autoCheck(userData);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: claimed
            ? Colors.white.withOpacity(0.07)
            : canDo
                ? const Color(0xFF1B5E35).withOpacity(0.3)
                : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? Colors.white.withOpacity(0.1)
              : canDo
                  ? const Color(0xFF628141).withOpacity(0.6)
                  : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(children: [
        Text(m.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title,
                style: TextStyle(
                    color:
                        claimed ? Colors.white.withOpacity(0.4) : Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    decoration: claimed ? TextDecoration.lineThrough : null)),
            Text(m.desc,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        if (claimed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('✅ +${_missionPoints(m)} 🌾',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontFamily: 'Inter')),
          )
        else if (canDo)
          GestureDetector(
            onTap: () => _claimMission(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF388E3C), Color(0xFF1B5E20)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF388E3C).withOpacity(0.5),
                        blurRadius: 8)
                  ]),
              child: Text('+${_missionPoints(m)} 🌾',
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
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Text('+${_missionPoints(m)} 🌾',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    fontFamily: 'Inter')),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Rice Plant CustomPainter  (stage 0–5)  — cute redesign
// ─────────────────────────────────────────────────────────
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
          ..color = color.withOpacity(0.2)
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
        Paint()..color = Colors.black.withOpacity(0.12));
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
          ..color = Colors.black.withOpacity(0.14)
          ..strokeWidth = 1.5);
    // tiny horizontal cracks (about to sprout)
    _line(c, cx - 6, cy - 12, cx + 6, cy - 12, Colors.black.withOpacity(0.12),
        1.2);
    _line(c, cx - 5, cy + 10, cx + 5, cy + 10, Colors.black.withOpacity(0.12),
        1.2);
    // shine patch
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 17, cy - 20), width: 13, height: 22),
        Paint()..color = Colors.white.withOpacity(0.22));
    // cute eyes
    _eye(c, cx - 13, cy - 5);
    _eye(c, cx + 13, cy - 5);
    // smile
    c.drawPath(
        Path()
          ..moveTo(cx - 9, cy + 14)
          ..quadraticBezierTo(cx, cy + 23, cx + 9, cy + 14),
        Paint()
          ..color = Colors.black.withOpacity(0.45)
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
          ..color = color.withOpacity(0.14)
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
        Paint()..color = Colors.black.withOpacity(0.1));
    c.drawOval(Rect.fromCenter(center: Offset(cx, gy), width: 86, height: 22),
        Paint()..color = _soilA.withOpacity(0.72));
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 4), width: 72, height: 14),
        Paint()..color = _soilB.withOpacity(0.55));
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, gy - 7), width: 50, height: 8),
        Paint()..color = _soilC.withOpacity(0.38));
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
        Offset(0, -2),
        Offset(0, -len * 0.86),
        Paint()
          ..color = Colors.white.withOpacity(0.16)
          ..strokeWidth = 1.2);
    // leaf shine
    c.drawPath(
        Path()
          ..moveTo(-hw * 0.28, -len * 0.14)
          ..quadraticBezierTo(-hw * 0.55, -len * 0.5, -hw * 0.22, -len * 0.72),
        Paint()
          ..color = Colors.white.withOpacity(0.14)
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
            ..color = grainBorder.withOpacity(0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // tiny shine
      c.drawOval(
          Rect.fromCenter(center: Offset(-1.5, -2.5), width: 2.5, height: 4.5),
          Paint()..color = Colors.white.withOpacity(0.55));
      c.restore();
    }
  }

  void _eye(Canvas c, double x, double y) {
    c.drawCircle(
        Offset(x, y), 5.5, Paint()..color = Colors.black.withOpacity(0.55));
    c.drawCircle(Offset(x + 1.8, y - 1.8), 1.8,
        Paint()..color = Colors.white.withOpacity(0.95));
  }

  void _miniface(Canvas c, double cx, double cy) {
    c.drawCircle(Offset(cx - 5, cy), 2.5,
        Paint()..color = Colors.black.withOpacity(0.35));
    c.drawCircle(Offset(cx + 5, cy), 2.5,
        Paint()..color = Colors.black.withOpacity(0.35));
    c.drawPath(
        Path()
          ..moveTo(cx - 4, cy + 5)
          ..quadraticBezierTo(cx, cy + 8, cx + 4, cy + 5),
        Paint()
          ..color = Colors.black.withOpacity(0.3)
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
