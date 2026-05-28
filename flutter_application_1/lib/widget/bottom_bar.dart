import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Import Provider ---
import '../providers/user_data_provider.dart';

// --- Import หน้าต่างๆ ---
import '../screens/app_home_screen.dart';
import '../screens/record/record_food_screen.dart';
import '../screens/recommend_food/recommend_food_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/subprofile_screen/progress_screen.dart';
import '../screens/tamagotchi/leaderboard_screen.dart';
import '../screens/weight/weight_chart_screen.dart';
import '../services/notification_helper.dart';
import 'notification_sheet.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  // รายชื่อหน้า (เรียงตามลำดับ 0, 1, 2, 3)
  final List<Widget> _pages = [
    const AppHomeScreen(), // Index 0: หน้าหลัก
    const FoodLogScreen(), // Index 1: หน้าบันทึก
    const RecommendedFoodScreen(), // Index 2: อาหารแนะนำ
    const LeaderboardScreen(embedded: true), // Index 3: ลีดเดอร์บอร์ด
  ];

  @override
  void initState() {
    super.initState();
    // P2: listen for notification deep-link payloads
    NotificationHelper.pendingPayload.addListener(_handleNotificationPayload);
    // Handle payload that may have been set before this widget was mounted
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNotificationPayload());
  }

  @override
  void dispose() {
    NotificationHelper.pendingPayload
        .removeListener(_handleNotificationPayload);
    super.dispose();
  }

  void _handleNotificationPayload() {
    final payload = NotificationHelper.pendingPayload.value;
    if (payload == null || !mounted) return;
    NotificationHelper.pendingPayload.value = null;

    switch (payload) {
      case 'record_food':
        ref.read(navIndexProvider.notifier).state = 1;
        break;
      case 'home':
        ref.read(navIndexProvider.notifier).state = 0;
        break;
      case 'weight':
        ref.read(navIndexProvider.notifier).state = 0;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeightChartScreen()));
        break;
      case 'progress':
        ref.read(navIndexProvider.notifier).state = 0;
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProgressScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ หัวใจสำคัญ: ดึงค่า Index จาก Provider มาใช้
    // เมื่อค่านี้เปลี่ยน หน้าจอจะเปลี่ยนตามทันที
    final selectedIndex = ref.watch(navIndexProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
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
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4C6414).withOpacity(0.4),
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
                  backgroundColor: Colors.white.withOpacity(0.25),
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

