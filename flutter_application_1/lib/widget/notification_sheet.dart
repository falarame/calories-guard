import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_data_provider.dart';
import '../services/api_client.dart';
import '../services/error_reporter.dart';

// ── Provider: unread count ────────────────────────────────────────────────────
final unreadCountProvider = StateProvider<int>((ref) => 0);

// ── Model ─────────────────────────────────────────────────────────────────────
class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['notification_id'] as int,
      title: j['title'] as String,
      message: j['message'] as String? ?? '',
      type: j['type'] as String? ?? 'info',
      isRead: j['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ── Bell Icon Button (used in top bars) ───────────────────────────────────────
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, this.color = Colors.white});
  final Color color;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  @override
  void initState() {
    super.initState();
    // fetch unread count on mount (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUnreadCount());
  }

  Future<void> _fetchUnreadCount() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    try {
      final res = await ApiClient().get('/notifications/$userId/unread_count');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        ref.read(unreadCountProvider.notifier).state =
            (data['unread_count'] as int?) ?? 0;
      }
    } catch (e, st) {
      ErrorReporter.report('notification_sheet.fetch_unread_count', e, st);
    }
  }

  void _openSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationSheet(),
    );
    // refresh count after sheet closes
    _fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _openSheet,
          icon:
              Icon(Icons.notifications_outlined, color: widget.color, size: 28),
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFE74C3C),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Notification Bottom Sheet ─────────────────────────────────────────────────
class NotificationSheet extends ConsumerStatefulWidget {
  const NotificationSheet({super.key});

  @override
  ConsumerState<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<NotificationSheet> {
  static const _green = Color(0xFF628141);

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final userId = ref.read(userDataProvider).userId;
    try {
      final res = await ApiClient().get('/notifications/$userId');
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() => _notifications = list);
      } else {
        setState(() => _error = 'โหลดไม่สำเร็จ');
      }
    } catch (_) {
      setState(() => _error = 'ไม่สามารถเชื่อมต่อได้');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    final userId = ref.read(userDataProvider).userId;
    try {
      await ApiClient().put('/notifications/$userId/read_all');
      setState(() {
        for (final n in _notifications) {
          n.isRead = true;
        }
      });
      ref.read(unreadCountProvider.notifier).state = 0;
    } catch (e, st) {
      ErrorReporter.report('notification_sheet.mark_all_read', e, st);
    }
  }

  // ── Icon per notification type ────────────────────────────────
  IconData _typeIcon(String type) {
    switch (type) {
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'tip':
        return Icons.lightbulb_outline_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'achievement':
        return const Color(0xFFFFB347);
      case 'warning':
        return const Color(0xFFE74C3C);
      case 'tip':
        return const Color(0xFF3498DB);
      case 'streak':
        return const Color(0xFFFF6B35);
      default:
        return _green;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อกี้';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${dt.day}/${dt.month}/${dt.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // ── Drag handle ─────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),

          // ── Header ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3D5A27), Color(0xFF628141)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('การแจ้งเตือน',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      if (unread > 0)
                        Text('ยังไม่ได้อ่าน $unread รายการ',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity( 0.75))),
                    ]),
              ),
              if (unread > 0)
                TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('อ่านทั้งหมด',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6)),
                ),
            ]),
          ),

          // ── Body ────────────────────────────────────────────
          Expanded(child: _buildBody(scrollCtrl)),
        ]),
      ),
    );
  }

  Widget _buildBody(ScrollController scrollCtrl) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF628141)));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF628141),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('ยังไม่มีการแจ้งเตือน',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('การแจ้งเตือนจะปรากฏที่นี่',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ]),
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _notifications.length,
      itemBuilder: (_, i) => _buildNotificationTile(_notifications[i]),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    final color = _typeColor(n.type);
    final icon = _typeIcon(n.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : const Color(0xFFEAF2DB),
        borderRadius: BorderRadius.circular(16),
        border: n.isRead
            ? null
            : Border.all(
                color: const Color(0xFF628141).withOpacity( 0.3),
                width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity( 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(children: [
          Expanded(
            child: Text(n.title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    color: Colors.black87)),
          ),
          if (!n.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF628141), shape: BoxShape.circle),
            ),
        ]),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (n.message.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(n.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 4),
          Text(_relativeTime(n.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}
