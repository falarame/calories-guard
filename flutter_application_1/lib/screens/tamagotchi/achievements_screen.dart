import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/providers/user_data_provider.dart';

class _AchievementInfo {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final int rewardGems;
  final int?
      target; // streak target for progress display (null = no progress UI)
  const _AchievementInfo({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.rewardGems,
    this.target,
  });
}

// Tier names + emojis must stay in sync with tamagotchi_screen.dart `_tiers`
const _achievements = [
  // First-time tier reach (lifetime)
  _AchievementInfo(
      id: 'first_tier_1',
      emoji: '🌿',
      title: 'ครั้งแรกถึงต้นกล้า',
      desc: 'ทำ XP ครบ 100 ใน 1 สัปดาห์',
      rewardGems: 30),
  _AchievementInfo(
      id: 'first_tier_2',
      emoji: '🌾',
      title: 'ครั้งแรกถึงออกรวง',
      desc: 'ทำ XP ครบ 300 ใน 1 สัปดาห์',
      rewardGems: 50),
  _AchievementInfo(
      id: 'first_tier_3',
      emoji: '🍚',
      title: 'ครั้งแรกถึงข้าวสุก',
      desc: 'ทำ XP ครบ 500 ใน 1 สัปดาห์',
      rewardGems: 150),
  _AchievementInfo(
      id: 'first_tier_4',
      emoji: '✨',
      title: 'ครั้งแรกถึงข้าวทอง',
      desc: 'ทำ XP ครบ 700 ใน 1 สัปดาห์',
      rewardGems: 300),
  // Streak milestones (lifetime)
  _AchievementInfo(
      id: 'streak_3',
      emoji: '🔥',
      title: 'ต่อเนื่อง 3 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 3 วัน',
      rewardGems: 10,
      target: 3),
  _AchievementInfo(
      id: 'streak_7',
      emoji: '🔥',
      title: 'ต่อเนื่อง 7 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 1 สัปดาห์',
      rewardGems: 25,
      target: 7),
  _AchievementInfo(
      id: 'streak_15',
      emoji: '🌟',
      title: 'ต่อเนื่อง 15 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 2 สัปดาห์',
      rewardGems: 50,
      target: 15),
  _AchievementInfo(
      id: 'streak_30',
      emoji: '🌟🌟',
      title: 'ต่อเนื่อง 30 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 1 เดือน',
      rewardGems: 100,
      target: 30),
  _AchievementInfo(
      id: 'streak_60',
      emoji: '⭐',
      title: 'ต่อเนื่อง 60 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 2 เดือน',
      rewardGems: 200,
      target: 60),
  _AchievementInfo(
      id: 'streak_90',
      emoji: '⭐⭐',
      title: 'ต่อเนื่อง 90 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 3 เดือน',
      rewardGems: 400,
      target: 90),
  _AchievementInfo(
      id: 'streak_365',
      emoji: '👑',
      title: 'ตำนาน 365 วัน',
      desc: 'บันทึกอาหารต่อเนื่อง 1 ปีเต็ม',
      rewardGems: 1000,
      target: 365),
];

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});
  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  Set<String> _earned = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(userDataProvider).userId;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('tama_achievements_$uid') ?? [];
    if (mounted) {
      setState(() {
        _earned = list.toSet();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final earnedCount =
        _achievements.where((a) => _earned.contains(a.id)).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('🏆 Trophy Room',
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text('$earnedCount / ${_achievements.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800)),
                  const Text('Achievements ที่ได้รับแล้ว',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Inter')),
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _achievements.length,
                  itemBuilder: (_, i) => _buildTile(_achievements[i], userData),
                ),
              ),
            ]),
    );
  }

  Widget _buildTile(_AchievementInfo a, UserData userData) {
    final earned = _earned.contains(a.id);
    int? progress;
    if (!earned && a.id.startsWith('streak_') && a.target != null) {
      progress = userData.currentStreak.clamp(0, a.target!);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: earned
                ? const Color(0xFF1565C0).withOpacity(0.4)
                : Colors.grey.shade300),
        boxShadow: earned
            ? [
                BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Opacity(
          opacity: earned ? 1.0 : 0.35,
          child: Text(a.emoji, style: const TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 8),
        Text(a.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: earned ? Colors.black87 : Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(a.desc,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontFamily: 'Inter')),
        const SizedBox(height: 6),
        if (earned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('+${a.rewardGems} 🌾',
                style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter')),
          )
        else if (progress != null && a.target != null)
          Text('$progress / ${a.target}',
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontFamily: 'Inter'))
        else
          Text('+${a.rewardGems} 🌾',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontFamily: 'Inter')),
      ]),
    );
  }
}
