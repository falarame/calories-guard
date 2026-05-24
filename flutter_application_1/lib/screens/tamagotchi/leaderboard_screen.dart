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
        Tab(icon: Text('�', style: TextStyle(fontSize: 18)), text: 'Streak'),
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
        bottom: tabs,
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildRow(entries[i], myUid, isStreak: isStreak),
      ),
    );
  }

  Widget _buildRow(_LeaderboardEntry e, int myUid, {required bool isStreak}) {
    final isMe = e.userId == myUid;
    final tierEmoji = _tierEmojis[e.tierIdx.clamp(0, _tierEmojis.length - 1)];
    final rankBadge = e.rank == 1
        ? '🥇'
        : e.rank == 2
            ? '🥈'
            : e.rank == 3
                ? '🥉'
                : '#${e.rank}';

    final subtitle = isStreak
        ? '🔥 ${e.streak} วันติดต่อกัน  •  ${e.totalLoginDays} วันทั้งหมด'
        : '$tierEmoji  ${e.weeklyXp} XP สัปดาห์นี้';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1565C0).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isMe
                ? const Color(0xFF1565C0).withOpacity(0.5)
                : Colors.grey.shade200),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: Text(rankBadge,
              style: TextStyle(
                  fontSize: e.rank <= 3 ? 22 : 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700)),
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
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'Inter')),
          ]),
        ),
      ]),
    );
  }
}
