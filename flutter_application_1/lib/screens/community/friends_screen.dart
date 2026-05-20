import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/community_models.dart';
import '../../providers/community_providers.dart';
import '../../services/community_api.dart';
import 'conversation_detail_screen.dart';
import 'invite_friend_bottom_sheet.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพื่อน'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'เพื่อน'),
            Tab(text: 'คำขอ'),
            Tab(text: 'เชิญ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_FriendList(), _RequestList(), _InviteTab()],
      ),
    );
  }
}

class _FriendList extends ConsumerWidget {
  const _FriendList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendsProvider),
      child: friends.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('ยังไม่มีเพื่อน — เชิญเพื่อนของคุณเลย!')),
              ],
            );
          }
          // Trigger presence refresh once data lands
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(presenceProvider.notifier).refreshFor(list.map((f) => f.userId).toList());
          });
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (_, i) => _FriendTile(friend: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('โหลดไม่สำเร็จ: $e')),
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final FriendEntry friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceProvider)[friend.userId] ?? friend.presence;
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE8EFCF),
            backgroundImage: (friend.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(friend.avatarUrl!) : null,
            child: (friend.avatarUrl?.isEmpty ?? true)
                ? const Icon(Icons.person, color: Color(0xFF628141))
                : null,
          ),
          if (presence == PresenceStatus.online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(friend.username),
      subtitle: Text(
        presence == PresenceStatus.online
            ? 'ออนไลน์'
            : friend.lastSeenAt != null
                ? 'เห็นล่าสุด ${_relativeTime(friend.lastSeenAt!)}'
                : 'ออฟไลน์',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        tooltip: 'ส่งข้อความ',
        onPressed: () async {
          try {
            final convId = await CommunityApi.instance.createDm(friend.userId);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationDetailScreen(
                  conversationId: convId,
                  title: friend.username,
                  peerUserId: friend.userId,
                ),
              ),
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เปิดแชทไม่สำเร็จ: $e')));
            }
          }
        },
      ),
      onLongPress: () => _showFriendMenu(context, ref, friend),
    );
  }

  void _showFriendMenu(BuildContext context, WidgetRef ref, FriendEntry f) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('ลบเพื่อน'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await CommunityApi.instance.removeFriend(f.userId);
                  ref.invalidate(friendsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('บล็อก', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await CommunityApi.instance.blockUser(f.userId);
                  ref.invalidate(friendsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บล็อกไม่สำเร็จ: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(friendRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendRequestsProvider),
      child: reqs.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('ไม่มีคำขอเป็นเพื่อน')),
              ],
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (_, i) {
              final r = list[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE8EFCF),
                  backgroundImage: (r.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(r.avatarUrl!) : null,
                  child: (r.avatarUrl?.isEmpty ?? true) ? const Icon(Icons.person, color: Color(0xFF628141)) : null,
                ),
                title: Text(r.username),
                subtitle: Text('ส่งคำขอ ${r.createdAt != null ? _relativeTime(r.createdAt!) : ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        try {
                          await CommunityApi.instance.acceptFriend(r.userId);
                          ref.invalidate(friendRequestsProvider);
                          ref.invalidate(friendsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ตอบรับไม่สำเร็จ: $e')));
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () async {
                        try {
                          await CommunityApi.instance.removeFriend(r.userId);
                          ref.invalidate(friendRequestsProvider);
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('โหลดไม่สำเร็จ: $e')),
      ),
    );
  }
}

class _InviteTab extends ConsumerWidget {
  const _InviteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref0 = ref.watch(myReferralProvider);
    final invitees = ref.watch(myInviteesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myReferralProvider);
        ref.invalidate(myInviteesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ref0.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('โหลดข้อมูลเชิญไม่สำเร็จ: $e'),
            data: (r) => _ReferralCard(summary: r),
          ),
          const SizedBox(height: 24),
          const Text('เพื่อนที่คุณเชิญสำเร็จ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          invitees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('โหลดรายชื่อไม่สำเร็จ: $e'),
            data: (list) {
              if (list.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('ยังไม่มีเพื่อนเข้าร่วม', style: TextStyle(color: Colors.grey))));
              return Column(
                children: list.map((i) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (i.inviteeAvatar?.isNotEmpty ?? false) ? NetworkImage(i.inviteeAvatar!) : null,
                    backgroundColor: const Color(0xFFE8EFCF),
                    child: (i.inviteeAvatar?.isEmpty ?? true) ? const Icon(Icons.person, color: Color(0xFF628141)) : null,
                  ),
                  title: Text(i.inviteeUsername),
                  subtitle: Text('${_sourceLabel(i.source)} • ${i.status == 'rewarded' ? 'รับรางวัลแล้ว' : i.status}'),
                  trailing: i.status == 'rewarded' ? const Icon(Icons.verified, color: Colors.green) : null,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _sourceLabel(String s) => switch (s) { 'email' => 'อีเมล', 'code' => 'รหัส', _ => 'ลิงก์' };
}

class _ReferralCard extends StatelessWidget {
  final ReferralSummary summary;
  const _ReferralCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFE8EFCF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Color(0xFF3D5A27)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ชวนเพื่อน รับ 50 gems + 20 XP',
                      style: TextStyle(color: Color(0xFF3D5A27), fontWeight: FontWeight.bold)),
                ),
                Text('+${summary.totalGemsEarned} gems',
                    style: const TextStyle(color: Color(0xFF3D5A27), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(child: Text(summary.code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2))),
                  Text('${summary.acceptedCount} คนเข้าร่วมแล้ว', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('แชร์ลิงก์ / ส่งอีเมล'),
              onPressed: () => showInviteFriendBottomSheet(context, summary),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final now = DateTime.now();
  final local = t.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาที';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมง';
  if (diff.inDays < 7) return '${diff.inDays} วัน';
  return DateFormat.yMd().format(local);
}
