import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';

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

const _tiers = [
  _Tier(
      name: 'ไข่',
      minPts: 0,
      color: Color(0xFFB0BEC5),
      glow: Color(0xFFECEFF1),
      emoji: '🥚'),
  _Tier(
      name: 'เหลือง',
      minPts: 100,
      color: Color(0xFFFFCA28),
      glow: Color(0xFFFFF8E1),
      emoji: '⭐'),
  _Tier(
      name: 'ฟ้า',
      minPts: 300,
      color: Color(0xFF42A5F5),
      glow: Color(0xFFE3F2FD),
      emoji: '💎'),
  _Tier(
      name: 'ส้มเพลิง',
      minPts: 600,
      color: Color(0xFFFF7043),
      glow: Color(0xFFFBE9E7),
      emoji: '🔥'),
  _Tier(
      name: 'ม่วงลึก',
      minPts: 1000,
      color: Color(0xFFAB47BC),
      glow: Color(0xFFF3E5F5),
      emoji: '✨'),
  _Tier(
      name: 'แชมป์',
      minPts: 2000,
      color: Color(0xFFFFD700),
      glow: Color(0xFFFFFDE7),
      emoji: '👑'),
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
    title: 'เปิดแอปวันนี้',
    desc: 'รับคะแนนเพียงแค่เปิดแอป',
    points: 2,
    autoCheck: (_) => true,
  ),
  _Mission(
    id: 'log_meal',
    emoji: '🍽️',
    title: 'บันทึกอาหาร',
    desc: 'บันทึกอาหารอย่างน้อย 1 มื้อวันนี้',
    points: 5,
    autoCheck: (u) => u.consumedCalories > 0,
  ),
  _Mission(
    id: 'hit_all_macros',
    emoji: '🥗',
    title: 'โภชนาการครบทั้ง 3',
    desc: 'โปรตีน คาร์บ ไขมัน ถึงเป้าทั้งหมดวันนี้',
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
    title: 'แคลอรี่ในเป้าหมาย',
    desc: 'อยู่ในช่วง 80–110% ของเป้าแคลอรี่',
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
    title: 'Streak 3+ วัน',
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

  static const _bg = Color(0xFF0F1923);

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
    for (final m in _missions) {
      if (!claimed.contains(m.id) && m.autoCheck(userData)) {
        newClaimed.add(m.id);
        earned += m.points;
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
    final prefs = await SharedPreferences.getInstance();
    final newPts = _totalPoints + m.points;
    final newClaimed = {..._claimedToday, m.id};
    await prefs.setInt('tama_points', newPts);
    await prefs.setStringList('tama_claimed_$_todayKey', newClaimed.toList());
    setState(() {
      _totalPoints = newPts;
      _claimedToday = newClaimed;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${m.emoji} +${m.points} คะแนน! "${m.title}"'),
        backgroundColor: const Color(0xFF628141),
        duration: const Duration(seconds: 2),
      ));
    }
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
        title: const Text('ต้อกของฉัน 🐣',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        centerTitle: true,
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
            child: Text('ภารกิจวันนี้',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter')),
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
          '${isDemo ? '${tier.minPts}+' : displayPoints} คะแนน${isDemo ? ' (เดโม่)' : ''}',
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
            'อีก ${nextTier.minPts - _totalPoints} คะแนน → ${nextTier.emoji} ${nextTier.name}',
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
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(painter: _PetPainter(tier.color)),
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
      Text('กดที่ไอคอนเพื่อดูตัวอย่างสี',
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
            child: Text('✅ +${m.points}',
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
                      colors: [Color(0xFF628141), Color(0xFF2E7D52)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF628141).withOpacity(0.4),
                        blurRadius: 8)
                  ]),
              child: Text('+${m.points} ✨',
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
            child: Text('+${m.points}',
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
//  Pet CustomPainter
// ─────────────────────────────────────────────────────────
class _PetPainter extends CustomPainter {
  final Color color;
  _PetPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(cx, cy + 5), 56, glowPaint);

    // Body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, 0.3)!,
          color,
          Color.lerp(color, Colors.black, 0.2)!,
        ],
        stops: const [0.0, 0.6, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 56));
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: 110, height: 108),
        topLeft: const Radius.circular(55),
        topRight: const Radius.circular(55),
        bottomLeft: const Radius.circular(50),
        bottomRight: const Radius.circular(50),
      ));
    canvas.drawPath(bodyPath, bodyPaint);

    // Ear left
    _drawEar(canvas, cx - 36, cy - 46, -0.4, color);
    // Ear right
    _drawEar(canvas, cx + 36, cy - 46, 0.4, color);

    // Eyes
    _drawEye(canvas, cx - 20, cy - 4);
    _drawEye(canvas, cx + 20, cy - 4);

    // Cheek blush
    final blushPaint = Paint()..color = Colors.pink.withOpacity(0.25);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 28, cy + 14), width: 22, height: 10),
        blushPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 28, cy + 14), width: 22, height: 10),
        blushPaint);

    // Mouth (smile)
    final mouthPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path()
      ..moveTo(cx - 14, cy + 24)
      ..quadraticBezierTo(cx, cy + 36, cx + 14, cy + 24);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  void _drawEar(Canvas canvas, double x, double y, double rot, Color c) {
    final earPaint = Paint()..color = Color.lerp(c, Colors.white, 0.15)!;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 22, height: 28), earPaint);
    canvas.restore();
  }

  void _drawEye(Canvas canvas, double x, double y) {
    final whitePaint = Paint()..color = Colors.white.withOpacity(0.95);
    final pupilPaint = Paint()..color = const Color(0xFF2D1B00);
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 22, height: 24),
        whitePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 2, y + 2), width: 12, height: 14),
        pupilPaint);
    canvas.drawCircle(Offset(x + 5, y - 2), 3.5, shinePaint);
  }

  @override
  bool shouldRepaint(_PetPainter old) => old.color != color;
}
