import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/constants/constants.dart';
import '/providers/user_data_provider.dart';

// ── Tier helper (mirrors tamagotchi_screen tiers) ───────────────
String? _rewardBadge(int tierLevel) {
  if (tierLevel >= 5) return '✨';
  if (tierLevel >= 3) return '🌾';
  if (tierLevel >= 1) return '🌱';
  return null;
}

String _tierEmoji(int streak) {
  if (streak >= 90) return '✨';
  if (streak >= 60) return '🌾';
  if (streak >= 30) return '🌿';
  if (streak >= 14) return '🪴';
  if (streak >= 7) return '🌱';
  return '🌰';
}

String _tierName(int streak) {
  if (streak >= 90) return 'วิ้งค์';
  if (streak >= 60) return 'พราว';
  if (streak >= 30) return 'โต้ง';
  if (streak >= 14) return 'แต้ว';
  if (streak >= 7) return 'ต้อย';
  return 'ติ๊ด';
}

Color _tierColor(int streak) {
  if (streak >= 90) return const Color(0xFFFFD600);
  if (streak >= 60) return const Color(0xFF8BC34A);
  if (streak >= 30) return const Color(0xFF2E7D32);
  if (streak >= 14) return const Color(0xFF43A047);
  if (streak >= 7) return const Color(0xFF66BB6A);
  return const Color(0xFF8D6E63);
}

class ExerciseRecommendationScreen extends ConsumerStatefulWidget {
  const ExerciseRecommendationScreen({super.key});

  @override
  ConsumerState<ExerciseRecommendationScreen> createState() =>
      _ExerciseRecommendationScreenState();
}

