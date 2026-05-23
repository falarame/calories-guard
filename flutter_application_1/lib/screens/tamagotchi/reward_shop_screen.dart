import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/api_client.dart';

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
      emoji: '🔰',
      name: 'Badge: มือใหม่',
      desc: 'Achievement badge สำหรับผู้เริ่มต้นสะสม XP',
      cost: 30),
  _Reward(
      id: 'badge_grower',
      emoji: '🏅',
      name: 'Badge: ผู้มุ่งมั่น',
      desc: 'Achievement badge สำหรับผู้มุ่งมั่นทำภารกิจต่อเนื่อง',
      cost: 150),
  _Reward(
      id: 'badge_champion',
      emoji: '✨',
      name: 'Badge: Champion',
      desc: 'Achievement badge ระดับสูง — มีเพียงไม่กี่คน',
      cost: 500),
  _Reward(
      id: 'streak_repair',
      emoji: '💎',
      name: 'Streak Repair',
      desc: 'กู้คืน streak ที่ขาดไป 1ครั้งต่อเดือน',
      cost: 700),
  _Reward(
      id: 'food_coupon',
      emoji: '🍱',
      name: 'คูปองส่วนลดอาหาร 10%',
      desc: 'Tangible reward — ส่วนลดจากพาร์ทเนอร์ร้านอาหารเพื่อสุขภาพ',
      cost: 200,
      comingSoon: true),
  _Reward(
      id: 'gym_coupon',
      emoji: '💪',
      name: 'คูปองฟิตเนส 1 วัน',
      desc: 'Tangible reward — ใช้ฟิตเนสพาร์ทเนอร์ฟรี 1 วัน',
      cost: 350,
      comingSoon: true),
  _Reward(
      id: 'premium_week',
      emoji: '👑',
      name: 'Premium 7 วัน',
      desc: 'Tangible reward — ปลดล็อกฟีเจอร์พรีเมียมทั้งหมด 1 สัปดาห์',
      cost: 600,
      comingSoon: true),
];

// ─── Screen ───────────────────────────────────────────────
class RewardShopScreen extends StatefulWidget {
  final int userId;
  final int currentGems;
  final int tierIdx;
  final int streakGrace; // 0 = ok, 1/2 = grace, -1 = expired
  final void Function(int newGems) onGemsUpdated;
  final Future<void> Function()? onStreakRepaired;

  const RewardShopScreen({
    super.key,
    required this.userId,
    required this.currentGems,
    required this.tierIdx,
    this.streakGrace = 0,
    required this.onGemsUpdated,
    this.onStreakRepaired,
  });

  @override
  State<RewardShopScreen> createState() => _RewardShopScreenState();
}

class _RewardShopScreenState extends State<RewardShopScreen> {
  late int _gems;
  Set<String> _claimed = {};
  bool _isRedeeming = false;

  static const _bg = Color(0xFFF8FAFB);
  static const _primary = Color(0xFF6A1B9A);

  DateTime? _freezeUntil;

  @override
  void initState() {
    super.initState();
    _gems = widget.currentGems;
    _loadClaimed();
    _loadFreeze();
  }

  String get _claimedKey => 'tama_achievements_${widget.userId}';
  String get _gemsKey => 'tama_gems_${widget.userId}';
  String get _freeRepairsKey => 'tama_free_repairs_${widget.userId}';
  String get _shopRepairsKey => 'tama_shop_repairs_${widget.userId}';
  String get _freezeKey => 'streak_freeze_until_${widget.userId}';

  static const int _streakRepairShopCost = 700;
  static const int _freeRepairQuotaPerMonth = 1;
  static const int _shopRepairQuotaPerMonth = 1;

