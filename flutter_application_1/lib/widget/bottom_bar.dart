import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Import Provider ---
import '../providers/user_data_provider.dart';

// --- Import หน้าต่างๆ ---
import '../screens/app_home_screen.dart';
import '../screens/record/record_food_screen.dart';
import '../screens/recommened_exercise/exercise_recommendation_screen.dart';
import '../screens/recommend_food/recommend_food_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/chat/chat_screen.dart';
import 'notification_sheet.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const _welcomePrefKey = 'chat_fab_welcome_seen';

  // รายชื่อหน้า (เรียงตามลำดับ 0, 1, 2, 3)
  final List<Widget> _pages = [
    const AppHomeScreen(), // Index 0: หน้าหลัก
    const FoodLogScreen(), // Index 1: หน้าบันทึก
    const RecommendedFoodScreen(), // Index 2: อาหารแนะนำ
    const ExerciseRecommendationScreen(), // Index 3: ออกกำลังกาย
  ];

  bool _showWelcome = false;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _maybeShowWelcome();
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybeShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomePrefKey) == true) return;
    if (!mounted) return;
    setState(() => _showWelcome = true);
    _welcomeTimer = Timer(const Duration(seconds: 6), _dismissWelcome);
  }

  Future<void> _dismissWelcome() async {
    if (!_showWelcome) return;
    _welcomeTimer?.cancel();
    if (mounted) setState(() => _showWelcome = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomePrefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ หัวใจสำคัญ: ดึงค่า Index จาก Provider มาใช้
    // เมื่อค่านี้เปลี่ยน หน้าจอจะเปลี่ยนตามทันที
    final selectedIndex = ref.watch(navIndexProvider);

    final showWelcomeBubble = _showWelcome && selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showWelcomeBubble) ...[
              _WelcomeSpeechBubble(onTap: _dismissWelcome),
              const SizedBox(height: 8),
            ],
            FloatingActionButton(
              heroTag: 'chatFab',
              onPressed: () {
                _dismissWelcome();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()));
              },
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              tooltip: 'AI Coach',
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.12,
                  child: Image.asset(
                    'assets/images/icon/chatbot_icon.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          _buildTopBar(), // ส่วนหัว (Logo + Profile)

          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        color: const Color(0xFFE8EFCF),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
                Icons.home_outlined, "หน้าหลัก", 0, selectedIndex),
            _buildBottomNavItem(
                Icons.food_bank_outlined, "บันทึก", 1, selectedIndex),
            _buildBottomNavItem(Icons.restaurant, "อาหาร", 2, selectedIndex),
            _buildBottomNavItem(
                Icons.leaderboard_rounded, "ลีดเดอร์บอร์ด", 3, selectedIndex),
          ],
        ),
      ),
    );
  }

  // Widget ปุ่มด้านล่าง
  Widget _buildBottomNavItem(
      IconData icon, String label, int index, int currentIndex) {
    bool isActive = currentIndex == index;
    Color color = isActive ? const Color(0xFF4C6414) : const Color(0xFF8F8F8F);

    return GestureDetector(
      onTap: () {
        // ✅ สั่งเปลี่ยนหน้าผ่าน Provider
        ref.read(navIndexProvider.notifier).state = index;
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: isActive
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4C6414).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                : null,
            child: Icon(icon, color: color, size: 30),
          ),
          if (!isActive) ...[
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color)),
          ]
        ],
      ),
    );
  }

  // Widget ส่วนหัว (Top Bar)
  Widget _buildTopBar() {
    return Container(
      height: 110,
      padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 10),
      decoration: const BoxDecoration(color: Color(0xFF628141)),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('assets/images/icon/icon.png'),
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calories',
                  style: TextStyle(
                      fontFamily: 'Itim',
                      fontSize: 15,
                      color: Color(0xFFE8EFCF),
                      height: 1)),
              Text('Guard',
                  style: TextStyle(
                      fontFamily: 'Karla',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1)),
            ],
          ),
          const Spacer(),
          const NotificationBell(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Builder(builder: (context) {
                final avatarUrl = ref.watch(userDataProvider).avatarUrl;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person_outline,
                          color: Colors.white, size: 22)
                      : null,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSpeechBubble extends StatelessWidget {
  final VoidCallback onTap;
  const _WelcomeSpeechBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF628141).withValues(alpha: 0.3),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี! ฉันคือน้องซีการ์ด',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4C6414)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'แตะที่นี่เพื่อพูดคุยกับโค้ช AI',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 18,
              bottom: -7,
              child: Transform.rotate(
                angle: 0.785398,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(
                          color: const Color(0xFF628141).withValues(alpha: 0.3),
                          width: 1.2),
                      bottom: BorderSide(
                          color: const Color(0xFF628141).withValues(alpha: 0.3),
                          width: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