class _ExerciseRecommendationScreenState
    extends ConsumerState<ExerciseRecommendationScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFF4F8F0);
  static const _card = Colors.white;
  static const _green = Color(0xFF43A047);

  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  String? _errorMsg;
  int _tabIndex = 0; // 0 = streak, 1 = tama_points
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_leaderboard);
    if (_tabIndex == 1) {
      list.sort((a, b) => ((b['tama_points'] as int?) ?? 0)
          .compareTo((a['tama_points'] as int?) ?? 0));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.baseUrl}/leaderboard'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data =
            (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() => _leaderboard = data);
        _animController.forward(from: 0);
      } else {
        setState(() => _errorMsg = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})');
      }
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(userDataProvider).userId;

    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _errorMsg != null
              ? _buildError()
              : FadeTransition(
                  opacity: _fadeAnim, child: _buildContent(myUserId)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌾', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(_errorMsg!,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadLeaderboard,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  Widget _buildContent(int myUserId) {
    final sorted = _sorted;
    final top3 = sorted.take(3).toList();
    final rest = sorted.skip(3).toList();

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadLeaderboard,
      child: CustomScrollView(
        slivers: [
          // ─── App Bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverToBoxAdapter(
            child: _buildTabToggle(),
          ),
          // ─── Podium ──────────────────────────────────────────
          if (top3.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildPodium(top3, myUserId),
            ),
          // ─── Rank 4+ list ─────────────────────────────────────
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(children: [
                  const Text('🌿', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('อันดับที่ 4 ขึ้นไป',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.grey.shade700)),
                ]),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildRankTile(rest[i], i + 4, myUserId),
                childCount: rest.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🌾 ไร่ข้าวทั่วประเทศ',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        color: Color(0xFF1B5E20))),
                SizedBox(height: 4),
                Text('จัดอันดับตามวันแสงแดดต่อเนื่อง',
                    style: TextStyle(fontSize: 13, color: Color(0xFF78909C))),
              ],
            ),
            GestureDetector(
              onTap: _loadLeaderboard,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F0), shape: BoxShape.circle),
                child: const Icon(Icons.refresh,
                    color: Color(0xFF43A047), size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8F1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8EDCF)),
          ),
          child: const Row(children: [
            Text('☀️', style: TextStyle(fontSize: 13)),
            SizedBox(width: 8),
            Text('สะสมวันแสงแดดต่อเนื่องให้ต้นข้าวเติบโต!',
                style: TextStyle(
                    color: Color(0xFF558B5E),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2EA),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          _tabBtn(0, '☀️  วันแสงแดด'),
          _tabBtn(1, '🌾  คะแนนสะสม'),
        ]),
      ),
    );
  }

  Widget _tabBtn(int idx, String label) {
    final active = _tabIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: active ? _green : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3, int myUserId) {
    final ordered = [
      if (top3.length > 1) top3[1] else null,
      top3[0],
      if (top3.length > 2) top3[2] else null,
    ];
    final heights = [90.0, 122.0, 72.0];
    final rankEmojis = ['🥈', '🥇', '🥉'];
    // order: silver(2nd), gold(1st), bronze(3rd)
    final rankColors = [
      const Color(0xFF90A4AE), // silver
      const Color(0xFFFFB300), // gold
      const Color(0xFFBF7040), // bronze
    ];
    final podiumGrads = [
      [const Color(0xFFECF0F3), const Color(0xFFBCC8D4)], // silver
      [const Color(0xFFFFF8DC), const Color(0xFFFFD84D)], // gold
      [const Color(0xFFF5E6D8), const Color(0xFFD4956A)], // bronze
    ];
    final podiumTextColors = [
      const Color(0xFF546E7A),
      const Color(0xFF7A5500),
      const Color(0xFF6D3A1A),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDEDD5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Text('TOP 3 ชาวไร่',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                letterSpacing: 2.5,
                color: _green.withOpacity(0.85))),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final user = ordered[i];
            if (user == null) return const SizedBox(width: 88);
            final isMe = user['user_id'] == myUserId;
            return _buildPodiumItem(
              user: user,
              rankEmoji: rankEmojis[i],
              rankColor: rankColors[i],
              podiumColors: podiumGrads[i],
              podiumTextColor: podiumTextColors[i],
              podiumHeight: heights[i],
              isMe: isMe,
              rank: (i == 0
                  ? 2
                  : i == 1
                      ? 1
                      : 3),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildPodiumItem({
    required Map<String, dynamic> user,
    required String rankEmoji,
    required Color rankColor,
    required List<Color> podiumColors,
    required Color podiumTextColor,
    required double podiumHeight,
    required bool isMe,
    required int rank,
  }) {
    final name = (user['username'] as String?) ?? 'ผู้ใช้';
    final streak = (user['current_streak'] as int?) ?? 0;
    final tColor = _tierColor(streak);
    final shortName = name.length > 8 ? '${name.substring(0, 7)}…' : name;

    return Column(children: [
      Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
        // Avatar circle — colored by rank (gold/silver/bronze)
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: rankColor.withOpacity(0.18),
            border: Border.all(color: rankColor, width: isMe ? 3 : 2),
            boxShadow: [
              BoxShadow(
                  color: rankColor.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: podiumTextColor),
            ),
          ),
        ),
        // Rank medal
        Positioned(
          top: -12,
          child: Text(rankEmoji, style: const TextStyle(fontSize: 18)),
        ),
        // Tier badge bottom-right
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: tColor.withOpacity(0.5))),
            child: Center(
                child: Text(_tierEmoji(streak),
                    style: const TextStyle(fontSize: 10))),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(shortName,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
              color: isMe ? rankColor : Colors.black87)),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_tabIndex == 1 ? '🌾' : '☀️',
            style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 2),
        Text(
          _tabIndex == 1
              ? '${(user['tama_points'] as int?) ?? 0} เมล็ด'
              : '$streak วัน',
          style: TextStyle(
              fontSize: 10, color: rankColor, fontWeight: FontWeight.w600),
        ),
      ]),
      const SizedBox(height: 8),
      // Podium block
      Container(
        width: 86,
        height: podiumHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: podiumColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          border: Border.all(color: rankColor.withOpacity(0.4)),
        ),
        child: Center(
          child: Text('#$rank',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: podiumTextColor)),
        ),
      ),
    ]);
  }

  Widget _buildRankTile(Map<String, dynamic> user, int rank, int myUserId) {
    final name = (user['username'] as String?) ?? 'ผู้ใช้';
    final streak = (user['current_streak'] as int?) ?? 0;
    final totalDays = (user['total_login_days'] as int?) ?? 0;
    final tierLevel = (user['tier_level'] as int?) ?? 0;
    final isMe = user['user_id'] == myUserId;
    final tColor = _tierColor(streak);
    final badge = _rewardBadge(tierLevel);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? tColor.withOpacity(0.09) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMe ? tColor.withOpacity(0.5) : const Color(0xFFE8F0E2),
            width: isMe ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 26,
            child: Text('#$rank',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    color: isMe ? tColor : Colors.grey.shade400)),
          ),
          const SizedBox(width: 6),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tColor.withOpacity(0.15),
              border: Border.all(color: tColor.withOpacity(0.5), width: 1.5),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: tColor),
              ),
            ),
          ),
        ]),
        title: Row(children: [
          if (badge != null) ...[
            Text(badge, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4)
          ],
          Text(name + (isMe ? ' (คุณ)' : ''),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  color: isMe ? _green : Colors.black87)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: tColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tColor.withOpacity(0.4))),
            child: Text('${_tierEmoji(streak)} ${_tierName(streak)}',
                style: TextStyle(
                    fontSize: 9,
                    color: tColor,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        subtitle: Text('รดน้ำ $totalDays วัน',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: _tabIndex == 0
            ? _streakBadge(streak, tColor)
            : _pointsBadge((user['tama_points'] as int?) ?? 0),
      ),
    );
  }

  Widget _streakBadge(int streak, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('☀️', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$streak',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Inter',
                  color: color)),
        ]),
      );

  Widget _pointsBadge(int pts) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8DC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD84D)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌾', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$pts',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Inter',
                  color: Color(0xFF7A5500))),
        ]),
      );
}
