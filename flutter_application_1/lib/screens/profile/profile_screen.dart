import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../providers/user_data_provider.dart';
import '../../services/api_client.dart';

// sub-screens imports
import 'subprofile_screen/progress_screen.dart';
import 'subprofile_screen/edit_profile_screen.dart';
import 'subprofile_screen/unit_settings_screen.dart';
import 'subprofile_screen/setting_screen.dart';
import '/login_register/screens/goal_selection_screen.dart';
import '/login_register/screens/activity_level_screen.dart';
import '/login_register/screens/food_allergy_screen.dart';
import '/screens/chat/chat_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xfile == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name.isNotEmpty ? xfile.name : 'avatar.jpg';
      print(
          '[upload] filename=$filename bytes=${bytes.length} header=${bytes.take(4).toList()}');
      final streamed = await ApiClient().uploadBytes(
        '/upload-image/',
        fieldName: 'file',
        bytes: bytes,
        fileName: filename,
      );
      final response = await http.Response.fromStream(streamed);
      print('[upload] status=${response.statusCode} body=${response.body}');
      if (response.statusCode != 200)
        throw Exception('${response.statusCode}: ${response.body}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) throw Exception('No URL');
      final userId = ref.read(userDataProvider).userId;
      await ApiClient().put('/users/$userId', body: {'avatar_url': url});
      ref.read(userDataProvider.notifier).setAvatarUrl(url);
    } catch (e, st) {
      print('[upload] ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    String daysLeftText = '0';
    if (userData.targetDate != null) {
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final target = DateTime(userData.targetDate!.year,
          userData.targetDate!.month, userData.targetDate!.day);
      final diff = target.difference(today).inDays;
      daysLeftText = diff > 0 ? diff.toString() : '0';
    }

    String goalText = 'ลดน้ำหนัก';
    Color goalColor = const Color(0xFFE74C3C);
    IconData goalIcon = Icons.trending_down;
    if (userData.goal == GoalOption.maintainWeight) {
      goalText = 'รักษาน้ำหนัก';
      goalColor = const Color(0xFF3498DB);
      goalIcon = Icons.balance;
    } else if (userData.goal == GoalOption.buildMuscle) {
      goalText = 'เพิ่มกล้ามเนื้อ';
      goalColor = const Color(0xFFE67E22);
      goalIcon = Icons.fitness_center;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Banner ────────────────────────────────
            _buildHeaderBanner(
                context, userData, goalText, goalColor, goalIcon, daysLeftText),

            const SizedBox(height: 20),

            // ─── Stats Row ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStatsRow(userData, daysLeftText),
            ),

            const SizedBox(height: 20),

            // ─── Badges ───────────────────────────────────
            _BadgesSection(userId: userData.userId),

            const SizedBox(height: 4),

            // ─── Section: ข้อมูลส่วนตัว ───────────────────────
            _buildSectionLabel('ข้อมูลส่วนตัว'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMenuCard([
                _MenuEntry(
                    Icons.edit_rounded, 'แก้ไขโปรไฟล์', const Color(0xFF5B8DD9),
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()));
                }),
                _MenuEntry(Icons.flag_rounded, 'แก้ไขเป้าหมาย',
                    const Color(0xFFE74C3C), () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GoalSelectionScreen()));
                }),
                _MenuEntry(Icons.directions_run_rounded, 'แก้ไขระดับกิจกรรม',
                    const Color(0xFF27AE60), () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ActivityLevelScreen(isEditing: true)));
                }),
                _MenuEntry(Icons.no_meals_rounded, 'การแพ้อาหาร',
                    const Color(0xFFE67E22), () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const FoodAllergyScreen(isEditing: true)));
                }),
                _MenuEntry(
                    Icons.settings_rounded, 'ตั้งค่า', const Color(0xFF8E44AD),
                    () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingScreen()));
                }, isLast: true),
              ]),
            ),

            const SizedBox(height: 20),

            // ─── Section: AI Coach ────────────────────────────
            _buildSectionLabel('AI Coach'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMenuCard([
                _MenuEntry(Icons.smart_toy_rounded, 'น้องซีการ์ด',
                    const Color(0xFF628141), () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
                    isLast: true,
                    assetIcon: 'assets/images/icon/chatbot_icon.png'),
              ]),
            ),

            const SizedBox(height: 20),

            // ─── Section: การแสดงผลข้อมูล ──────────────────────
            _buildSectionLabel('การแสดงผลข้อมูล'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMenuCard([
                _MenuEntry(Icons.sync_rounded, 'ยูนิต', const Color(0xFF16A085),
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UnitSettingsScreen()));
                }),
                _MenuEntry(Icons.bar_chart_rounded, 'ความคืบหน้า',
                    const Color(0xFF2980B9), () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProgressScreen()));
                }, isLast: true),
              ]),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(
      BuildContext context,
      dynamic userData,
      String goalText,
      Color goalColor,
      IconData goalIcon,
      String daysLeftText) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D5A27), Color(0xFF628141)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      child: Column(children: [
        // Back + Title
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text('โปรไฟล์ส่วนตัว',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(width: 40),
        ]),

        const SizedBox(height: 24),

        // Avatar + Info
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Avatar circle (tap to upload)
          GestureDetector(
            onTap: _uploading ? null : _pickAndUploadAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 2.5),
                    image: DecorationImage(
                        image: (userData.avatarUrl != null &&
                                userData.avatarUrl!.isNotEmpty)
                            ? NetworkImage(userData.avatarUrl!) as ImageProvider
                            : const AssetImage(
                                'assets/images/profile/profile.png'),
                        fit: BoxFit.cover),
                  ),
                  child: _uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                              strokeWidth: 2))
                      : null,
                ),
                if (!_uploading)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF628141), width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Color(0xFF628141)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userData.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                  'อายุ ${userData.age} ปี  •  สูง ${userData.height.toInt()} ซม.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(goalIcon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text('เป้าหมาย: $goalText',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow(dynamic userData, String daysLeftText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: _statItem('${userData.weight.toInt()} กก.', 'น้ำหนักปัจจุบัน',
              Icons.monitor_weight_outlined, const Color(0xFF27AE60)),
        ),
        Container(width: 1, height: 60, color: const Color(0xFFEEEEEE)),
        Expanded(
          child: _statItem('${userData.targetWeight.toInt()} กก.', 'เป้าหมาย',
              Icons.flag_outlined, const Color(0xFFE74C3C)),
        ),
        Container(width: 1, height: 60, color: const Color(0xFFEEEEEE)),
        Expanded(
          child: _statItem('$daysLeftText วัน', 'วันที่เหลือ',
              Icons.calendar_today_outlined, const Color(0xFF3498DB)),
        ),
      ]),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildMenuCard(List<_MenuEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: entries.map((e) => _buildMenuTile(e)).toList(),
      ),
    );
  }

  Widget _buildMenuTile(_MenuEntry e) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: e.assetIcon != null ? Colors.white : Colors.grey.shade100,
              shape: e.assetIcon != null ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
                  e.assetIcon != null ? null : BorderRadius.circular(10),
            ),
            child: e.assetIcon != null
                ? ClipOval(
                    child: Transform.scale(
                      scale: 1.12,
                      child: Image.asset(e.assetIcon!, fit: BoxFit.cover),
                    ),
                  )
                : Icon(e.icon, color: Colors.grey.shade500, size: 20),
          ),
          title: Text(e.label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          trailing: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey.shade400),
          onTap: e.onTap,
        ),
        if (!e.isLast)
          Divider(
              height: 1,
              indent: 70,
              endIndent: 20,
              color: Colors.grey.shade100),
      ],
    );
  }
}

