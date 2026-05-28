import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/api_client.dart';
import '/services/error_reporter.dart';

class _LeaderboardEntry {
  final int userId;
  final String username;
  final String? avatarUrl;
  final int weeklyXp;
  final int tierIdx;
  final int rank;
  final int streak;
  final int totalLoginDays;

  const _LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.weeklyXp,
    required this.tierIdx,
    required this.rank,
    required this.streak,
    required this.totalLoginDays,
  });

  static _LeaderboardEntry? tryParse(dynamic raw, int rank) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final uid = (m['user_id'] as num?)?.toInt();
    if (uid == null) return null;
    return _LeaderboardEntry(
      userId: uid,
      username: (m['username'] ?? 'User').toString(),
      avatarUrl: m['avatar_url']?.toString(),
      weeklyXp: (m['weekly_xp'] as num?)?.toInt() ??
          (m['tama_points'] as num?)?.toInt() ??
          0,
      tierIdx: (m['tier_level'] as num?)?.toInt() ?? 0,
      rank: (m['rank'] as num?)?.toInt() ?? rank,
      streak: (m['current_streak'] as num?)?.toInt() ?? 0,
      totalLoginDays: (m['total_login_days'] as num?)?.toInt() ?? 0,
    );
  }
}

const _tierEmojis = ['🌱', '🌿', '🌾', '🍚', '✨'];
const _podiumColors = [
  Color(0xFFFFD700),
  Color(0xFFB0BEC5),
  Color(0xFFBF8970),
];

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<_LeaderboardEntry> _xpBoard = [];
  List<_LeaderboardEntry> _streakBoard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient().get('/leaderboard/global', queryParams: {'limit': '100'}),
        ApiClient().get('/leaderboard/streak', queryParams: {'limit': '100'}),
      ]);

      List<_LeaderboardEntry> parseList(String body) {
        try {
          final data = jsonDecode(body);
          if (data is! List) return [];
          final entries = <_LeaderboardEntry>[];
          for (int i = 0; i < data.length; i++) {
            final entry = _LeaderboardEntry.tryParse(data[i], i + 1);
            if (entry != null) entries.add(entry);
          }
          return entries;
        } catch (_) {
          return [];
        }
      }

      if (mounted) {
        setState(() {
          _xpBoard =
              results[0].statusCode == 200 ? parseList(results[0].body) : [];
          _streakBoard =
              results[1].statusCode == 200 ? parseList(results[1].body) : [];
          _loading = false;
        });
      }
    } catch (e, st) {
      ErrorReporter.report('leaderboard.load', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(userDataProvider).userId;
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabCtrl,
            children: [
              _buildList(_xpBoard, uid, isStreak: false),
              _buildList(_streakBoard, uid, isStreak: true),
            ],
          );

    final tabs = TabBar(
      controller: _tabCtrl,
      labelColor: const Color(0xFF1565C0),
      unselectedLabelColor: Colors.grey,
      indicatorColor: const Color(0xFF1565C0),
      tabs: const [
        Tab(icon: Text('⭐', style: TextStyle(fontSize: 18)), text: 'XP'),
        Tab(icon: Text('🔥', style: TextStyle(fontSize: 18)), text: 'Streak'),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8FAFB),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              const Expanded(
                child: Text('🏆 ลีดเดอร์บอร์ด',
                    style: TextStyle(
                        color: Colors.black87,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
                onPressed: _load,
              ),
            ]),
          ),
          tabs,
          Expanded(child: content),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('🏆 Leaderboard',
            style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: tabs,
        ),
      ),
      body: content,
    );
  }

  Widget _buildList(List<_LeaderboardEntry> entries, int myUid,
      {required bool isStreak}) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('ยังไม่มีข้อมูล',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ),
      );
    }

    final top3 = entries.take(3).toList();
    final rest =
        entries.length > 3 ? entries.sublist(3) : <_LeaderboardEntry>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildPodium(top3, myUid, isStreak: isStreak),
          ),
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('อันดับอื่น ๆ',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter')),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                itemCount: rest.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildRow(rest[i], myUid, isStreak: isStreak),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildPodium(List<_LeaderboardEntry> top3, int myUid,
      {required bool isStreak}) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A237E).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        Text(isStreak ? '🔥 ต่อเนื่องที่สุด 🔥' : '⭐ สัปดาห์นี้ ⭐',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'Inter',
                letterSpacing: 1.5)),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: _podiumItem(second, 2, 60,
                    myUid: myUid, isStreak: isStreak)),
            Expanded(
                child: _podiumItem(first, 1, 90,
                    myUid: myUid, isStreak: isStreak)),
            Expanded(
                child: _podiumItem(third, 3, 44,
                    myUid: myUid, isStreak: isStreak)),
          ],
        ),
      ]),
    );
  }

  Widget _podiumItem(_LeaderboardEntry? e, int rank, double platformH,
      {required int myUid, required bool isStreak}) {
    if (e == null) {
      return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
          height: platformH,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _podiumColors[rank - 1].withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ]);
    }

    final isMe = e.userId == myUid;
    final tierEmoji = _tierEmojis[e.tierIdx.clamp(0, _tierEmojis.length - 1)];
    final color = _podiumColors[rank - 1];
    final avatarRadius = rank == 1 ? 30.0 : 22.0;
    final medals = ['🥇', '🥈', '🥉'];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('👑', style: TextStyle(fontSize: 22)),
          ),
        Container(
          decoration: isMe
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellowAccent, width: 2.5),
                )
              : null,
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: e.avatarUrl != null && e.avatarUrl!.isNotEmpty
                ? NetworkImage(e.avatarUrl!)
                : null,
            child: e.avatarUrl == null || e.avatarUrl!.isEmpty
                ? Icon(Icons.person,
                    size: rank == 1 ? 26 : 20, color: Colors.grey.shade600)
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(medals[rank - 1], style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        SizedBox(
          width: 85,
          child: Text(
            isMe ? '${e.username}\n(คุณ)' : e.username,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe ? Colors.yellowAccent : Colors.white,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!isStreak) Text(tierEmoji, style: const TextStyle(fontSize: 12)),
          if (!isStreak && e.streak > 0) const SizedBox(width: 3),
          if (e.streak > 0) ...[
            const Text('🔥', style: TextStyle(fontSize: 12)),
            Text('${e.streak}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade300,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        Text(
          isStreak ? '${e.totalLoginDays} วันทั้งหมด' : '${e.weeklyXp} XP',
          style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        Container(
          height: platformH,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text('#$rank',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    fontFamily: 'Inter')),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(_LeaderboardEntry e, int myUid, {required bool isStreak}) {
    final isMe = e.userId == myUid;
    final tierEmoji = _tierEmojis[e.tierIdx.clamp(0, _tierEmojis.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1565C0).withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isMe
                ? const Color(0xFF1565C0).withOpacity(0.45)
                : Colors.grey.shade200),
      ),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text('#${e.rank}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  fontFamily: 'Inter')),
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: e.avatarUrl != null && e.avatarUrl!.isNotEmpty
              ? NetworkImage(e.avatarUrl!)
              : null,
          child: e.avatarUrl == null || e.avatarUrl!.isEmpty
              ? const Icon(Icons.person, size: 20, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isMe ? '${e.username} (คุณ)' : e.username,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isMe ? const Color(0xFF1565C0) : Colors.black87,
                  fontFamily: 'Inter'),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              if (!isStreak) ...[
                Text(tierEmoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
              ],
              if (e.streak > 0) ...[
                const Text('🔥', style: TextStyle(fontSize: 12)),
                Text(' ${e.streak}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
              ],
              Text(
                isStreak
                    ? '${e.totalLoginDays} วันทั้งหมด'
                    : '${e.weeklyXp} XP',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'Inter'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
