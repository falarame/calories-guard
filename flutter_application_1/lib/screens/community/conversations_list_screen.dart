import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/community_models.dart';
import '../../theme/app_theme.dart';
import '../../providers/community_providers.dart';
import 'conversation_detail_screen.dart';
import 'friends_screen.dart';

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('แชท'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'เพื่อน & คำเชิญ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
        child: convs.when(
          data: (list) => list.isEmpty
              ? _buildEmpty(context)
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) => _ConversationTile(c: list[i]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, e, () => ref.read(conversationsProvider.notifier).refresh()),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.chat_bubble_outline, size: 64, color: Theme.of(context).hintColor),
        const SizedBox(height: 12),
        const Text('ยังไม่มีการสนทนา', textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text(
          'เริ่มแชทกับเพื่อนได้จากแท็บ "เพื่อน"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object e, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text('โหลดไม่สำเร็จ: $e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationSummary c;
  const _ConversationTile({required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = c.peerUserId == null ? null : ref.watch(presenceProvider)[c.peerUserId];
    final lastTime = c.lastMessageAt != null ? _formatTime(c.lastMessageAt!) : '';
    final preview = _previewText();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _avatar(context, presence),
      title: Row(
        children: [
          Expanded(
            child: Text(
              c.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: c.unreadCount > 0 ? FontWeight.bold : FontWeight.w500),
            ),
          ),
          if (lastTime.isNotEmpty)
            Text(lastTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600),
            ),
          ),
          if (c.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.palette.brand,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(
              conversationId: c.conversationId,
              title: c.displayTitle,
              peerUserId: c.peerUserId,
            ),
          ),
        );
        // Refresh list to reflect new last_read / unread state
        if (context.mounted) {
          ref.read(conversationsProvider.notifier).refresh();
        }
      },
    );
  }

  Widget _avatar(BuildContext context, PresenceStatus? presence) {
    final url = c.displayAvatar;
    final avatar = CircleAvatar(
      radius: 26,
      backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      backgroundColor: const Color(0xFFE8EFCF),
      child: (url == null || url.isEmpty)
          ? Icon(c.type == 'group' ? Icons.group : Icons.person, color: context.palette.brand)
          : null,
    );
    if (presence == PresenceStatus.online) {
      return Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      );
    }
    return avatar;
  }

  String _previewText() {
    if (c.lastMessageBody != null && c.lastMessageBody!.isNotEmpty) return c.lastMessageBody!;
    if (c.lastMessageKind == 'image') return '📷 รูปภาพ';
    if (c.lastMessageKind == 'file') return '📎 ไฟล์';
    if (c.lastMessageKind == 'system') return 'แจ้งเตือนระบบ';
    return 'เริ่มสนทนาเลย';
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final local = t.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat.E('th').format(local);
    }
    return DateFormat.yMd().format(local);
  }
}