class _MenuEntry {
  final IconData icon;
  final String label;
  final Color iconBg;
  final VoidCallback? onTap;
  final bool isLast;
  final String? assetIcon;
  const _MenuEntry(this.icon, this.label, this.iconBg, this.onTap,
      {this.isLast = false, this.assetIcon});
}

// ─── Badge showcase (reads from local SharedPrefs) ────────────
class _BadgesSection extends StatefulWidget {
  final int userId;
  const _BadgesSection({required this.userId});
  @override
  State<_BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<_BadgesSection> {
  Set<String> _claimed = {};

  static const _badgeInfo = {
    'badge_newbie': ('🌱', 'ชาวนามือใหม่'),
    'badge_grower': ('🌾', 'รวงทอง'),
    'badge_champion': ('✨', 'วิ้งค์'),
  };

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final key = 'tama_rewards_claimed_${widget.userId}';
      setState(() => _claimed = (prefs.getStringList(key) ?? []).toSet());
    });
  }

  @override
  Widget build(BuildContext context) {
    final earned =
        _badgeInfo.entries.where((e) => _claimed.contains(e.key)).toList();
    if (earned.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🏆  บาดจ์ของฉัน',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D5A27),
                fontFamily: 'Inter')),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: earned.map((e) {
              final emoji = e.value.$1;
              final label = e.value.$2;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF628141).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF628141).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF3D5A27),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ]),
              );
            }).toList()),
      ]),
    );
  }
}
