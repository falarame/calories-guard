import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '/providers/user_data_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _green = Color(0xFF628141);
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final userId = ref.read(userDataProvider).userId;
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
      debugPrint(
          '[upload] filename=$filename bytes=${bytes.length} header=${bytes.take(4).toList()}');

      // Step 1: upload bytes to /upload-image/ → ได้ public URL
      final streamed = await ApiClient().uploadBytes(
        '/upload-image/',
        fieldName: 'file',
        bytes: bytes,
        fileName: filename,
        extraFields: {'user_id': userId.toString()},
      );
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) throw Exception(body);

      final data = jsonDecode(body) as Map<String, dynamic>;
      final publicUrl = data['url'] as String?;
      if (publicUrl == null) throw Exception('No URL in response');

      final cacheBusted =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      // Step 2: PUT /users/{id} ส่ง avatar_url พร้อม cache buster เพื่อ force reload หลัง restart
      final putRes = await ApiClient().put(
        '/users/$userId',
        body: {'avatar_url': cacheBusted},
      );
      if (putRes.statusCode != 200) throw Exception(putRes.body);
      ref.read(userDataProvider.notifier).setAvatarUrl(cacheBusted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('อัปโหลดรูปสำเร็จ ✅'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('อัปโหลดไม่สำเร็จ: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _updateUserData(Map<String, dynamic> updateData) async {
    final userId = ref.read(userDataProvider).userId;
    try {
      final response = await ApiClient().put(
        '/users/$userId',
        body: updateData,
      );
      if (response.statusCode == 200) {
        final user = ref.read(userDataProvider);
        if (updateData.containsKey('username')) {
          ref.read(userDataProvider.notifier).setPersonalInfo(
              name: updateData['username'],
              birthDate: user.birthDate ?? DateTime.now(),
              height: user.height,
              weight: user.weight);
        }
        if (updateData.containsKey('height_cm')) {
          final h = double.tryParse(updateData['height_cm'].toString()) ??
              user.height;
          ref.read(userDataProvider.notifier).setPersonalInfo(
              name: user.name,
              birthDate: user.birthDate ?? DateTime.now(),
              height: h,
              weight: user.weight);
        }
        if (updateData.containsKey('current_weight_kg')) {
          final w =
              double.tryParse(updateData['current_weight_kg'].toString()) ??
                  user.weight;
          ref.read(userDataProvider.notifier).setPersonalInfo(
              name: user.name,
              birthDate: user.birthDate ?? DateTime.now(),
              height: user.height,
              weight: w);
        }
        if (updateData.containsKey('target_weight_kg')) {
          final tw =
              double.tryParse(updateData['target_weight_kg'].toString()) ??
                  user.targetWeight;
          ref
              .read(userDataProvider.notifier)
              .setGoalInfo(targetWeight: tw, duration: user.duration);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('บันทึกข้อมูลเรียบร้อยแล้ว ✅'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(String title, String key, String currentValue,
      {bool isNumber = false}) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('แก้ไข$title',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        content: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: 'กรอก$titleใหม่',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              if (isNumber) {
                final value = double.tryParse(text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('กรุณากรอกตัวเลขที่ถูกต้อง (มากกว่า 0)'),
                      backgroundColor: Colors.orange));
                  return;
                }
                if (key == 'height_cm' && (value < 50 || value > 300)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('ส่วนสูงต้องอยู่ระหว่าง 50–300 ซม.'),
                      backgroundColor: Colors.orange));
                  return;
                }
                if ((key == 'current_weight_kg' || key == 'target_weight_kg') &&
                    (value < 20 || value > 500)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('น้ำหนักต้องอยู่ระหว่าง 20–500 กก.'),
                      backgroundColor: Colors.orange));
                  return;
                }
                _updateUserData({key: value});
              } else {
                if (text.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('ชื่อต้องมีอย่างน้อย 2 ตัวอักษร'),
                      backgroundColor: Colors.orange));
                  return;
                }
                _updateUserData({key: text});
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: SingleChildScrollView(
        child: Column(children: [
          // ─── Header ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3D5A27), Color(0xFF628141)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 36),
            child: Column(children: [
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
                  child: Text('แก้ไขโปรไฟล์',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 40),
              ]),
              const SizedBox(height: 28),

              // Avatar
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: DecorationImage(
                          image: (userData.avatarUrl != null &&
                                  userData.avatarUrl!.isNotEmpty)
                              ? NetworkImage(userData.avatarUrl!)
                                  as ImageProvider
                              : const AssetImage(
                                  'assets/images/profile/profile.png'),
                          fit: BoxFit.cover),
                    ),
                    child: _isUploadingAvatar
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: _green),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ─── Info Card ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('ข้อมูลพื้นฐาน'),
              const SizedBox(height: 10),
              _buildInfoCard([
                _EditRow(
                  label: 'ชื่อผู้ใช้',
                  value: userData.name,
                  icon: Icons.person_outline_rounded,
                  iconColor: Colors.grey.shade500,
                  onTap: () =>
                      _showEditDialog('ชื่อผู้ใช้', 'username', userData.name),
                ),
                _EditRow(
                  label: 'อายุ',
                  value: '${userData.age} ปี',
                  icon: Icons.cake_outlined,
                  iconColor: Colors.grey.shade500,
                  isEditable: false,
                ),
                _EditRow(
                  label: 'ส่วนสูง',
                  value: '${userData.height.toInt()} ซม.',
                  icon: Icons.height_rounded,
                  iconColor: Colors.grey.shade500,
                  onTap: () => _showEditDialog(
                      'ส่วนสูง', 'height_cm', userData.height.toString(),
                      isNumber: true),
                  isLast: true,
                ),
              ]),
              const SizedBox(height: 20),
              _sectionLabel('ข้อมูลน้ำหนัก'),
              const SizedBox(height: 10),
              _buildInfoCard([
                _EditRow(
                  label: 'น้ำหนักปัจจุบัน',
                  value: '${userData.weight.toInt()} กก.',
                  icon: Icons.monitor_weight_outlined,
                  iconColor: Colors.grey.shade500,
                  onTap: () => _showEditDialog('น้ำหนักปัจจุบัน',
                      'current_weight_kg', userData.weight.toString(),
                      isNumber: true),
                ),
                _EditRow(
                  label: 'น้ำหนักเป้าหมาย',
                  value: '${userData.targetWeight.toInt()} กก.',
                  icon: Icons.flag_outlined,
                  iconColor: Colors.grey.shade500,
                  onTap: () => _showEditDialog('น้ำหนักเป้าหมาย',
                      'target_weight_kg', userData.targetWeight.toString(),
                      isNumber: true),
                ),
                _EditRow(
                  label: 'วันที่เหลือ',
                  value: '$daysLeftText วัน',
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.grey.shade500,
                  isEditable: false,
                  isLast: true,
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5));
  }

  Widget _buildInfoCard(List<_EditRow> rows) {
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
      child: Column(children: rows.map((r) => _buildEditTile(r)).toList()),
    );
  }

  Widget _buildEditTile(_EditRow row) {
    return Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(row.icon, color: row.iconColor, size: 20),
        ),
        title: Text(row.label,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.2)),
        subtitle: Text(row.value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        trailing: row.isEditable
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200)),
                child: const Icon(Icons.edit_rounded, size: 15, color: _green),
              )
            : null,
        onTap: row.isEditable ? row.onTap : null,
      ),
      if (!row.isLast)
        Divider(
            height: 1, indent: 70, endIndent: 20, color: Colors.grey.shade100),
    ]);
  }
}

class _EditRow {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool isEditable;
  final bool isLast;
  const _EditRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.isEditable = true,
    this.isLast = false,
  });
}
