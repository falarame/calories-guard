import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Reward model ────────────────────────────────────────
class _Reward {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  final int cost;
  final bool comingSoon;
  const _Reward({
    required this.id,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.cost,
    this.comingSoon = false,
  });
}

const _rewards = [
  _Reward(
      id: 'badge_newbie',
      emoji: '🌱',
      name: 'แบดจ์ชาวนามือใหม่',
      desc: 'ตราสัญลักษณ์แสดงความมุ่งมั่นในการดูแลสุขภาพ',
      cost: 50),
  _Reward(
      id: 'badge_grower',
      emoji: '🌾',
      name: 'แบดจ์รวงทอง',
      desc: 'สำหรับผู้ที่ทำภารกิจต่อเนื่องจนต้นข้าวออกรวง',
      cost: 300),
  _Reward(
      id: 'badge_champion',
      emoji: '✨',
      name: 'แบดจ์วิ้งค์',
      desc: 'เกียรติยศสูงสุดของไร่ข้าว มีเพียงไม่กี่คน',
      cost: 1000),
  _Reward(
      id: 'food_coupon',
      emoji: '🍱',
      name: 'คูปองส่วนลดอาหาร 10%',
      desc: 'ส่วนลดจากพาร์ทเนอร์ร้านอาหารเพื่อสุขภาพ',
      cost: 500,
      comingSoon: true),
  _Reward(
      id: 'gym_coupon',
      emoji: '💪',
      name: 'คูปองฟิตเนส 1 วัน',
      desc: 'ใช้ฟิตเนสพาร์ทเนอร์ฟรี 1 วัน',
      cost: 800,
      comingSoon: true),
  _Reward(
      id: 'premium_week',
      emoji: '👑',
      name: 'Premium 7 วัน',
      desc: 'ปลดล็อกฟีเจอร์พรีเมียมทั้งหมดเป็นเวลา 1 สัปดาห์',
      cost: 1500,
      comingSoon: true),
];

// ─── Screen ───────────────────────────────────────────────
class RewardShopScreen extends StatefulWidget {
  final int currentPoints;
  final void Function(int newPoints) onPointsUpdated;

  const RewardShopScreen({
    super.key,
    required this.currentPoints,
    required this.onPointsUpdated,
  });

  @override
  State<RewardShopScreen> createState() => _RewardShopScreenState();
}

class _RewardShopScreenState extends State<RewardShopScreen> {
  late int _points;
  Set<String> _claimed = {};

  static const _bg = Color(0xFF0A1A0E);
  static const _card = Color(0xFF122018);
  static const _green = Color(0xFF66BB6A);

  @override
  void initState() {
    super.initState();
    _points = widget.currentPoints;
    _loadClaimed();
  }

  Future<void> _loadClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('tama_rewards_claimed') ?? [];
    setState(() => _claimed = list.toSet());
  }

  Future<void> _redeem(_Reward r) async {
    if (_claimed.contains(r.id) || _points < r.cost || r.comingSoon) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('แลก ${r.name}?',
            style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        content: Text('ใช้ ${r.cost} เมล็ดข้าว 🌾',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final newPts = _points - r.cost;
    final newClaimed = {..._claimed, r.id};
    await prefs.setInt('tama_points', newPts);
    await prefs.setStringList('tama_rewards_claimed', newClaimed.toList());
    setState(() {
      _points = newPts;
      _claimed = newClaimed;
    });
    widget.onPointsUpdated(newPts);
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${r.emoji} ได้รับ "${r.name}" แล้ว!'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ร้านแลกรางวัล 🏪',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(children: [
        // ── Points banner ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: _green.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            const Text('🌾', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('เมล็ดข้าวของฉัน',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Inter')),
              Text('$_points เมล็ด',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter')),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Reward list ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: _rewards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(_rewards[i]),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(_Reward r) {
    final isClaimed = _claimed.contains(r.id);
    final canAfford = _points >= r.cost;
    final isAvailable = !r.comingSoon && !isClaimed && canAfford;
    final borderColor = isClaimed
        ? _green.withOpacity(0.5)
        : r.comingSoon
            ? Colors.white.withOpacity(0.08)
            : canAfford
                ? _green.withOpacity(0.35)
                : Colors.white.withOpacity(0.1);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isClaimed
            ? [BoxShadow(color: _green.withOpacity(0.12), blurRadius: 10)]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isClaimed
                  ? _green.withOpacity(0.15)
                  : r.comingSoon
                      ? Colors.white.withOpacity(0.04)
                      : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: Text(r.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),

          // text
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(r.name,
                    style: TextStyle(
                        color: isClaimed
                            ? _green
                            : Colors.white
                                .withOpacity(r.comingSoon ? 0.4 : 0.95),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if (r.comingSoon) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.4))),
                    child: const Text('เร็วๆ นี้',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(r.desc,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          )),
          const SizedBox(width: 10),

          // action
          if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _green.withOpacity(0.4))),
              child: const Text('✅ ได้แล้ว',
                  style: TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600)),
            )
          else
            GestureDetector(
              onTap: isAvailable ? () => _redeem(r) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isAvailable
                      ? const LinearGradient(
                          colors: [Color(0xFF388E3C), Color(0xFF1B5E20)])
                      : null,
                  color: isAvailable ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isAvailable
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1)),
                  boxShadow: isAvailable
                      ? [
                          BoxShadow(
                              color: _green.withOpacity(0.35), blurRadius: 8)
                        ]
                      : [],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${r.cost}',
                      style: TextStyle(
                          color: isAvailable
                              ? Colors.white
                              : r.comingSoon
                                  ? Colors.white.withOpacity(0.2)
                                  : const Color(0xFFEF9A9A),
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                          fontSize: 14)),
                  Text('🌾',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white
                              .withOpacity(isAvailable ? 1.0 : 0.3))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