  int _parseMonthlyCount(String? stored, String monthKey) {
    if (stored == null) return 0;
    final parts = stored.split(':');
    if (parts.length < 2 || parts[0] != monthKey) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  bool get _freezeActive =>
      _freezeUntil != null && _freezeUntil!.isAfter(DateTime.now());

  Future<void> _loadClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_claimedKey) ?? [];
    setState(() => _claimed = list.toSet());
  }

  Future<void> _loadFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_freezeKey);
    if (ms != null && mounted) {
      setState(() => _freezeUntil = DateTime.fromMillisecondsSinceEpoch(ms));
    }
  }

  Future<void> _redeem(_Reward r) async {
    if (_isRedeeming) return;
    // Streak Repair has its own dedicated flow (free quota + monthly shop quota)
    if (r.id == 'streak_repair') {
      await _handleStreakRepair();
      return;
    }
    final isFreeze = r.id == 'streak_freeze';
    final alreadyFrozen = isFreeze && _freezeActive;
    if ((!isFreeze && _claimed.contains(r.id)) ||
        _gems < r.cost ||
        r.comingSoon ||
        alreadyFrozen) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('แลก ${r.name}?',
            style: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: Text('ใช้ ${r.cost} 🌾 เมล็ดข้าว',
            style: TextStyle(color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
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
    setState(() => _isRedeeming = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final newGems = _gems - r.cost;
      await prefs.setInt(_gemsKey, newGems);

      if (isFreeze) {
        final until = DateTime.now().add(const Duration(days: 2));
        await prefs.setInt(_freezeKey, until.millisecondsSinceEpoch);
        if (mounted) {
          setState(() {
            _gems = newGems;
            _freezeUntil = until;
          });
        }
        widget.onGemsUpdated(newGems);
        ApiClient().patch('/users/${widget.userId}/tama-points',
            body: {'gems': newGems, 'tier_level': widget.tierIdx}).ignore();
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '\ud83d\udee1\ufe0f Streak Freeze \u0e40\u0e1b\u0e34\u0e14\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e41\u0e25\u0e49\u0e27! \u0e1b\u0e49\u0e2d\u0e07\u0e01\u0e31\u0e19 2 \u0e27\u0e31\u0e19'),
            backgroundColor: Color(0xFF1565C0),
            duration: Duration(seconds: 2),
          ));
        }
        return;
      }

      final newClaimed = {..._claimed, r.id};
      await prefs.setStringList(_claimedKey, newClaimed.toList());
      setState(() {
        _gems = newGems;
        _claimed = newClaimed;
      });
      widget.onGemsUpdated(newGems);
      ApiClient().patch(
        '/users/${widget.userId}/tama-points',
        body: {
          'gems': newGems,
          'tier_level': widget.tierIdx,
          'claimed_badges': newClaimed.toList(),
        },
      ).ignore();
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${r.emoji} ได้รับ "${r.name}" แล้ว!'),
          backgroundColor: _primary,
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  /// Streak Repair (V2.1): 1 free + 1 shop purchase per month (separate quotas)
  /// Free  = 0 🌾 cost, 1/month
  /// Shop  = 700 🌾 flat cost, 1/month (independent of free quota)
  Future<void> _handleStreakRepair() async {
    if (_isRedeeming) return;
    if (widget.streakGrace != -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ใช้ได้เฉพาะตอน streak ขาดแล้วเท่านั้น'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final freeUsed =
        _parseMonthlyCount(prefs.getString(_freeRepairsKey), monthKey);
    final shopUsed =
        _parseMonthlyCount(prefs.getString(_shopRepairsKey), monthKey);
    final freeAvailable = freeUsed < _freeRepairQuotaPerMonth;
    final shopAvailable =
        shopUsed < _shopRepairQuotaPerMonth && _gems >= _streakRepairShopCost;

    if (!freeAvailable && !shopAvailable) {
      final reason = (shopUsed >= _shopRepairQuotaPerMonth)
          ? 'หมดสิทธิ์ทั้งฟรีและร้านเดือนนี้ — รอเดือนหน้า'
          : 'หมดสิทธิ์ฟรี + 🌾 ไม่พอ (ต้อง ≥ $_streakRepairShopCost)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reason),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💎 กู้คืน Streak',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (freeAvailable)
                _RepairOptionRow(
                  emoji: '🆓',
                  title: 'ใช้สิทธิ์ฟรี',
                  subtitle: 'เหลือ 1 ครั้งเดือนนี้',
                  enabled: true,
                  onTap: () => Navigator.pop(context, 'free'),
                )
              else
                _RepairOptionRow(
                  emoji: '🆓',
                  title: 'สิทธิ์ฟรี',
                  subtitle: 'ใช้ไปแล้วเดือนนี้',
                  enabled: false,
                ),
              const SizedBox(height: 10),
              if (shopAvailable)
                _RepairOptionRow(
                  emoji: '💰',
                  title: 'ซื้อจากร้าน $_streakRepairShopCost 🌾',
                  subtitle:
                      'เหลือ 1 ครั้งเดือนนี้ · หลังซื้อ: ${_gems - _streakRepairShopCost} 🌾',
                  enabled: true,
                  onTap: () => Navigator.pop(context, 'shop'),
                )
              else if (shopUsed >= _shopRepairQuotaPerMonth)
                _RepairOptionRow(
                  emoji: '💰',
                  title: 'ซื้อจากร้าน',
                  subtitle: 'ใช้สิทธิ์ shop เดือนนี้แล้ว',
                  enabled: false,
                )
              else
                _RepairOptionRow(
                  emoji: '💰',
                  title: 'ซื้อจากร้าน $_streakRepairShopCost 🌾',
                  subtitle: '🌾 ไม่พอ (มี $_gems)',
                  enabled: false,
                ),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
    if (choice != 'free' && choice != 'shop') return;
    final useFree = choice == 'free';
    final cost = useFree ? 0 : _streakRepairShopCost;

    setState(() => _isRedeeming = true);
    try {
      final newGems = _gems - cost;
      await prefs.setInt(_gemsKey, newGems);
      if (useFree) {
        await prefs.setString(_freeRepairsKey, '$monthKey:${freeUsed + 1}');
      } else {
        await prefs.setString(_shopRepairsKey, '$monthKey:${shopUsed + 1}');
      }
      ApiClient().post('/users/${widget.userId}/streak-repair', body: {
        'source': useFree ? 'free' : 'shop',
        'cost_gems': cost,
      }).ignore();
      await widget.onStreakRepaired?.call();
      if (mounted) {
        setState(() => _gems = newGems);
        widget.onGemsUpdated(newGems);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(useFree
              ? '💎 ใช้สิทธิ์ฟรีกู้ streak สำเร็จ! บันทึกอาหารวันนี้ได้เลย'
              : '💎 ซื้อ Streak Repair สำเร็จ! (-$_streakRepairShopCost 🌾)'),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 3),
        ));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('แลกเมล็ดข้าว',
            style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(children: [
        // ── Gems banner ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: _primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            const Text('🌾', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เมล็ดข้าวของฉัน',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Inter')),
                    Text('$_gems 🌾',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Inter')),
                  ]),
            ),
            const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('หมดอายุ 30 วัน',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'Inter')),
              SizedBox(height: 2),
              Text('ใช้แลกรางวัลด้านล่าง',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
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
    final isFreeze = r.id == 'streak_freeze';
    final isRepair = r.id == 'streak_repair';
    // Streak Repair: re-buyable monthly — only enabled when streak expired (grace -1)
    final isClaimed =
        isRepair ? false : (isFreeze ? _freezeActive : _claimed.contains(r.id));
    final repairEnabled = isRepair && widget.streakGrace == -1;
    final canAfford = isRepair ? repairEnabled : _gems >= r.cost;
    final isAvailable = !r.comingSoon && !isClaimed && canAfford;
    final borderColor = isClaimed
        ? _primary.withOpacity(0.4)
        : r.comingSoon
            ? Colors.grey.shade200
            : canAfford
                ? _primary.withOpacity(0.3)
                : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: isClaimed
                  ? _primary.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
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
                  ? _primary.withOpacity(0.1)
                  : r.comingSoon
                      ? Colors.grey.shade100
                      : _primary.withOpacity(0.07),
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
                  Flexible(
                    child: Text(r.name,
                        style: TextStyle(
                            color: isClaimed
                                ? _primary
                                : r.comingSoon
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  if (r.comingSoon) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
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
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ])),
          const SizedBox(width: 10),

          // action
          if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primary.withOpacity(0.3))),
              child: const Text('✅ ได้แล้ว',
                  style: TextStyle(
                      color: Color(0xFF6A1B9A),
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
                  color: isAvailable ? _primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isAvailable
                      ? [
                          BoxShadow(
                              color: _primary.withOpacity(0.35), blurRadius: 8)
                        ]
                      : [],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${r.cost}',
                      style: TextStyle(
                          color: isAvailable
                              ? Colors.white
                              : r.comingSoon
                                  ? Colors.grey.shade300
                                  : const Color(0xFFEF9A9A),
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                          fontSize: 14)),
                  Text('🌾',
                      style: TextStyle(
                          fontSize: 10,
                          color: isAvailable
                              ? Colors.white
                              : Colors.grey.shade400)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _RepairOptionRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  const _RepairOptionRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF1565C0) : Colors.grey;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.06) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: enabled ? color.withOpacity(0.3) : Colors.grey.shade300),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: enabled ? Colors.black87 : Colors.grey.shade500)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? Colors.grey.shade600
                          : Colors.grey.shade400)),
            ]),
          ),
          if (enabled) Icon(Icons.chevron_right, color: color, size: 22),
        ]),
      ),
    );
  }
}
