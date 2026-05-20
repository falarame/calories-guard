import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_models.dart';
import '../services/community_api.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Referral
/// ─────────────────────────────────────────────────────────────────────────

final myReferralProvider = FutureProvider.autoDispose<ReferralSummary>((ref) async {
  return CommunityApi.instance.getMyReferral();
});

final myInviteesProvider = FutureProvider.autoDispose<List<InviteePreview>>((ref) async {
  return CommunityApi.instance.getInvitees();
});

/// ─────────────────────────────────────────────────────────────────────────
/// Friends
/// ─────────────────────────────────────────────────────────────────────────

final friendsProvider = FutureProvider.autoDispose<List<FriendEntry>>((ref) async {
  return CommunityApi.instance.listFriends();
});

final friendRequestsProvider = FutureProvider.autoDispose<List<FriendEntry>>((ref) async {
  return CommunityApi.instance.listFriendRequests();
});

/// ─────────────────────────────────────────────────────────────────────────
/// Conversations list — REST seed + Supabase Realtime delta merge
/// ─────────────────────────────────────────────────────────────────────────

/// Notifies whenever ANY conversation row in cleangoal.messages changes for
/// my member set. Implementations are best-effort: if Realtime is degraded
/// the UI still works on REST polling triggered by the user (pull-to-refresh).
class ConversationsController extends StateNotifier<AsyncValue<List<ConversationSummary>>> {
  ConversationsController() : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  RealtimeChannel? _channel;

  Future<void> _bootstrap() async {
    await refresh();
    _subscribe();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await CommunityApi.instance.listConversations();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    final supa = Supabase.instance.client;
    _channel = supa.channel('community:conversations');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'cleangoal',
          table: 'messages',
          callback: (payload) async {
            // Cheap re-fetch — the list query already produces the right shape
            // including unread counts. We could update in-place by patching
            // the matching conversation row, but a single GET is plenty.
            await _refetchSilently();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'cleangoal',
          table: 'conversation_members',
          callback: (_) async => _refetchSilently(),
        )
        .subscribe();
  }

  Future<void> _refetchSilently() async {
    try {
      final list = await CommunityApi.instance.listConversations();
      if (mounted) state = AsyncValue.data(list);
    } catch (_) {
      // realtime triggered → REST hiccup; UI keeps last good data
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final conversationsProvider =
    StateNotifierProvider.autoDispose<ConversationsController, AsyncValue<List<ConversationSummary>>>(
  (ref) => ConversationsController(),
);

/// Total unread across all conversations — drives the home-screen badge.
final chatUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final state = ref.watch(conversationsProvider);
  return state.maybeWhen(
    data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
});

/// ─────────────────────────────────────────────────────────────────────────
/// Messages inside a single conversation
/// ─────────────────────────────────────────────────────────────────────────

class MessagesState {
  final List<ChatMessage> messages; // sorted oldest → newest
  final bool isLoadingHistory;
  final bool hasMore;
  final Object? error;

  const MessagesState({
    this.messages = const [],
    this.isLoadingHistory = false,
    this.hasMore = true,
    this.error,
  });

  MessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoadingHistory,
    bool? hasMore,
    Object? error,
  }) =>
      MessagesState(
        messages: messages ?? this.messages,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class MessagesController extends StateNotifier<MessagesState> {
  final int conversationId;
  RealtimeChannel? _channel;

  MessagesController(this.conversationId) : super(const MessagesState()) {
    loadInitial();
    _subscribeRealtime();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoadingHistory: true, error: null);
    try {
      final fetched = await CommunityApi.instance.listMessages(conversationId, limit: 50);
      // API returns DESC by message_id — flip for chronological order
      final asc = fetched.reversed.toList();
      state = state.copyWith(
        messages: asc,
        isLoadingHistory: false,
        hasMore: fetched.length >= 50,
      );
      // Mark the newest as read
      if (asc.isNotEmpty) {
        await CommunityApi.instance.markRead(conversationId, asc.last.messageId);
      }
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false, error: e);
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore || state.isLoadingHistory || state.messages.isEmpty) return;
    final oldest = state.messages.first.messageId;
    state = state.copyWith(isLoadingHistory: true);
    try {
      final older = await CommunityApi.instance.listMessages(conversationId, before: oldest, limit: 50);
      final asc = older.reversed.toList();
      state = state.copyWith(
        messages: [...asc, ...state.messages],
        isLoadingHistory: false,
        hasMore: older.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false, error: e);
    }
  }

  void _subscribeRealtime() {
    final supa = Supabase.instance.client;
    _channel = supa.channel('community:messages:$conversationId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'cleangoal',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            try {
              final msg = ChatMessage.fromJson(Map<String, dynamic>.from(newRow));
              if (state.messages.any((m) => m.messageId == msg.messageId)) return;
              state = state.copyWith(messages: [...state.messages, msg]);
              // Best-effort mark-read so the badge clears while user is on screen
              CommunityApi.instance.markRead(conversationId, msg.messageId).ignore();
            } catch (_) {}
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'cleangoal',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            try {
              final msg = ChatMessage.fromJson(Map<String, dynamic>.from(updated));
              final idx = state.messages.indexWhere((m) => m.messageId == msg.messageId);
              if (idx == -1) return;
              final next = [...state.messages];
              next[idx] = msg;
              state = state.copyWith(messages: next);
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> sendText(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final sent = await CommunityApi.instance.sendMessage(conversationId, body: text);
    // Realtime will deliver — but inserting locally guards against slow CDC
    if (!state.messages.any((m) => m.messageId == sent.messageId)) {
      state = state.copyWith(messages: [...state.messages, sent]);
    }
  }

  Future<void> sendAttachment({
    required List<int> bytes,
    required String fileName,
    String? caption,
  }) async {
    final upload = await CommunityApi.instance.uploadAttachment(
      conversationId: conversationId,
      bytes: bytes,
      fileName: fileName,
    );
    final kind = (upload['kind'] as String?) ?? 'file';
    final sent = await CommunityApi.instance.sendMessage(
      conversationId,
      kind: kind,
      body: caption,
      attachmentUrl: upload['url'] as String?,
      attachmentMime: upload['mime'] as String?,
      attachmentSize: (upload['size'] as num?)?.toInt(),
      attachmentName: upload['name'] as String?,
    );
    if (!state.messages.any((m) => m.messageId == sent.messageId)) {
      state = state.copyWith(messages: [...state.messages, sent]);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final messagesProvider =
    StateNotifierProvider.autoDispose.family<MessagesController, MessagesState, int>(
  (ref, conversationId) => MessagesController(conversationId),
);

/// ─────────────────────────────────────────────────────────────────────────
/// Presence — periodic heartbeat + cached map for friends/conversations
/// ─────────────────────────────────────────────────────────────────────────

class PresenceController extends StateNotifier<Map<int, PresenceStatus>> {
  Timer? _heartbeat;

  PresenceController() : super(const <int, PresenceStatus>{}) {
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => _beat());
    _beat();
  }

  Future<void> _beat() async {
    try {
      await CommunityApi.instance.heartbeat();
    } catch (_) {}
  }

  Future<void> refreshFor(List<int> userIds) async {
    if (userIds.isEmpty) return;
    try {
      final map = await CommunityApi.instance.getPresence(userIds);
      state = {...state, ...map};
    } catch (_) {}
  }

  void overrideForTesting(int userId, PresenceStatus status) {
    state = {...state, userId: status};
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }
}

final presenceProvider =
    StateNotifierProvider<PresenceController, Map<int, PresenceStatus>>(
  (ref) => PresenceController(),
);
