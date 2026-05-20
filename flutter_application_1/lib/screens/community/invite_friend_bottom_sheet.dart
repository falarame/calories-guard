import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/community_models.dart';
import '../../providers/community_providers.dart';
import '../../services/community_api.dart';

Future<void> showInviteFriendBottomSheet(BuildContext context, ReferralSummary summary) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InviteSheet(summary: summary),
  );
}

class _InviteSheet extends ConsumerStatefulWidget {
  final ReferralSummary summary;
  const _InviteSheet({required this.summary});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลที่ถูกต้อง')));
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await CommunityApi.instance.sendEmailInvite(email);
      if (!mounted) return;
      ref.invalidate(myReferralProvider);
      ref.invalidate(myInviteesProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['email_sent'] == true ? 'ส่งคำเชิญแล้ว 🎉' : 'สร้างลิงก์แล้ว แต่ส่งอีเมลไม่สำเร็จ')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ส่งคำเชิญไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ชวนเพื่อนมาใช้ Calories Guard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('เมื่อเพื่อนสมัครและยืนยันอีเมล คุณจะได้ 50 gems + 20 XP',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // Share link block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รหัสของคุณ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.summary.code,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: 'คัดลอกลิงก์',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: widget.summary.shareUrl));
                        if (mounted) {
                          messenger.showSnackBar(const SnackBar(content: Text('คัดลอกลิงก์แล้ว')));
                        }
                      },
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(widget.summary.shareUrl, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('แชร์ลิงก์ผ่านแอปอื่น'),
            onPressed: () {
              Share.share(
                'มาลองใช้ Calories Guard กับฉันสิ! สมัครผ่านลิงก์นี้รับ 20 gems ฟรี ✨\n${widget.summary.shareUrl}',
                subject: 'มาลองใช้ Calories Guard',
              );
            },
          ),
          const SizedBox(height: 24),

          // Email block
          const Text('หรือส่งคำเชิญทางอีเมล',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'friend@example.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _sendInvite,
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ส่ง'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
